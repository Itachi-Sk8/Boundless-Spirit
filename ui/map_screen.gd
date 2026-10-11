class_name MapScreen
extends CanvasLayer
## The map (Tab, or Map in the pause menu): every visited room drawn where it sits in the world,
## with its ground in the region's color, the current room outlined, the hero blinking, Spirit
## Room gates marked with a diamond (filled once that Spirit Room is cleared), and checkpoint
## stones as dots. Spirit Rooms aren't drawn: inside one, the map shows the hero at the gate they
## came in through. Move pans when the map is bigger than the screen. Tab, Esc, or Back closes
## it. The game pauses.

signal closed

## Map colors per region: the room's fill and its ground.
const REGION_COLORS := {
	&"hollow": Color(0.62, 0.62, 0.6), &"ember_grove": Color(0.92, 0.52, 0.22),
	&"meadow": Color(0.95, 0.85, 0.3), &"canopy": Color(0.45, 0.78, 0.3),
	&"briar": Color(0.85, 0.32, 0.3), &"caverns": Color(0.62, 0.32, 0.75),
	&"falls": Color(0.38, 0.75, 0.9), &"heart": Color(0.95, 0.95, 0.95),
}
const INK := Color(0.22, 0.12, 0.05)
const HERO := Color(1.0, 1.0, 1.0)
## Game units per tile: the map zooms to fit, between these.
const MIN_SCALE := 0.35
const MAX_SCALE := 1.5
const PAN_SPEED := 200.0
## A gate's diamond sits this many tiles above its doorway's floor.
const GATE_HEIGHT_TILES := 4.0

@export var game: Main

var is_open := false

var _pan := Vector2.ZERO
var _time := 0.0
var _skip_frame := false
# Room id -> ImageTexture of its solid ground, one pixel per tile.
var _ground := {}

@onready var view: Control = %View
@onready var title: Label = %Title


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	view.draw.connect(_draw_map)


## Show the map until it's closed. `own_pause`: it paused the game itself (opened with Tab),
## so it unpauses on closing; from the pause menu it leaves the game paused.
func open(own_pause := true) -> void:
	is_open = true
	set_meta(&"own_pause", own_pause)
	get_tree().paused = true
	_pan = Vector2.ZERO
	_skip_frame = true
	var region := WorldMap.region_of(game.room.room_id) if game.room else &""
	title.text = WorldMap.REGION_NAMES.get(region, "Map")
	show()
	view.queue_redraw()
	await closed


func close() -> void:
	is_open = false
	hide()
	if get_meta(&"own_pause", true):
		get_tree().paused = false
		game.player.jump_buffer_timer = 0.0
	closed.emit()


func _process(delta: float) -> void:
	if not is_open:
		if Input.is_action_just_pressed(&"map") and game.can_pause() and not get_tree().paused:
			open()
		return
	if _skip_frame:
		_skip_frame = false
		return
	if Input.is_action_just_pressed(&"map") or Input.is_action_just_pressed(&"pause") \
			or Input.is_action_just_pressed(&"ui_cancel"):
		Sfx.play(&"ui_confirm", -10.0)
		close()
		return
	var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_pan += move * PAN_SPEED * delta
	_time += delta
	view.queue_redraw()


func _draw_map() -> void:
	var visited := _visited_rooms()
	if visited.is_empty():
		return
	var bounds := WorldMap.rect_px(visited[0])
	for id: StringName in visited:
		bounds = bounds.merge(WorldMap.rect_px(id))
	var area := Rect2(Vector2.ZERO, view.size)
	var tiles := bounds.size / WorldMap.TILE
	var scale := clampf(minf(area.size.x / tiles.x, area.size.y / tiles.y), MIN_SCALE, MAX_SCALE)
	var current: StringName = game.room.room_id if game.room else &""
	var hero_tile := game.player.global_position / WorldMap.TILE
	if WorldMap.is_spirit_room(current):
		var back := game.spirit_return()
		current = back.get("room", &"")
		hero_tile = back.get("spot", Vector2.ZERO) / WorldMap.TILE
	# Center on everything visited when it fits, otherwise on the hero; panning moves from there.
	var center := bounds.get_center() / WorldMap.TILE
	if tiles.x * scale > area.size.x or tiles.y * scale > area.size.y:
		center = hero_tile
	var span := tiles * scale
	_pan = _pan.clamp(-span, span)
	var offset := area.get_center() - center * scale - _pan

	for id: StringName in visited:
		var info: Dictionary = WorldMap.rooms()[id]
		var rect := Rect2(Vector2(info["origin"]) * scale + offset, Vector2(info["size"]) * scale)
		var color: Color = REGION_COLORS.get(info["region"], REGION_COLORS[&"hollow"])
		view.draw_rect(rect, Color(color.darkened(0.75), 0.85))
		view.draw_texture_rect(_ground_texture(id, color), rect, false)
		view.draw_rect(rect, INK if id != current else HERO, false, 1.0 if id != current else 1.5)
		for checkpoint: Vector2 in info["checkpoints"]:
			view.draw_circle(rect.position + checkpoint / WorldMap.TILE * scale, 1.5, Color(0.95, 0.9, 0.7))
		for door: Dictionary in info["doors"]:
			var gate: Vector2 = door["spot"] / WorldMap.TILE - Vector2(0, GATE_HEIGHT_TILES)
			_draw_diamond(rect.position + gate * scale, 4.0, color, GameState.best_time(door["target"]) != INF)
	if current != &"" and fmod(_time, 0.8) < 0.55:
		view.draw_circle(hero_tile * scale + offset - Vector2(0, scale), 2.5, HERO)


func _draw_diamond(center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if filled:
		view.draw_colored_polygon(points, color.lightened(0.3))
	points.append(points[0])
	view.draw_polyline(points, Color.WHITE, 1.0)


func _visited_rooms() -> Array[StringName]:
	var found: Array[StringName] = []
	for id: StringName in WorldMap.rooms():
		if WorldMap.is_spirit_room(id):
			continue
		if GameState.has_visited(id) or (game.room and game.room.room_id == id):
			found.append(id)
	return found


func _ground_texture(id: StringName, color: Color) -> ImageTexture:
	if not _ground.has(id):
		var rows: PackedStringArray = WorldMap.rooms()[id]["rows"]
		var size: Vector2i = WorldMap.rooms()[id]["size"]
		var image := Image.create_empty(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				var symbol := rows[y][x]
				if symbol in TerrainLayout.SOLID:
					image.set_pixel(x, y, color)
				elif symbol == "=":
					image.set_pixel(x, y, Color(color, 0.6))
		_ground[id] = ImageTexture.create_from_image(image)
	return _ground[id]
