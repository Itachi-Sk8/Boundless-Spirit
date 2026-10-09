extends Node
## Checks every hazard, object, and creature in the gallery room (rooms/test/gallery.tscn)
## through the real game: each one is tried with the hero placed beside it. Uses save slot 9
## and deletes it afterwards.
##
## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 res://tests/hazards.tscn
## Exit code is the number of failed checks.

const SLOT := 9
const GALLERY := "res://rooms/test/gallery.tscn"
const T := 16.0
## The gallery's floor surface.
const FLOOR := 256.0

var main: Main
var hero: Player
var _checks := 0
var _failures := 0
var _held: Array[StringName] = []


func _ready() -> void:
	GameState.slot = SLOT
	GameState.delete_save()
	GameState.pending_room_scene = GALLERY
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	hero = main.player
	# A check that errors out never returns; give up rather than hang.
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		print("
TIMED OUT after %d checks, %d failed" % [_checks, _failures])
		get_tree().quit(100))
	_run.call_deferred()


func _run() -> void:
	await frames(5)
	GameState.set_all_colors(true)
	check("the gallery loads", main.room.scene_file_path == GALLERY, main.room.scene_file_path)
	for test: Callable in [test_head_thorns, test_vines, test_barrier, test_one_way, test_flower, test_plate_door,
			test_breakable_wall, test_wind, test_updraft, test_waterfall, test_water, test_branch,
			test_stalactite, test_falling_log, test_rolling_logs, test_bee, test_boar, test_snail]:
		await test.call()
		_release_all()
		await _alive()
	GameState.delete_save()
	await frames(5)
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(_failures)


func test_head_thorns() -> void:
	# Ceiling thorns just low enough to touch the top of the drawn head (4 px above the
	# collision box), but not the box itself.
	var thorns: Thorns = load("res://entities/thorns.tscn").instantiate()
	thorns.direction = Thorns.Direction.DOWN
	main.room.get_node(^"Hazards").add_child(thorns)
	var top_of_head := FLOOR - hero.tuning.stand_size.y - hero.tuning.hurtbox_head_reach
	thorns.global_position = Vector2(4 * T, top_of_head + 1.0 - thorns.hurt_rect().end.y)
	place(4 * T + 8, FLOOR)
	check("ceiling thorns kill when they touch the hero's head",
			await until(func() -> bool: return hero.state_name == &"dead", 10), "")
	await _alive()
	thorns.global_position.y -= 2.0
	place(4 * T + 8, FLOOR)
	await frames(10)
	check("  but not when they're just above it", hero.state_name != &"dead", "")
	thorns.direction = Thorns.Direction.UP
	thorns.length = 2
	thorns.adjust_px = -5
	check("thorns can be a few pixels shorter than whole tiles", thorns.length_px() == 27
			and thorns.hurt_rect() == Rect2(2, 7, 23, 9) and thorns.art_rect().size == Vector2(27, 16),
			str(thorns.hurt_rect()))
	thorns.adjust_px = 6
	check("  or longer", thorns.hurt_rect().size.x == 34, str(thorns.hurt_rect()))
	thorns.queue_free()


# --- Objects --------------------------------------------------------------------------------

func test_vines() -> void:
	place(14 * T + 8, 10 * T)
	_hold(&"grab")
	check("holding Grab on vines climbs them", await until(func() -> bool: return hero.state_name == &"climb", 30),
			hero.state_name)
	_hold(&"move_up")
	var y := hero.global_position.y
	await frames(20)
	check("  and up moves up them", hero.global_position.y < y - 10.0, "%.0f -> %.0f" % [y, hero.global_position.y])


func test_barrier() -> void:
	place(19 * T, FLOOR)
	_hold(&"move_right")
	await frames(60)
	var barrier := _node(^"Entities/SpiritBarrier") as Node2D
	check("a spirit barrier stops the hero", hero.global_position.x < barrier.global_position.x,
			"%.0f vs %.0f" % [hero.global_position.x, barrier.global_position.x])


func test_one_way() -> void:
	place(28 * T, FLOOR)
	await frames(2)
	_hold(&"jump")
	await frames(40)
	_release(&"jump")
	await until(func() -> bool: return hero.is_on_floor(), 60)
	check("jumping up through a one-way platform lands on top", absf(hero.global_position.y - 12 * T) < 2.0,
			str(hero.global_position))


func test_flower() -> void:
	place(34 * T + 8, 200)
	hero.air_dashes_left = 0
	var top := hero.global_position.y
	for i in 70:
		await frames(1)
		top = minf(top, hero.global_position.y)
	check("a bounce flower throws the hero high", top < 140.0, "highest %.0f" % top)
	check("  and refills the dash", hero.air_dashes_left > 0, "")


