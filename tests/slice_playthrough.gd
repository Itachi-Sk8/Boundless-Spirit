extends Node
## Plays the whole vertical slice start to finish through the real game, like a careful player:
## the Hollow, Ember Grove, the Spirit Room and its orange unlock, the shortcut gate, and the
## dash across the Hollow's gap to the end room. Fails at the first segment it can't clear.
## Uses save slot 9 and deletes it afterwards.
##
## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 res://tests/slice_playthrough.tscn
## Exit code is the number of failed checks.

const SLOT := 9
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"slide",
	&"grab", &"spirit",
]

var main: Main
var hero: Player
var _checks := 0
var _failures := 0
var _aborted := false


func _ready() -> void:
	GameState.slot = SLOT
	GameState.delete_save()
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	hero = main.player
	_run.call_deferred()


func _run() -> void:
	await frames(10)
	var segments: Array[Callable] = [
		hollow_clearing_east, hollow_east_push_and_crumble, ember_entry, ember_leaves, ember_climb,
		ember_gate, spirit_room, shortcut_home, dash_gap, meadow_end,
	]
	for segment in segments:
		if _aborted:
			break
		await segment.call()
	_release_all()
	if not _aborted:
		check("the save remembers the end room", GameState.load_game(SLOT) and GameState.room_id == &"meadow_edge",
				str(GameState.room_id))
	GameState.delete_save()
	await frames(5)
	print("\n%d checks, %d failed%s" % [_checks, _failures, " (stopped early)" if _aborted else ""])
	get_tree().quit(_failures)


# --- Route ---------------------------------------------------------------------------------

func hollow_clearing_east() -> void:
	check("starts in the Hollow clearing", main.room.room_id == &"hollow_clearing", str(main.room.room_id))
	# Over the thorns, wherever they are on the clearing's floor (moved and resized in the editor).
	var thorns := main.room.get_node(^"Hazards").get_child(0) as Thorns
	var hurt := thorns.get_global_transform() * thorns.hurt_rect()
	await run_to(hurt.position.x - 40.0)
	await leap(hurt.end.x + 22.0, 240.0, "over the thorns")
	await run_to(325.0)
	await leap(390.0, 208.0, "up onto the ledge")
	await run_to(436.0)
	await leap(540.0, 240.0, "over the pit")
	await run_until_room(&"hollow_east", 1.0)


func hollow_east_push_and_crumble() -> void:
	var block: PushBlock = main.room.find_children("*", "PushBlock", true, false)[0]
	_hold(&"move_right")
	await until(func() -> bool: return hero.adjacent_block(1) == block, 240)
	_hold(&"grab")
	await until(func() -> bool: return block.global_position.x >= 1111.0, 600)
	_release_all()
	check("pushed the stone against the high ledge", absf(block.global_position.x - 1112.0) < 2.0,
			"stone at %.1f" % block.global_position.x)
	await leap(1112.0, 224.0, "onto the stone")
	await leap(1160.0, 160.0, "from the stone onto the ledge")
	await run_to(1238.0)
	await leap(1304.0, 160.0, "onto the crumbling ledge")
	await leap(1400.0, 160.0, "off the crumbling ledge before it falls")
	await run_until_room(&"ember_entry", 1.0)


func ember_entry() -> void:
	await run_to(1702.0)
	await leap(1768.0, 208.0, "onto the first crumbling ledge")
	await leap(1848.0, 192.0, "onto the second crumbling ledge")
	await leap(1928.0, 208.0, "onto the third crumbling ledge")
	await leap(2000.0, 240.0, "down to the far floor")
	await run_to(2068.0)
	await leap(2184.0, 240.0, "over the leaf dip")
	await run_until_room(&"ember_leaves", 1.0)


func ember_leaves() -> void:
	await run_to(2350.0)
	for target: Vector2 in [Vector2(2424, 240), Vector2(2504, 224), Vector2(2584, 240), Vector2(2648, 208),
			Vector2(2728, 224), Vector2(2792, 240), Vector2(2856, 208), Vector2(2930, 240)]:
		await leap(target.x, target.y, "to (%d, %d) over the thorns" % [target.x, target.y])
		if _aborted:
			return
	await run_until_room(&"ember_climb", 1.0)


