extends Node
## Plays Sunlit Meadow (region 2) through the real game, room by room, with orange (dash)
## already returned: from Meadow Edge west to the Meadow Spirit Room and the yellow color.
## Every route is a fixed list of button presses timed in frames, so a route that passes
## proves each jump can be made. Fails at the first move it can't make.
## Uses save slot 9 and deletes it afterwards.
##
## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 res://tests/meadow_playthrough.tscn
## Start at a later room (entering from its east side) with `-- --from=<room id>`, and print
## the hero's path during every timed move with `-- --trace`.
## Exit code is the number of failed checks.

const SLOT := 9
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"slide",
	&"grab", &"spirit", &"interact", &"pause", &"ui_accept",
]
const TILE := 16.0

var main: Main
var hero: Player
var _checks := 0
var _failures := 0
var _aborted := false
var _trace := false


func _ready() -> void:
	GameState.slot = SLOT
	GameState.delete_save()
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	hero = main.player
	_run.call_deferred()


func _run() -> void:
	await frames(5)
	var from := &"meadow_edge"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			from = StringName(arg.substr(7))
		elif arg == "--trace":
			_trace = true
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	var segments: Array = [
		[&"meadow_edge", meadow_edge], [&"meadow_hop", meadow_hop], [&"meadow_shaft", meadow_shaft],
		[&"meadow_embers", meadow_embers], [&"meadow_flowers", meadow_flowers],
		[&"meadow_breakers", meadow_breakers], [&"meadow_bees", meadow_bees],
		[&"meadow_thicket", meadow_thicket],
		[&"meadow_gate", meadow_gate], [&"meadow_spirit_room", meadow_spirit_room],
	]
	var started := false
	for segment: Array in segments:
		if not started and segment[0] != from:
			continue
		if not started:
			started = true
			main._enter_world_room(segment[0], _east_spawn(segment[0]))
			await frames(5)
		if _aborted:
			break
		print("--- %s" % segment[0])
		await segment[1].call()
	check("started at a known room", started, str(from))
	_release_all()
	GameState.delete_save()
	await frames(5)
	print("\n%d checks, %d failed%s" % [_checks, _failures, " (stopped early)" if _aborted else ""])
	get_tree().quit(_failures)


## Where a room is entered from the east: its East spawn, or its Start.
func _east_spawn(id: StringName) -> Vector2:
	var room: Room = load(WorldMap.scene_of(id)).instantiate()
	room.position = WorldMap.rect_px(id).position
	var spot := room.named_spawn(&"East")
	if spot == Vector2.INF:
		spot = room.named_spawn(&"Start")
	room.free()
	return spot


# --- Route ---------------------------------------------------------------------------------

func meadow_edge() -> void:
	await perform("jump over the bump", 15 * TILE, -1, [[0, &"jump", 18]], Vector2(4 * TILE, 15 * TILE))
	await run_until_room(&"meadow_hop", -1.0)


func meadow_hop() -> void:
	# The dip: jump from its edge and dash at the top of the jump.
	await perform("jump-dash over the dip", 58 * TILE + 2.0, -1, [[0, &"jump", 18], [24, &"dash", 2]],
			Vector2(41 * TILE, 15 * TILE))
	# The thorn pit to the higher ledge.
	await perform("jump-dash over the thorn pit", 38 * TILE + 2.0, -1, [[0, &"jump", 18], [25, &"dash", 2]],
			Vector2(24 * TILE, 13 * TILE))
	# The high ledge: jump, then dash up and left at the top.
	await perform("diagonal dash up to the high ledge", 17 * TILE, -1,
			[[0, &"jump", 18], [20, &"move_up", 14], [22, &"dash", 2]], Vector2(5 * TILE, 8 * TILE))
	await run_until_room(&"meadow_shaft", -1.0)