func test_plate_door() -> void:
	var door := _node(^"Entities/PlateDoor") as PlateDoor
	var plate := _node(^"Entities/PressurePlate") as PressurePlate
	place(plate.global_position.x, FLOOR)
	await frames(10)
	check("standing on a pressure plate opens its door", plate.pressed and door.is_open, "")
	place(36 * T, FLOOR)
	await frames(30)
	check("stepping off shuts it", not plate.pressed and not door.is_open, "")
	var block := _node(^"Entities/PushBlock") as PushBlock
	block.global_position = plate.global_position
	await frames(10)
	check("a push block on the plate holds it open", plate.pressed and door.is_open, "")
	main.room.reset_room()
	await frames(5)


func test_breakable_wall() -> void:
	var wall := _node(^"Entities/BreakableWall") as BreakableWall
	place(49 * T, FLOOR)
	await frames(2)
	_hold(&"move_right")
	await frames(2)
	_hold(&"dash")
	await frames(30)
	check("dashing into a breakable wall shatters it", wall.broken, str(hero.global_position))
	_release_all()
	main.room.reset_room()
	await frames(2)
	check("  and it comes back when the room resets (no flag)", not wall.broken, "")


func test_wind() -> void:
	place(58 * T, FLOOR)
	await frames(40)
	check("wind carries a standing hero along", hero.global_position.x > 58 * T + 20.0, "%.0f" % hero.global_position.x)


func test_updraft() -> void:
	var gust := _node(^"Entities/Updraft") as WindGust
	await until(func() -> bool: return not gust.blowing, 200)
	await until(func() -> bool: return gust.blowing, 200)
	place(67 * T + 8, FLOOR)
	var top := hero.global_position.y
	for i in 50:
		await frames(1)
		top = minf(top, hero.global_position.y)
	check("an updraft lifts the hero while it blows", top < FLOOR - 48.0, "highest %.0f" % top)


func test_waterfall() -> void:
	var normal := await _jump_height(70 * T)
	var under := await _jump_height(73 * T)
	check("a waterfall presses a jump down", under < normal * 0.5, "%.0f px under it, %.0f px outside" % [under, normal])


func test_water() -> void:
	var deaths := GameState.deaths
	place(80 * T, 220)
	check("falling into water is death", await until(func() -> bool: return GameState.deaths > deaths, 60), "")


func test_branch() -> void:
	var branch := _node(^"Entities/SwayingBranch") as SwayingBranch
	var x := branch.global_position.x
	await frames(30)
	check("a branch sways", absf(branch.global_position.x - x) > 2.0, "")
	place(branch.global_position.x + 24, branch.global_position.y - 1)
	await frames(5)
	var start := hero.global_position.x
	await frames(40)
	check("  carrying the hero standing on it", hero.is_on_floor() and absf(hero.global_position.x - start) > 4.0,
			"%.0f -> %.0f" % [start, hero.global_position.x])


# --- Hazards --------------------------------------------------------------------------------

func test_stalactite() -> void:
	var stalactite := _node(^"Hazards/Stalactite1") as FallingHazard
	var deaths := GameState.deaths
	place(stalactite.global_position.x, FLOOR)
	check("a stalactite falls on the hero beneath it", await until(func() -> bool: return GameState.deaths > deaths, 120), "")
	await _alive()
	check("  and is back in place after the death", stalactite.phase == FallingHazard.Phase.HANGING, "")
	place(stalactite.global_position.x, FLOOR)
	await until(func() -> bool: return stalactite.phase == FallingHazard.Phase.FALLING, 60)
	place(100 * T, FLOOR)
	check("one that misses shatters on the floor", await until(func() -> bool: return stalactite.phase == FallingHazard.Phase.GONE, 90), "")
	check("  and grows back", await until(func() -> bool: return stalactite.phase == FallingHazard.Phase.HANGING, 200), "")


func test_falling_log() -> void:
	var falling := _node(^"Hazards/FallingLog") as FallingHazard
	var deaths := GameState.deaths
	place(falling.global_position.x - 16, FLOOR)
	check("a falling log drops on the hero beneath it", await until(func() -> bool: return GameState.deaths > deaths, 120), "")


func test_rolling_logs() -> void:
	var deaths := GameState.deaths
	place(130 * T, FLOOR)
	check("rolling logs run the hero over", await until(func() -> bool: return GameState.deaths > deaths, 240), "")
	await _alive()
	var logs := _node(^"Hazards/RollingLogs") as RollingLogs
	place(118 * T, FLOOR)
	var seen := await until(func() -> bool: return logs.get_child_count() > 0, 240)
	var gone := await until(func() -> bool: return logs.get_child_count() == 0, 300)
	check("a log smashes against the bump in its way", seen and gone, "")