func ember_climb() -> void:
	await run_to(3160.0)
	await leap(3200.0, 192.0, "onto the first ledge")
	await run_to(3240.0)
	await leap(3336.0, 144.0, "onto the plank")
	await run_to(3370.0)
	await leap(3464.0, 96.0, "onto the right-hand ledge")
	await run_to(3430.0)
	await leap(3330.0, 48.0, "onto the long shelf")
	if _aborted:
		return
	var block: PushBlock = main.room.find_children("*", "PushBlock", true, false)[0]
	_hold(&"move_left")
	await until(func() -> bool: return hero.adjacent_block(-1) == block, 240)
	_hold(&"grab")
	_release(&"move_left")
	_hold(&"move_right")
	await until(func() -> bool: return block.global_position.x >= 3223.0, 240)
	_release_all()
	check("pulled the stone out of its niche", block.global_position.x >= 3220.0,
			"stone at %.1f" % block.global_position.x)
	await frames(5)
	await leap(block.global_position.x, block.global_position.y - 16.0, "onto the pulled stone")
	await leap(3262.0, -32.0, "from the stone onto the upper shelf")
	await leap(3120.0, -64.0, "to the exit ledge")
	await run_until_room(&"ember_gate", -1.0)


func ember_gate() -> void:
	_hold(&"move_left")
	var asked := await until(func() -> bool: return main.confirm.visible, 600)
	_release_all()
	check("walking into the Spirit Room's door asks if you're ready", asked, str(hero.global_position))
	if not asked:
		_aborted = true
		return
	await frames(3)
	_hold(&"jump")
	await frames(2)
	_release(&"jump")
	var entered := await until(func() -> bool: return main.room.room_id == &"ember_spirit_room" and not main.transitioning, 120)
	check("answering Yes enters the Spirit Room at its start", entered
			and hero.global_position.distance_to(main.room.named_spawn(&"Start")) < 2.0, str(hero.global_position))
	check("entering the Spirit Room starts a timed run", main._run_active, "")
	if not entered:
		_aborted = true


func spirit_room() -> void:
	await run_to(2432.0)
	await leap(2340.0, -64.0, "over the first thorn pit")
	await run_to(2318.0)
	await leap(2196.0, -64.0, "over the second thorn pit")
	await run_to(2152.0)
	await leap(2028.0, -64.0, "under the thorn ceiling", 46.0)
	await run_to(1962.0)
	await leap(1896.0, -96.0, "onto crumbling ledge 1")
	await leap(1800.0, -112.0, "onto crumbling ledge 2")
	await leap(1704.0, -96.0, "onto crumbling ledge 3")
	await leap(1600.0, -64.0, "to the floor before the stone")
	if _aborted:
		return
	var block: PushBlock = main.room.find_children("*", "PushBlock", true, false)[0]
	_hold(&"move_left")
	await until(func() -> bool: return hero.adjacent_block(-1) == block, 120)
	_hold(&"grab")
	await until(func() -> bool: return block.global_position.x <= 1449.0, 600)
	_release_all()
	check("pushed the stone under the thorn ceiling to the wall", block.global_position.x <= 1449.0,
			str(block.global_position))
	await frames(5)
	await leap(1448.0, -80.0, "onto the stone")
	await leap(1400.0, -144.0, "from the stone up the wall")
	await run_to(1318.0)
	for target: Vector2 in [Vector2(1272, -96), Vector2(1208, -80), Vector2(1144, -96), Vector2(1052, -96)]:
		await leap(target.x, target.y, "to (%d, %d) over the last thorns" % [target.x, target.y], 30.0)
		if _aborted:
			return
	var absorbed := func() -> bool:
		return GameState.has_color(GameState.SpiritColor.ORANGE) and not hero.frozen and not hero.input_locked
	await until(absorbed, 300)
	check("touching the orange color unlocks it after landing", GameState.has_color(GameState.SpiritColor.ORANGE)
			and hero.is_on_floor(), str(hero.global_position))
	check("control comes back with no card in the way", not hero.frozen and not hero.input_locked, "")
	check("the run is recorded quietly", GameState.best_time(&"ember_spirit_room") < INF
			and GameState.clear_deaths.has("ember_spirit_room"), GameState.format_time(GameState.best_time(&"ember_spirit_room")))
	print("    Spirit Room run: %s" % GameState.format_time(GameState.best_time(&"ember_spirit_room")))


func shortcut_home() -> void:
	await run_until_room(&"hollow_east", -1.0)
	check("the orange gate opened the shaft down into the Hollow", main.room.room_id == &"hollow_east", "")
	await until(func() -> bool: return hero.is_on_floor(), 120)
	_hold(&"move_left")
	await until(func() -> bool: return GameState.has_flag(&"hollow_shortcut"), 180)
	check("the shortcut gate opens from the far side", GameState.has_flag(&"hollow_shortcut"), "")
	await run_until_room(&"hollow_clearing", -1.0)
	await run_to(514.0)
	await leap(420.0, 208.0, "back up onto the clearing's ledge")
	# From the end of the ledge, over the thorns below it.
	var thorns := main.room.get_node(^"Hazards").get_child(0) as Thorns
	var hurt := thorns.get_global_transform() * thorns.hurt_rect()
	await run_to(360.0)
	await leap(minf(hurt.position.x - 24.0, 300.0), 240.0, "back over the thorns")
	await run_until_room(&"hollow_west", -1.0)