func meadow_shaft() -> void:
	# A: from the floor beside it, jump and dash straight up, then drift left onto it.
	await run_to_local(23.5 * TILE)
	await perform("jump and up-dash onto the first ledge", -INF, 0,
			[[0, &"jump", 18], [26, &"move_up", 14], [27, &"dash", 2], [36, &"move_left", 40]],
			Vector2(16 * TILE, 33 * TILE))
	# B: from A's left end, jump, then dash up-left.
	await run_to_local(14.5 * TILE)
	await perform("jump and diagonal dash onto the left ledge", -INF, 0,
			[[0, &"jump", 18], [25, &"move_up", 14], [25, &"move_left", 24], [27, &"dash", 2]],
			Vector2(6 * TILE, 26 * TILE))
	# C: from B's right end, the same to the right.
	await run_to_local(9.5 * TILE)
	await perform("jump and diagonal dash onto the right ledge", -INF, 0,
			[[0, &"jump", 18], [25, &"move_up", 14], [25, &"move_right", 34], [27, &"dash", 2]],
			Vector2(20 * TILE, 19 * TILE))
	# D: up-dash through the ember, then dash up-left onto the top ledge.
	await run_to_local(16.4 * TILE)
	await perform("up-dash through the ember, dash again to the top", -INF, 0,
			[[0, &"jump", 18], [26, &"move_up", 30], [27, &"dash", 2], [41, &"move_left", 60], [41, &"dash", 2]],
			Vector2(3 * TILE, 8 * TILE))
	await run_until_room(&"meadow_embers", -1.0)


func meadow_embers() -> void:
	await perform("jump-dash, ember, dash over the first pit", 54 * TILE + 2.0, -1,
			[[0, &"jump", 18], [24, &"dash", 2], [42, &"dash", 2]], Vector2(33 * TILE, 16 * TILE))
	await perform("hop and three dashes under the thorn ceiling", 28 * TILE + 2.0, -1,
			[[0, &"jump", 1], [10, &"dash", 2], [24, &"dash", 2], [38, &"dash", 2]], Vector2(8 * TILE, 16 * TILE))
	await run_until_room(&"meadow_flowers", -1.0)


func meadow_flowers() -> void:
	# F1: bounce, up-dash, and on over the wall.
	await perform("bounce and up-dash over the wall", 56 * TILE, -1,
			[[0, &"steer", 54.5 * TILE], [24, &"move_up", 14], [26, &"dash", 2], [36, &"steer", 46 * TILE]],
			Vector2(46 * TILE, 12 * TILE))
	# Drop into the pit beside the wall.
	await perform("drop into the pit", 40 * TILE + 4.0, -1, [[0, &"steer", 37 * TILE], [20, &"wait", 0]], Vector2(37 * TILE, 25 * TILE))
	# F2: bounce and dash left out through the opening before the thorns.
	await walk_onto_flower(33.5 * TILE)
	await perform("bounce and dash out under the thorns", -INF, 0,
			[[4, &"move_left", 4], [6, &"dash", 2], [10, &"steer", 26 * TILE]], Vector2(26 * TILE, 22 * TILE))
	# F3 to F4 to the way out: bounce, dash left at the top, land on the pillar's flower,
	# bounce, dash up-left.
	await walk_onto_flower(23.5 * TILE)
	# Rising off F3, dash left at the top and steer onto the pillar's flower; bounce off it
	# and dash up-left to the way out.
	await perform("bounce, dash left, and land on the pillar's flower", -INF, 0,
			[[0, &"steer", 7.5 * TILE], [26, &"move_left", 4], [28, &"dash", 2]],
			Vector2(7.5 * TILE, 23 * TILE), true)
	await perform("bounce and dash up-left to the way out", -INF, 0,
			[[20, &"move_up", 14], [20, &"move_left", 30], [22, &"dash", 2], [36, &"steer", 2 * TILE]],
			Vector2(2 * TILE, 13 * TILE))
	await run_until_room(&"meadow_breakers", -1.0)


