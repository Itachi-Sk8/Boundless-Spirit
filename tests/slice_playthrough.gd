extends Node
## Plays the whole vertical slice start to finish through the real game, like a careful player:
## the Hollow, Ember Grove, the Spirit Room's gate, the orange unlock, leaving back through the
## gate, and the dash across the Hollow's gap to the end room. Fails at the first segment it
## can't clear. For now it skips the Spirit Room's run (it steps straight to the orb, until the
## room settles) and the walk home from Ember Gate (it starts again at the Hollow clearing).
## Uses save slot 9 and deletes it afterwards.
##
## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 res://tests/slice_playthrough.tscn
## Exit code is the number of failed checks.

const SLOT := 9
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"slide",
	&"grab", &"spirit", &"interact", &"pause", &"ui_accept",
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
		ember_gate, spirit_room, leave_spirit_room, back_to_the_hollow, dash_gap, meadow_end,
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
	# The clearing is open, flat ground: just run east.
	await run_until_room(&"hollow_east", 1.0)


func hollow_east_push_and_crumble() -> void:
	var block: PushBlock = main.room.find_children("*", "PushBlock", true, false)[0]
	_hold(&"move_right")
	await until(func() -> bool: return hero.adjacent_block(1) == block, 240)
	_hold(&"grab")
	await until(func() -> bool: return block.global_position.x >= 1431.0, 600)
	_release_all()
	check("pushed the stone against the high ledge", absf(block.global_position.x - 1432.0) < 2.0,
			"stone at %.1f" % block.global_position.x)
	await leap(1432.0, 224.0, "onto the stone")
	await leap(1480.0, 160.0, "from the stone onto the ledge")
	await run_to(1558.0)
	await leap(1672.0, 160.0, "onto the crumbling ledge over the thorns")
	await leap(1820.0, 160.0, "off the crumbling ledge onto the long platform")
	await run_until_room(&"ember_entry", 1.0)


func ember_entry() -> void:
	await run_to(2470.0)
	await leap(2600.0, 192.0, "up onto the crumbling ledge over the pit")
	await leap(2740.0, 240.0, "down to the far floor")
	await run_to(2820.0)
	await leap(2936.0, 240.0, "over the leaf dip")
	await run_until_room(&"ember_leaves", 1.0)


func ember_leaves() -> void:
	await run_to(3102.0)
	for target: Vector2 in [Vector2(3176, 240), Vector2(3256, 224), Vector2(3336, 240), Vector2(3400, 208),
			Vector2(3480, 224), Vector2(3544, 240), Vector2(3608, 208), Vector2(3682, 240)]:
		await leap(target.x, target.y, "to (%d, %d) over the thorns" % [target.x, target.y])
		if _aborted:
			return
	await run_until_room(&"ember_climb", 1.0)


func ember_climb() -> void:
	# Up the low ledges, over the floor thorns, and back left onto the shelf and the block above it.
	await run_to(4230.0)
	await leap(4288.0, 192.0, "onto the low ledge")
	await leap(4424.0, 144.0, "over the thorns onto the plank")
	await run_to(4458.0)
	await leap(4552.0, 96.0, "onto the right-hand ledge")
	await leap(4440.0, 32.0, "back up onto the end of the shelf")
	await leap(4376.0, -32.0, "up onto the block over the shelf")
	await run_to(4285.0)
	await leap(4216.0, -64.0, "onto the step under the crumbling ledges")
	if _aborted:
		return
	# The crumbling ledges zigzag up the shaft, lowest first; each falls soon after landing.
	var ledges := main.room.find_children("*", "CrumblePlatform", true, false)
	ledges.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.y > b.global_position.y)
	for ledge: CrumblePlatform in ledges:
		var middle := ledge.global_position.x + ledge.width_tiles * 8.0
		await leap(middle, ledge.global_position.y, "onto the crumbling ledge at height %d" % roundi(-ledge.global_position.y))
		if _aborted:
			return
	await leap(4120.0, -512.0, "off the last ledge onto the top corridor")
	await run_until_room(&"ember_gate", -1.0)