func dash_gap() -> void:
	await run_to(-100.0)
	await leap(-150.0, 224.0, "onto the little rise")
	if _aborted:
		return
	var deaths := GameState.deaths
	# Run at the gap, jump from its edge, and dash left at the top of the jump.
	_hold(&"move_left")
	await until(func() -> bool: return hero.global_position.x <= -282.0, 300)
	_hold(&"jump")
	await until(func() -> bool: return hero.velocity.y >= 0.0, 60)
	_hold(&"dash")
	await frames(2)
	_release(&"dash")
	_release(&"jump")
	await until(func() -> bool: return hero.is_on_floor() or GameState.deaths > deaths, 120)
	_release(&"move_left")
	check("dashed across the Hollow's wide gap", GameState.deaths == deaths and hero.global_position.x < -512.0,
			"at %s, deaths %d" % [hero.global_position, GameState.deaths - deaths])
	if GameState.deaths != deaths:
		_aborted = true


func meadow_end() -> void:
	await run_until_room(&"meadow_edge", -1.0)
	await run_to(-830.0)
	await frames(10)
	check("the end message shows", main.prompt.modulate.a > 0.1 and main.prompt.text.contains("Thanks for playing"),
			main.prompt.text)


# --- Moves ---------------------------------------------------------------------------------

## Run toward world x, stopping there.
func run_to(x: float) -> void:
	if _aborted:
		return
	var direction := signf(x - hero.global_position.x)
	var action := &"move_right" if direction > 0.0 else &"move_left"
	_hold(action)
	await until(func() -> bool: return (hero.global_position.x - x) * direction >= 0.0 or main.transitioning, 600)
	_release(action)


## Keep running until the game is in room `id`.
func run_until_room(id: StringName, direction: float) -> void:
	if _aborted:
		return
	var action := &"move_right" if direction > 0.0 else &"move_left"
	_hold(action)
	var arrived := await until(func() -> bool: return main.room.room_id == id and not main.transitioning, 900)
	_release(action)
	check("reached %s" % id, arrived, "in %s at %s" % [main.room.room_id, hero.global_position])
	if not arrived:
		_aborted = true


## Jump to a landing spot: world x and the surface's y. Picks the hold time from the jump
## physics so the hero clears the distance without going higher than `max_rise`, steers until
## over the spot, then lets go of the direction to land on it.
func leap(x: float, surface_y: float, label: String, max_rise := 200.0) -> void:
	if _aborted:
		return
	var deaths := GameState.deaths
	var direction := signf(x - hero.global_position.x)
	var action := &"move_right" if direction > 0.0 else &"move_left"
	var hold := _plan_hold(hero.global_position.y - surface_y, absf(x - hero.global_position.x), max_rise)
	_hold(action)
	_hold(&"jump")
	for i in 180:
		await frames(1)
		if i + 1 >= hold:
			_release(&"jump")
		if (hero.global_position.x - x) * direction >= -1.0:
			_release(action)
		if GameState.deaths > deaths:
			break
		if i > 3 and (hero.is_on_floor() or hero.frozen):
			break
	_release_all()
	await frames(2)
	# Frozen means it touched a color orb on the way, which is as good as landing.
	var landed := GameState.deaths == deaths and (hero.frozen or absf(hero.global_position.y - surface_y) < 6.0)
	check("leap " + label, landed, "at %s, aim (%.0f, %.0f)%s" % [hero.global_position, x, surface_y,
			", died" if GameState.deaths > deaths else ""])
	if not landed:
		_aborted = true


## The shortest jump hold (in frames) that reaches `rise` px up and covers `distance` px,
## by stepping the same jump physics the hero uses.
func _plan_hold(rise: float, distance: float, max_rise: float) -> int:
	var t := hero.tuning
	var best := 18
	for hold in range(1, 19):
		var y := 0.0
		var vy := -t.jump_speed
		var top := 0.0
		var landed_frame := -1
		for frame in 240:
			if frame >= hold:
				vy = minf(vy + t.gravity / 60.0, t.max_fall_speed)
			y += vy / 60.0
			top = minf(top, y)
			if vy > 0.0 and y >= -rise:
				landed_frame = frame
				break
		if -top > max_rise:
			return maxi(1, hold - 1)
		if landed_frame < 0 or -top < rise + 10.0:
			continue
		if landed_frame / 60.0 * t.run_speed >= distance + 10.0:
			return hold
		best = hold
	return best


# --- Harness -------------------------------------------------------------------------------

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


func _hold(action: StringName) -> void:
	Input.action_press(action)


func _release(action: StringName) -> void:
	Input.action_release(action)


func _release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)