func meadow_breakers() -> void:
	await run_to_local(43 * TILE)
	await perform("dash left through the cracked wall", -INF, 0, [[0, &"move_left", 6], [1, &"dash", 2]],
			Vector2(37 * TILE, 14 * TILE))
	await run_to_local(28 * TILE)
	await perform("dash down through the cracked floor", -INF, 0, [[0, &"move_down", 8], [2, &"dash", 2], [12, &"wait", 0]],
			Vector2(28 * TILE, 23 * TILE))
	await perform("dash down through the second cracked floor", -INF, 0, [[0, &"move_down", 8], [2, &"dash", 2], [12, &"wait", 0]],
			Vector2(28 * TILE, 29 * TILE))
	await run_to_local(26 * TILE)
	await perform("jump-dash over the thorns in the low corridor", 25 * TILE, -1, [[0, &"jump", 8], [6, &"dash", 2]],
			Vector2(16 * TILE, 29 * TILE))
	await run_to_local(14 * TILE)
	await perform("jump and up-dash through the cracked ceiling", -INF, 0,
			[[0, &"jump", 18], [11, &"move_up", 14], [13, &"dash", 2], [25, &"steer", 9.5 * TILE]],
			Vector2(9.5 * TILE, 22 * TILE))
	await run_to_local(8 * TILE + 6.0)
	await perform("jump and dash up-left through the corner block", -INF, 0,
			[[0, &"jump", 18], [24, &"move_up", 14], [24, &"move_left", 30], [26, &"dash", 2]],
			Vector2(3 * TILE, 15 * TILE))
	await run_until_room(&"meadow_bees", -1.0)


func meadow_bees() -> void:
	# Over the pit: the bee dives after the hero has gone, into the thorns.
	await perform("jump the bee's pit", 58.5 * TILE, -1, [[0, &"jump", 18]], Vector2(48 * TILE, 19 * TILE))
	# Pillar to pillar without stopping, before the bees overhead dive.
	await perform("jump-dash to the first pillar", 46 * TILE + 2.0, -1,
			[[0, &"jump", 18], [22, &"dash", 2], [34, &"steer", 35 * TILE]], Vector2(35 * TILE, 17 * TILE))
	await perform("jump-dash to the second pillar", 34 * TILE + 2.0, -1,
			[[0, &"jump", 18], [22, &"dash", 2], [34, &"steer", 23 * TILE]], Vector2(23 * TILE, 15 * TILE))
	await perform("jump-dash to the third pillar", 22 * TILE + 2.0, -1,
			[[0, &"jump", 18], [20, &"dash", 2], [32, &"steer", 12 * TILE]], Vector2(12 * TILE, 17 * TILE))
	await perform("jump off the last pillar", 11 * TILE + 2.0, -1, [[0, &"jump", 18], [12, &"steer", 3 * TILE]],
			Vector2(3 * TILE, 19 * TILE))
	await run_until_room(&"meadow_thicket", -1.0)


func meadow_thicket() -> void:
	# The chimney: the gap between its thorns is 8 px wider than the hero. Line up, jump,
	# up-dash through the ember, up-dash again, and step off onto the ledge.
	await line_up(77 * TILE)
	await perform("up the thorn chimney", -INF, 0,
			[[0, &"jump", 18], [26, &"move_up", 30], [27, &"dash", 2], [41, &"dash", 2], [55, &"steer", 70 * TILE]],
			Vector2(74 * TILE, 8 * TILE))
	# Off the ledge's end in a dash, and two more off the embers, under the thorns.
	await perform("three dashes off the ledge under the thorns", 60 * TILE + 2.0, -1,
			[[0, &"dash", 2], [14, &"dash", 2], [28, &"dash", 2], [40, &"steer", 41 * TILE]], Vector2(41 * TILE, 9 * TILE))
	# Down into the pit onto the flower, then up-dash at the top of the bounce onto the rock.
	await perform("drop onto the flower in the pit", 34 * TILE - 4.0, -1, [[0, &"steer", 27.5 * TILE]],
			Vector2(27.5 * TILE, 24 * TILE), true)
	await perform("bounce and up-dash onto the rock", -INF, 0,
			[[24, &"move_up", 14], [26, &"dash", 2], [38, &"steer", 23 * TILE]], Vector2(23 * TILE, 10 * TILE))
	# The crumbling ledges, then dash through the cracked rock into the way out.
	await perform("down onto the first crumbling ledge", 14 * TILE + 2.0, -1, [[0, &"jump", 6], [10, &"steer", 10 * TILE]],
			Vector2(10 * TILE, 12 * TILE))
	await perform("on to the second", 9 * TILE + 2.0, -1, [[0, &"jump", 6], [8, &"steer", 5 * TILE]],
			Vector2(5 * TILE, 14 * TILE))
	if _aborted:
		return
	_hold(&"move_left")
	await frames(1)
	await _tap(&"dash")
	await run_until_room(&"meadow_gate", -1.0)