func ember_gate() -> void:
	var gate: SpiritGate = main.room.find_children("*", "SpiritGate", true, false)[0]
	_hold(&"move_left")
	var shown := await until(func() -> bool: return gate.hint.visible, 600)
	_release_all()
	await frames(10)
	check("walking into the Spirit Room's gate shows the Interact key", shown, str(hero.global_position))
	await _tap(&"interact")
	var asked := await until(func() -> bool: return main.confirm.visible, 60)
	check("pressing Interact at the gate asks if you're ready", asked, str(hero.global_position))
	if not asked:
		_aborted = true
		return
	await frames(3)
	await _tap(&"jump")
	var entered := await until(func() -> bool: return main.room.room_id == &"ember_spirit_room" and not main.transitioning, 120)
	check("answering Yes enters the Spirit Room at its start", entered
			and hero.global_position.distance_to(main.room.named_spawn(&"Start")) < 2.0, str(hero.global_position))
	check("entering the Spirit Room starts a timed run", main._run_active, "")
	if not entered:
		_aborted = true


func spirit_room() -> void:
	# The run itself is skipped until the room settles: step down beside the orb and walk in.
	var orb: ColorOrb = main.room.find_children("*", "ColorOrb", true, false)[0]
	hero.global_position = Vector2(orb.global_position.x + 40.0, main.room.world_bounds().position.y + 256.0)
	hero.velocity = Vector2.ZERO
	await frames(10)
	await run_to(orb.global_position.x)
	var absorbed := func() -> bool:
		return GameState.has_color(GameState.SpiritColor.ORANGE) and not hero.frozen and not hero.input_locked
	await until(absorbed, 300)
	check("touching the orange color unlocks it after landing", GameState.has_color(GameState.SpiritColor.ORANGE)
			and hero.is_on_floor(), str(hero.global_position))
	check("control comes back with no card in the way", not hero.frozen and not hero.input_locked, "")
	check("the run is recorded quietly", GameState.best_time(&"ember_spirit_room") < INF
			and GameState.clear_deaths.has("ember_spirit_room"), GameState.format_time(GameState.best_time(&"ember_spirit_room")))
	if not GameState.has_color(GameState.SpiritColor.ORANGE):
		_aborted = true


func leave_spirit_room() -> void:
	if _aborted:
		return
	var exits := main.room.find_children("*", "SpiritGate", true, false).filter(
			func(gate: SpiritGate) -> bool: return gate.mode == SpiritGate.Mode.EXIT)
	if exits.is_empty():
		print("    (no exit gate in the room yet: leaving from the pause menu)")
		await _tap(&"pause")
		# Rows: Resume, Map, Settings, Leave Spirit Room, Quit.
		for i in 3:
			await _tap(&"move_down")
		await _tap(&"ui_accept")
	else:
		# Like the run, the way to the exit gate is skipped for now: step into its doorway.
		var exit: SpiritGate = exits[0]
		hero.global_position = exit.global_position
		hero.velocity = Vector2.ZERO
		await frames(10)
		check("the exit gate is open once the color is taken", exit.is_open(), "")
		await _tap(&"interact")
	var back := await until(func() -> bool: return main.room.room_id == &"ember_gate" and not main.transitioning, 180)
	var gate: SpiritGate = main.room.find_children("*", "SpiritGate", true, false)[0] if back else null
	check("leaving the Spirit Room goes back to the gate it was entered through", back
			and hero.global_position.distance_to(gate.global_position) < 2.0, "%s at %s" % [main.room.room_id, hero.global_position])
	if not back:
		_aborted = true


func back_to_the_hollow() -> void:
	if _aborted:
		return
	# The walk home from Ember Gate isn't played yet: start again at the clearing's west side.
	main._enter_world_room(&"hollow_clearing", Vector2(40, 240))
	await frames(5)
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

## Press and release a button, two frames each.
func _tap(action: StringName) -> void:
	_hold(action)
	await frames(2)
	_release(action)
	await frames(2)


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
		# The margin covers the run-up: the hero isn't at full speed the moment it jumps.
		if landed_frame / 60.0 * t.run_speed >= distance + 24.0:
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
