class_name Main
extends Node2D
## The game. Holds the hero, the camera, and the HUD, and swaps rooms in and out as the hero
## moves through the world: room changes behind the letterbox, deaths and respawns,
## checkpoints, Spirit Room gates and runs, the color unlock and its cascade, play time, and
## autosaving. Spirit Rooms stand apart from the world: their gates are the only way in and out,
## and leaving one goes back to the gate the hero came in through.

## Entities reach the game through this (null outside the game, e.g. in tests).
static var instance: Main

## Falling this far below a room with nothing beneath it is a death, in px.
const PIT_MARGIN := 16.0
## Seconds each layer takes to take on its new color when a color returns...
const CASCADE_LAYER_TIME := 1.6
## ...and the delay between one layer starting and the next, back to front.
const CASCADE_STAGGER := 0.45
## After touching an orb, how long to wait for the hero to land before absorbing anyway.
const LAND_WAIT_FRAMES := 180
## How hard and long the screen shakes when the hero dies (px, seconds), if shake is on.
const DEATH_SHAKE := 3.0
const DEATH_SHAKE_TIME := 0.2
## Where the hero waits while a room loads, when its spot there isn't known yet.
const FAR_AWAY := Vector2(-100000, -100000)
const SPIRIT_DOOR_QUESTION := "Are you ready to challenge your Spirit?"
## The prompt shown when each color returns, by GameState.SpiritColor.
const ABILITY_PROMPTS: Array[String] = [
	"Orange returned: DASH!   J  /  X button   (8 directions)",
	"Yellow returned: DOUBLE JUMP!   Jump again in midair",
	"Green returned: WALL JUMP!   Jump off walls",
	"Red returned: SLIDE!   K  /  B button while running",
	"Purple returned: CLIMB!   Grab ledges; hold L  /  RT on vines",
	"Blue returned: SPIRIT PHASE!   Hold I  /  Y button",
]
## Region tint for the background forest; shows as those layers regain color.
const REGION_TINT := {&"ember_grove": Color(1.0, 0.82, 0.68), &"meadow": Color(1.0, 0.95, 0.75)}

var room: Room
var transitioning := false

var _entry_spawn := Vector2.ZERO
var _checkpoint := Vector2.INF
var _run_active := false
var _run_time := 0.0
var _run_deaths := 0
## The color strengths on screen right now (by WorldColor.Layer), and whether a cascade is
## animating them.
var _shown_color := PackedFloat32Array()
var _cascading := false

@onready var world: Node2D = $World
@onready var player: Player = $Player
@onready var camera: GameCamera = $Camera
@onready var backdrop: Backdrop = $Camera/Backdrop
@onready var letterbox: Letterbox = $Letterbox
@onready var prompt: Prompt = $Hud/Prompt
@onready var confirm: ConfirmPopup = $Hud/ConfirmPopup
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var map_screen: MapScreen = $MapScreen
@onready var travel_menu: TravelMenu = $TravelMenu


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	# Check room edges after the hero moves and before the camera follows.
	process_physics_priority = 5
	player.died.connect(_on_player_died)
	GameState.colors_changed.connect(_update_world_color)
	var pending := GameState.pending_room_scene
	GameState.pending_room_scene = ""
	if pending != "":
		# A room was run on its own, or the test room was picked: start there as-is.
		var id := WorldMap.room_for_scene(pending)
		var origin := WorldMap.rect_px(id).position if id != &"" else Vector2.ZERO
		_enter(id, pending, origin, Vector2.INF)
	elif GameState.load_game(GameState.slot):
		_enter_world_room(GameState.room_id, GameState.respawn_position)
	else:
		_enter_world_room(WorldMap.START_ROOM, Vector2.INF)


func _process(delta: float) -> void:
	if transitioning:
		return
	GameState.play_time += delta
	if _run_active and not player.frozen and not player.input_locked and player.state_name != &"dead":
		_run_time += delta


func _physics_process(_delta: float) -> void:
	if transitioning or room == null or player.frozen or player.state_name == &"dead":
		return
	var center := player.global_position + Vector2(0.0, -player.tuning.stand_size.y / 2.0)
	var bounds := room.world_bounds()
	if bounds.has_point(center):
		return
	# Spirit Rooms connect to nothing: their edges are walls, and falling out is a death.
	var next := WorldMap.room_at(center) if room.room_id != &"" and not room.spirit_room else &""
	if next != &"" and next != room.room_id and not WorldMap.solid_at(next, center):
		_change_room(next)
	elif center.y > bounds.end.y + PIT_MARGIN:
		player.die()
	elif center.y > bounds.end.y:
		pass # Falling out of the bottom: a pit, unless a room below takes the hero.
	else:
		# Off an edge with no room there, or where the next room is solid: hold the hero at
		# the edge, as if against a wall or ceiling.
		var half := player.tuning.stand_size.x / 2.0
		player.global_position.x = clampf(player.global_position.x, bounds.position.x + half, bounds.end.x - half)
		if center.y < bounds.position.y:
			player.global_position.y = bounds.position.y + player.tuning.stand_size.y / 2.0
			player.velocity.y = maxf(player.velocity.y, 0.0)