func meadow_gate() -> void:
	# Down off the step to the gate, and in.
	var gate: SpiritGate = main.room.find_children("*", "SpiritGate", true, false)[0]
	_hold(&"move_left")
	var shown := await until(func() -> bool: return gate.hint.visible, 600)
	_release_all()
	await frames(10)
	check("the Meadow's gate shows the Interact key", shown, str(hero.global_position - origin()))
	await _tap(&"interact")
	var asked := await until(func() -> bool: return main.confirm.visible, 60)
	check("pressing Interact at the gate asks if you're ready", asked, "")
	if not asked:
		_aborted = true
		return
	await frames(3)
	await _tap(&"jump")
	var entered := await until(func() -> bool: return main.room.room_id == &"meadow_spirit_room" and not main.transitioning, 120)
	check("answering Yes enters the Meadow Spirit Room at its start", entered
			and hero.global_position.distance_to(main.room.named_spawn(&"Start")) < 2.0, str(hero.global_position))
	if not entered:
		_aborted = true


func meadow_spirit_room() -> void:
	var deaths := GameState.deaths
	# S1: into the thorn shaft; jump and up-dash four times, refilled by the embers.
	await line_up(13 * TILE + 8.0)
	await perform("up the thorn shaft on four up-dashes", -INF, 0,
			[[0, &"jump", 18], [26, &"move_up", 56], [27, &"dash", 2], [41, &"dash", 2], [55, &"dash", 2], [69, &"dash", 2],
			[83, &"steer", 20 * TILE]], Vector2(20 * TILE, 8 * TILE))
	# S2: hop off the ledge and dash six times through the cracked pillars, under thorns.
	await perform("six dashes through the cracked pillars", 30 * TILE + 14.0, 1,
			[[0, &"jump", 1], [10, &"dash", 2], [24, &"dash", 2], [38, &"dash", 2], [52, &"dash", 2], [66, &"dash", 2],
			[80, &"dash", 2], [92, &"steer", 66 * TILE]], Vector2(66 * TILE, 9 * TILE))
	# S3: drop onto the flower, up-dash at the top onto L3; on without stopping under the bee,
	# onto the pillar's flower, and dash right to L4.
	await perform("drop onto the pit's flower", 72 * TILE + 8.0, 1, [[0, &"steer", 80.5 * TILE]],
			Vector2(80.5 * TILE, 27 * TILE), true)
	await perform("bounce and up-dash onto the ledge", -INF, 0,
			[[24, &"move_up", 14], [26, &"dash", 2], [38, &"steer", 86 * TILE]], Vector2(86 * TILE, 14 * TILE))
	await perform("hop off the ledge onto the pillar's flower", 92 * TILE + 8.0, 1, [[0, &"jump", 6], [0, &"steer", 99.5 * TILE]],
			Vector2(99.5 * TILE, 20 * TILE), true)
	await perform("bounce and dash right to the next ledge", -INF, 0,
			[[26, &"move_right", 4], [28, &"dash", 2], [40, &"steer", 107 * TILE]], Vector2(107 * TILE, 12 * TILE))
	# S4: down through two cracked floors (steering clear of the thorns), then right through
	# cracked rock.
	await run_to(116 * TILE)
	await perform("dash down through the first cracked floor", -INF, 0,
			[[0, &"move_down", 8], [2, &"dash", 2], [6, &"steer", 120 * TILE], [20, &"wait", 0]], Vector2(120 * TILE, 22 * TILE))
	await perform("dash down through the second", -INF, 0, [[0, &"move_down", 8], [2, &"dash", 2], [12, &"wait", 0]],
			Vector2(120 * TILE, 29 * TILE))
	await perform("dash right through the cracked rock", -INF, 0, [[0, &"move_right", 6], [1, &"dash", 2]],
			Vector2(124.5 * TILE, 29 * TILE))
	# S5: crumbling ledges over thorns, and a jump and dash to the color.
	await perform("onto the first crumbling ledge", 129 * TILE + 4.0, 1, [[0, &"jump", 18], [12, &"steer", 135.5 * TILE]],
			Vector2(135.5 * TILE, 27 * TILE))
	await perform("onto the second", 136 * TILE + 10.0, 1, [[0, &"jump", 18], [12, &"steer", 142.5 * TILE]],
			Vector2(142.5 * TILE, 25 * TILE))
	await perform("onto the third", 143 * TILE + 10.0, 1, [[0, &"jump", 18], [12, &"steer", 149.5 * TILE]],
			Vector2(149.5 * TILE, 23 * TILE))
	await perform("jump and dash to the color", 150 * TILE + 10.0, 1, [[0, &"jump", 18], [20, &"dash", 2], [32, &"steer", 161 * TILE]],
			Vector2(161 * TILE, 21 * TILE))
	if _aborted:
		return
	var absorbed := func() -> bool:
		return GameState.has_color(GameState.SpiritColor.YELLOW) and not hero.frozen and not hero.input_locked
	await until(absorbed, 400)
	check("yellow returns at the end of the run", GameState.has_color(GameState.SpiritColor.YELLOW), "")
	check("a clean run, with no deaths in the Spirit Room", GameState.deaths == deaths, "%d deaths" % (GameState.deaths - deaths))
	check("the run is recorded", GameState.best_time(&"meadow_spirit_room") < INF,
			GameState.format_time(GameState.best_time(&"meadow_spirit_room")))
	# Out through the exit gate, back to the Meadow's gate.
	var exit: SpiritGate = main.room.find_children("*", "SpiritGate", true, false).filter(
			func(gate: SpiritGate) -> bool: return gate.mode == SpiritGate.Mode.EXIT)[0]
	await run_to(exit.global_position.x)
	await frames(5)
	check("the exit gate is open once the color is taken", exit.is_open() and exit.hint.visible, "")
	await _tap(&"interact")
	var back := await until(func() -> bool: return main.room.room_id == &"meadow_gate" and not main.transitioning, 180)
	check("the exit gate leads back to the Meadow's gate", back, str(main.room.room_id))