# --- Creatures ------------------------------------------------------------------------------

func test_bee() -> void:
	var bee := _node(^"Entities/Bee") as Bee
	main.room.reset_room()
	await frames(2)
	place(bee.global_position.x, FLOOR)
	check("a bee dives at the hero beneath it", await until(func() -> bool: return bee.state == Bee.State.DIVE, 60), "")
	place(136 * T, FLOOR)
	check("  hits the ground and is dazed", await until(func() -> bool: return bee.state == Bee.State.DAZED, 60), "")
	check("  then flies back up to its loop", await until(func() -> bool: return bee.state == Bee.State.PATROL, 200), "")
	# Lure it into thorns.
	var thorns: Thorns = load("res://entities/thorns.tscn").instantiate()
	main.room.get_node(^"Hazards").add_child(thorns)
	thorns.global_position = Vector2(roundf(bee.global_position.x) - 8.0, FLOOR - T)
	var x := bee.global_position.x
	await frames(1)
	bee.set_physics_process(false)
	place(x + 12.0, FLOOR)
	bee.global_position.x = x
	bee.set_physics_process(true)
	check("a bee that dives into thorns dies", await until(func() -> bool: return bee.state == Bee.State.DEAD, 120), "")
	thorns.queue_free()
	main.room.reset_room()
	await frames(2)
	check("  and is back when the room resets", bee.state != Bee.State.DEAD and bee.visible, "")


func test_boar() -> void:
	var boar := _node(^"Entities/Boar") as Boar
	var wall := _node(^"Entities/BoarWall") as BreakableWall
	main.room.reset_room()
	await frames(2)
	var deaths := GameState.deaths
	place(boar.global_position.x - 90.0, FLOOR)
	check("a boar charges a hero it sees and kills", await until(func() -> bool: return GameState.deaths > deaths, 150), "")
	await _alive()
	boar.facing = 1
	place(161 * T, FLOOR)
	check("  (charging at a hero ahead)", await until(func() -> bool: return boar.state == Boar.State.CHARGE, 60), "")
	place(140 * T, FLOOR)
	check("a charge smashes a breakable wall", await until(func() -> bool: return wall.broken, 120), "")
	check("  and ends dazed against the next wall", await until(func() -> bool: return boar.state == Boar.State.DAZED, 180), "")


func test_snail() -> void:
	var snail := _node(^"Entities/Snail") as Snail
	main.room.reset_room()
	place(150 * T, FLOOR)
	check("a snail crawls over the edge and down the wall",
			await until(func() -> bool: return snail._normal == Vector2i.RIGHT, 360), str(snail._normal))
	place(snail.global_position.x + 16.0, FLOOR)
	check("it hides when the hero comes near", await until(func() -> bool: return snail.state == Snail.State.HIDDEN, 60), "")
	check("  and its shell is solid (a push block)", snail.collision_layer == 1 << 4, "")
	check("  and drops to the floor", await until(func() -> bool: return snail.is_on_floor(), 60), "")
	place(150 * T, FLOOR)
	check("it comes out once the hero is gone", await until(func() -> bool: return snail.state == Snail.State.CRAWL, 240), "")


# --- Helpers --------------------------------------------------------------------------------

func place(x: float, y: float) -> void:
	_release_all()
	hero.respawn(Vector2(x, y), true)
	main.camera.snap_to_target()


func _jump_height(x: float) -> float:
	place(x, FLOOR)
	await frames(3)
	_hold(&"jump")
	var top := FLOOR
	for i in 50:
		await frames(1)
		top = minf(top, hero.global_position.y)
	_release(&"jump")
	await until(func() -> bool: return hero.is_on_floor(), 90)
	return FLOOR - top


func _node(path: NodePath) -> Node:
	return main.room.get_node(path)


func _alive() -> void:
	await until(func() -> bool: return hero.state_name != &"dead" and not hero.frozen, 120)
	await frames(2)


func _hold(action: StringName) -> void:
	Input.action_press(action)
	_held.append(action)


func _release(action: StringName) -> void:
	Input.action_release(action)
	_held.erase(action)


func _release_all() -> void:
	for action in _held.duplicate():
		_release(action)


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func until(condition: Callable, limit: int) -> bool:
	for i in limit:
		await get_tree().process_frame
		if condition.call():
			return true
	return false


func check(label: String, passed: bool, detail := "") -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s  %s%s" % ["PASS" if passed else "FAIL", label, "  (%s)" % detail if detail else ""])