## The pause menu and map can open: not during room changes, popups, or the color unlock.
func can_pause() -> bool:
	return room != null and not transitioning and not player.frozen and not player.input_locked \
			and not confirm.visible and not travel_menu.is_open


## A waystone can open the travel menu: not in a Spirit Room, nor when the game can't pause.
func can_travel() -> bool:
	return can_pause() and not room.spirit_room


## Called by an awake waystone when the hero presses Interact at it.
func open_travel(_stone: Waystone) -> void:
	if can_travel():
		travel_menu.open()


## Go to a waystone (from the travel menu): room `id`, arriving at `spot` in world px, behind
## the letterbox.
func travel_to(id: StringName, spot: Vector2) -> void:
	if transitioning:
		return
	Sfx.play(&"respawn")
	await _travel(id, &"", spot)


## True during a Spirit Room run (until its color is taken).
func is_spirit_run() -> bool:
	return _run_active


func run_time() -> float:
	return _run_time


func run_deaths() -> int:
	return _run_deaths


## Inside a Spirit Room with a gate to go back to, so the pause menu can offer the way out.
func can_leave_spirit_room() -> bool:
	return room != null and room.spirit_room and not spirit_return().is_empty()


## Leave a Spirit Room (its exit gate, or Leave Spirit Room in the pause menu): back to the
## doorway of the gate the hero came in through. The room resets.
func leave_spirit_room() -> void:
	var back := spirit_return()
	if back.is_empty():
		return
	GameState.spirit_return_room = &""
	await _travel(back["room"], &"", back["spot"])


## Put the hero back at its respawn point with the room reset, as after a death.
func respawn_player() -> void:
	room.reset_room()
	player.respawn(_respawn_spot())
	camera.snap_to_target()


## Called by checkpoint stones. Returns false where checkpoints don't count (Spirit Rooms).
func checkpoint_reached(spot: Vector2) -> bool:
	if room.spirit_room:
		return false
	_checkpoint = spot
	GameState.respawn_position = spot
	GameState.save_game()
	return true


## Called by a Spirit Room's entrance gate when the hero presses Interact in its doorway: asks
## whether to go in. Yes enters the room at its start, remembering this gate as the way back;
## No leaves the hero standing where they are.
func knock(door: SpiritGate) -> void:
	if transitioning or player.frozen:
		return
	player.frozen = true
	player.velocity = Vector2.ZERO
	player.play(&"idle")
	var yes := await confirm.ask(SPIRIT_DOOR_QUESTION)
	# The press that answered shouldn't also make the hero jump.
	player.jump_buffer_timer = 0.0
	if yes:
		GameState.spirit_return_room = room.room_id
		GameState.spirit_return_spot = door.global_position
		await _travel(door.target_room, door.target_spawn)
	else:
		await get_tree().process_frame
		player.frozen = false


## Called by a color orb when the hero touches it. The hero falls to the ground with the
## controls off, then the color flows into it, the world's color cascades forward, and the
## ability's prompt shows. A Spirit Room's run is recorded (no card interrupts the moment).
func collect_color(orb: ColorOrb) -> void:
	var color := orb.color
	if _run_active:
		GameState.record_clear(room.room_id, _run_time, _run_deaths)
	_run_active = false
	player.input_locked = true
	for i in LAND_WAIT_FRAMES:
		if player.is_on_floor() or player.state_name == &"dead":
			break
		await get_tree().physics_frame
	if player.state_name == &"dead":
		orb.release()
		return
	player.input_locked = false
	player.frozen = true
	player.velocity = Vector2.ZERO
	player.play(&"idle")
	Sfx.play(&"color_unlock", 0.0, 0.0)
	await orb.fly_into(player)
	var before := WorldColor.strengths(GameState.colors())
	_cascading = true
	GameState.set_color(color, true)
	_cascade(before, WorldColor.strengths(GameState.colors()))
	prompt.show_text(ABILITY_PROMPTS[color], 7.0)
	await get_tree().create_timer(0.4).timeout
	player.jump_buffer_timer = 0.0
	player.frozen = false
	GameState.respawn_position = player.global_position
	GameState.save_game()


## Where leaving the current Spirit Room goes: the gate the hero came in through, or else the
## first gate leading here. {"room", "spot" (world px)}, or empty if there's none.
func spirit_return() -> Dictionary:
	if WorldMap.has_room(GameState.spirit_return_room):
		return {"room": GameState.spirit_return_room, "spot": GameState.spirit_return_spot}
	return WorldMap.door_into(room.room_id)


func _enter_world_room(id: StringName, spot: Vector2) -> void:
	GameState.room_id = id
	_enter(id, WorldMap.scene_of(id), WorldMap.rect_px(id).position, spot)