# --- Moves ---------------------------------------------------------------------------------

## The room's top-left corner in world px.
func origin() -> Vector2:
	return main.room.position


## Run to `x` (room-local px).
func run_to_local(x: float) -> void:
	await run_to(origin().x + x)


func run_to(x: float) -> void:
	if _aborted:
		return
	var direction := signf(x - hero.global_position.x)
	if direction == 0.0:
		return
	var action := &"move_right" if direction > 0.0 else &"move_left"
	_hold(action)
	await until(func() -> bool: return (hero.global_position.x - x) * direction >= 0.0 or main.transitioning, 600)
	_release(action)
	# Stop dead, so timed moves start from standing.
	await until(func() -> bool: return absf(hero.velocity.x) < 1.0, 30)


## Keep running until the game is in room `id`.
func run_until_room(id: StringName, direction: float) -> void:
	if _aborted:
		return
	var action := &"move_right" if direction > 0.0 else &"move_left"
	_hold(action)
	var arrived := await until(func() -> bool: return main.room.room_id == id and not main.transitioning, 900)
	_release(action)
	await frames(2)
	check("reached %s" % id, arrived, "in %s at %s" % [main.room.room_id, hero.global_position])
	if not arrived:
		_aborted = true


## A timed move. Runs in `facing` (-1 left, 1 right, 0 stand) until the hero passes
## `takeoff_x` (room-local px; -INF or INF starts at once), then plays `steps` from that frame:
## each is [frame, action, frames held], or [frame, &"steer", x] to steer toward room-local x
## from then on (like a player lining up a landing; a direction key held by a step wins), or
## [frame, &"wait", 0] to hold nothing until then. Then waits for a landing and checks the hero
## stood up alive near `land` (room-local px: within 6 px of its height and 40 px of its x).
## With `to_flower`, the move ends instead when a bounce flower launches the hero (near `land`).
func perform(label: String, takeoff_x: float, facing: int, steps: Array, land: Vector2, to_flower := false) -> void:
	if _aborted:
		return
	var deaths := GameState.deaths
	var run_action := &"move_right" if facing > 0 else &"move_left"
	if facing != 0:
		_hold(run_action)
		var takeoff := origin().x + takeoff_x
		await until(func() -> bool: return (hero.global_position.x - takeoff) * facing >= 0.0, 600)
	var last := 0
	for step: Array in steps:
		last = maxi(last, step[0] + (0 if step[1] == &"steer" else step[2]))
	var landed := false
	var steer_x := NAN
	var forced := {}
	var fall_speed := hero.velocity.y
	for frame in last + 240:
		for step: Array in steps:
			if step[1] == &"steer":
				if frame == step[0]:
					steer_x = step[2]
			elif step[1] == &"wait":
				pass
			elif frame == step[0]:
				_hold(step[1])
				forced[step[1]] = true
			elif frame == step[0] + step[2]:
				_release(step[1])
				forced.erase(step[1])
		if not is_nan(steer_x):
			var gap: float = origin().x + steer_x - hero.global_position.x
			for side: StringName in [&"move_left", &"move_right"]:
				if forced.has(side):
					continue
				var want := gap < -1.5 if side == &"move_left" else gap > 1.5
				if want:
					_hold(side)
				else:
					_release(side)
		await frames(1)
		if _trace:
			var at := hero.global_position - origin()
			var extra := ""
			for bee: Bee in main.room.find_children("*", "Bee", true, false):
				extra += " bee(%.0f, %.0f %d)" % [bee.global_position.x - origin().x, bee.global_position.y - origin().y, bee.state]
			print("    f%-3d (%.1f, %.1f) v(%.0f, %.0f) %s%s" % [frame, at.x, at.y, hero.velocity.x, hero.velocity.y, hero.state_name, extra])
		if GameState.deaths > deaths:
			if _trace:
				print("    killed by: %s" % [_hazards_touching()])
			break
		# A new launch: falling (or level) one frame, flung up the next.
		if to_flower and hero.velocity.y < -400.0 and fall_speed > -100.0:
			landed = true
			break
		fall_speed = hero.velocity.y
		if not to_flower and frame > last and hero.is_on_floor() and hero.state_name != &"dash":
			landed = true
			break
	if not to_flower:
		_release_all()
		await frames(2)
	else:
		_release_all()
	var at := hero.global_position - origin()
	var near_y := absf(at.y - land.y) < (24.0 if to_flower else 6.0)
	var ok := landed and GameState.deaths == deaths and near_y and absf(at.x - land.x) < 40.0
	check(label, ok, "at %s, aim %s%s" % [at, land, ", died" if GameState.deaths > deaths else ""])
	if not ok:
		_aborted = true