## Load a room and put the hero at `spot` (Vector2.INF: the room's Start spawn, or its first).
func _enter(id: StringName, scene_path: String, origin: Vector2, spot: Vector2) -> void:
	# Move the hero before the room arrives (see Touch for why triggers double-check anyway).
	player.global_position = spot if spot != Vector2.INF else FAR_AWAY
	_swap_room(id, scene_path, origin)
	if spot == Vector2.INF:
		spot = _spawn_or_first(&"Start")
	_entry_spawn = spot
	player.respawn(spot, true)
	camera.snap_to_target()
	if id != &"":
		GameState.respawn_position = spot
		GameState.save_game()


## Go into a world room behind the letterbox (Spirit Room gates, leaving a Spirit Room): at
## `spot` in world px if given, otherwise at the spawn point named `spawn`.
func _travel(id: StringName, spawn: StringName, spot := Vector2.INF) -> void:
	transitioning = true
	player.frozen = true
	await letterbox.close()
	player.global_position = FAR_AWAY
	_swap_room(id, WorldMap.scene_of(id), WorldMap.rect_px(id).position)
	if spot == Vector2.INF:
		spot = _spawn_or_first(spawn)
	_entry_spawn = spot
	player.respawn(spot, true)
	# Face into the room.
	player.facing = -1 if spot.x > room.world_bounds().get_center().x else 1
	GameState.room_id = id
	GameState.respawn_position = spot
	GameState.save_game()
	camera.snap_to_target()
	transitioning = false
	await letterbox.open()


func _spawn_or_first(spawn: StringName) -> Vector2:
	var spot := room.named_spawn(spawn)
	if spot == Vector2.INF:
		var spawns := room.spawn_points()
		spot = spawns[0] if not spawns.is_empty() else room.world_bounds().get_center()
	return spot


func _swap_room(id: StringName, scene_path: String, origin: Vector2) -> void:
	if room:
		world.remove_child(room)
		room.queue_free()
	room = load(scene_path).instantiate()
	room.room_id = id
	room.position = origin
	world.add_child(room)
	_checkpoint = Vector2.INF
	camera.setup(player, room.world_bounds())
	backdrop.room_bottom = room.world_bounds().end.y
	var region := WorldMap.region_of(id)
	backdrop.set_tint(REGION_TINT.get(region, Color.WHITE))
	if WorldMap.has_room(id):
		GameState.mark_visited(id)
	_update_world_color()
	if room.debug_room:
		debug_overlay.show_info()
	# A Spirit Room is timed until its color is taken.
	_run_active = room.spirit_room and room.find_children("*", "ColorOrb", true, false).any(
			func(orb: Node) -> bool: return not orb.is_queued_for_deletion())
	_run_time = 0.0
	_run_deaths = 0


func _change_room(next: StringName) -> void:
	transitioning = true
	player.frozen = true
	await letterbox.close()
	_swap_room(next, WorldMap.scene_of(next), WorldMap.rect_px(next).position)
	_entry_spawn = room.nearest_spawn(player.global_position)
	GameState.room_id = next
	GameState.respawn_position = _entry_spawn
	GameState.save_game()
	camera.snap_to_target()
	player.frozen = false
	transitioning = false
	await letterbox.open()


func _respawn_spot() -> Vector2:
	if room.spirit_room:
		var start := room.named_spawn(&"Start")
		return start if start != Vector2.INF else _entry_spawn
	return _checkpoint if _checkpoint != Vector2.INF else _entry_spawn


func _on_player_died() -> void:
	GameState.add_death()
	camera.shake(DEATH_SHAKE, DEATH_SHAKE_TIME)
	if _run_active:
		_run_deaths += 1
		_run_time = 0.0
	respawn_player()


## Show the world's color for the colors collected (full color in the test room).
func _update_world_color() -> void:
	if _cascading:
		return
	var full := room != null and room.debug_room
	_shown_color = WorldColor.full() if full else WorldColor.strengths(GameState.colors())
	WorldColor.apply(_shown_color)


## Animate each layer from its old color strength to its new one, back to front.
func _cascade(before: PackedFloat32Array, after: PackedFloat32Array) -> void:
	_cascading = true
	_shown_color = before.duplicate()
	WorldColor.apply(_shown_color)
	var tween := create_tween().set_parallel(true)
	var order := 0
	for layer in after.size():
		if is_equal_approx(before[layer], after[layer]):
			continue
		tween.tween_method(_show_layer.bind(layer), before[layer], after[layer], CASCADE_LAYER_TIME) \
				.set_delay(order * CASCADE_STAGGER)
		order += 1
	if order == 0:
		tween.kill()
		_cascading = false
		return
	tween.finished.connect(func() -> void:
		_cascading = false
		_update_world_color())


func _show_layer(value: float, layer: int) -> void:
	_shown_color[layer] = value
	WorldColor.apply(_shown_color)