## Press and release a button, two frames each.
func _tap(action: StringName) -> void:
	_hold(action)
	await frames(2)
	_release(action)


## Step to room-local x on the ground, to within a pixel, and stand still.
func line_up(x: float) -> void:
	if _aborted:
		return
	for i in 120:
		var gap: float = origin().x + x - hero.global_position.x
		if absf(gap) < 1.0 and absf(hero.velocity.x) < 1.0:
			break
		var side := &"move_left" if gap < 0.0 else &"move_right"
		_hold(side)
		await frames(1 if absf(gap) < 8.0 else maxi(1, int(absf(gap) / 3.5) - 2))
		_release(side)
		await frames(2)


## Walk to room-local x until a bounce flower there launches the hero.
func walk_onto_flower(x: float) -> void:
	if _aborted:
		return
	var deaths := GameState.deaths
	var launched := false
	for frame in 300:
		var gap: float = origin().x + x - hero.global_position.x
		if gap < -1.5:
			_hold(&"move_left")
			_release(&"move_right")
		elif gap > 1.5:
			_hold(&"move_right")
			_release(&"move_left")
		else:
			_release(&"move_left")
			_release(&"move_right")
		await frames(1)
		if hero.velocity.y < -300.0 or GameState.deaths > deaths:
			launched = hero.velocity.y < -300.0
			break
	if not launched:
		check("bounced off the flower at %d" % roundi(x), false, str(hero.global_position - origin()))
		_aborted = true


## Names of the hazards overlapping the hero's hazard box (for traces).
func _hazards_touching() -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 34)
	query.shape = box
	query.transform = Transform2D(0.0, hero.global_position + Vector2(0, -15))
	query.collision_mask = Player.HAZARD_LAYER
	query.collide_with_areas = true
	var names := []
	for hit in hero.get_world_2d().direct_space_state.intersect_shape(query, 8):
		var node: Node = hit["collider"]
		var owner_node: Node2D = node.get_parent() if node.name == &"Hurt" else node
		names.append("%s at %s" % [owner_node.name, owner_node.global_position - origin()])
	return names


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
