extends Node
## Headless movement tests and level-building measurements. Each test builds a small arena
## from a text layout (same legend as the movement test room), presses buttons frame by
## frame, and checks a rule from docs/DESIGN.md. Measurements print as a table at the end.
##
## Run from the repo root (it's a scene so the autoloads load):
##   godot --headless --path . --fixed-fps 60 res://tests/run_tests.tscn
## Exit code is the number of failed checks.

const PLAYER := preload("res://player/player.tscn")
const PUSH_BLOCK := preload("res://entities/push_block.tscn")
const DASH_EMBER := preload("res://entities/dash_ember.tscn")
const TILESET := preload("res://art/tilesets/test_tiles.tres")
const TILES := {
	"#": Vector2i(0, 0), "-": Vector2i(2, 0), "^": Vector2i(3, 0), "v": Vector2i(4, 0),
	">": Vector2i(5, 0), "<": Vector2i(6, 0), "S": Vector2i(7, 0), "|": Vector2i(8, 0),
}
const TILE := 16.0
const ORANGE := GameState.SpiritColor.ORANGE
const YELLOW := GameState.SpiritColor.YELLOW
const GREEN := GameState.SpiritColor.GREEN
const RED := GameState.SpiritColor.RED
const PURPLE := GameState.SpiritColor.PURPLE
const BLUE := GameState.SpiritColor.BLUE
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash", &"slide",
	&"grab", &"spirit",
]

const FLAT := """
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#..................................................................#
#P.................................................................#
####################################################################
"""

var player: Player
var spawn := Vector2.ZERO
var measurements: Array[Array] = []

var _world: Node2D
var _checks := 0
var _failures := 0
var _deaths := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests: Array[Callable] = [
		test_run, test_full_jump, test_short_hop, test_jump_distance, test_coyote_time,
		test_jump_buffer, test_corner_correction, test_crouch_under_spikes, test_death_respawn,
		test_push_pull, test_dash, test_dash_up, test_ember_refill, test_double_jump,
		test_wall_jump_single_wall, test_wall_jump_shaft, test_slide, test_slide_tunnel,
		test_ledge_grab, test_vine_climb, test_spirit_through_barrier, test_spirit_into_hazard,
	]
	for test in tests:
		await test.call()
	for action in ACTIONS:
		Input.action_release(action)
	if _world:
		_world.free()
	await wait(60) # Let the last sounds finish so none is reported as leaked at exit.
	print("\n=== Level-building numbers (px; a tile is 16 px) ===")
	for row in measurements:
		print("%-34s %7.1f px  %5.1f tiles" % [row[0], row[1], row[1] / TILE])
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(_failures)


# --- Tests -------------------------------------------------------------------------------

func test_run() -> void:
	await arena(FLAT)
	_hold(&"move_right")
	var frames := await until(func() -> bool: return player.velocity.x >= player.tuning.run_speed, 30)
	check("run reaches top speed within 4 frames", frames <= 4, "%d frames" % frames)
	await wait(10)
	_release(&"move_right")
	frames = await until(func() -> bool: return player.velocity.x == 0.0, 30)
	check("run stops within 3 frames, no sliding", frames <= 3, "%d frames" % frames)


func test_full_jump() -> void:
	await arena(FLAT)
	var start_y := player.position.y
	_hold(&"jump")
	var top := await track_jump()
	_release(&"jump")
	var rise := start_y - top.y
	measure("Full jump height", rise)
	check("full jump rises about 73 px (doc)", absf(rise - 73.0) <= 4.0, "%.1f px" % rise)


func test_short_hop() -> void:
	await arena(FLAT)
	var start_y := player.position.y
	_hold(&"jump")
	await wait(1)
	_release(&"jump")
	var top := await track_jump()
	var rise := start_y - top.y
	measure("Short hop height (tap)", rise)
	check("a tap is a short hop, under a third of a full jump", rise < 25.0, "%.1f px" % rise)


func test_jump_distance() -> void:
	await arena(FLAT)
	_hold(&"move_right")
	await wait(20)
	var start_x := player.position.x
	_hold(&"jump")
	var landing := await track_jump()
	_release_all()
	var distance := landing.x - start_x
	measure("Running jump distance (feet)", distance)
	measure("Widest gap, running jump", distance + player.tuning.stand_size.x)


func test_coyote_time() -> void:
	var ledge := """
#..............................#
#..............................#
#..............................#
#..............................#
#P.............................#
##########.....................#
#..............................#
#..............................#
#..............................#
################################
"""
	for late_frames: int in [5, 8]:
		await arena(ledge)
		_hold(&"move_right")
		await until(func() -> bool: return not player.is_on_floor(), 120)
		await wait(late_frames - 1)
		_hold(&"jump")
		await wait(1)
		var jumped := player.state_name == &"jump"
		_release_all()
		if late_frames == 5:
			check("coyote: jump works 5 frames after leaving a ledge", jumped, player.state_name)
		else:
			check("coyote: jump fails 8 frames after leaving a ledge", not jumped, player.state_name)


func test_jump_buffer() -> void:
	var drop := """
#.......#
#...P...#
#.......#
#.......#
#.......#
#.......#
#.......#
#########
"""
	await arena(drop, [], false)
	var landing_frame := await until(func() -> bool: return player.is_on_floor(), 120)
	await arena(drop, [], false)
	await wait(landing_frame - 5)
	_hold(&"jump")
	await until(func() -> bool: return player.is_on_floor() or player.state_name == &"jump", 20)
	await wait(1)
	check("buffer: jump pressed 5 frames before landing fires on landing",
			player.state_name == &"jump", player.state_name)
	_release_all()


func test_corner_correction() -> void:
	var ceiling := """
#.........#
#.........#
#.........#
#....######
#.........#
#.........#
#....P....#
###########
"""
	await arena(ceiling)
	# Stand with the body 2 px under the ceiling's left corner.
	player.position.x = 5 * TILE - player.tuning.stand_size.x / 2.0 + 2.0
	await wait(1)
	_hold(&"jump")
	var top := await track_jump()
	_release_all()
	check("corner correction: clipping a corner by 2 px slides around it",
			top.y < 3 * TILE, "apex y %.1f" % top.y)


func test_crouch_under_spikes() -> void:
	var passage := """
#..................#
#..................#
#.....#######......#
#.....vvvvvvv......#
#P.................#
####################
"""
	await arena(passage)
	_hold(&"move_down")
	_hold(&"move_right")
	await until(func() -> bool: return player.position.x > 15 * TILE, 300)
	check("crouching passes under head-height spikes", _deaths == 0 and player.position.x > 15 * TILE,
			"deaths %d, x %.0f" % [_deaths, player.position.x])
	_release_all()
	await arena(passage)
	_hold(&"move_right")
	await until(func() -> bool: return _deaths > 0, 120)
	check("standing walks into head-height spikes and dies", _deaths > 0, "deaths %d" % _deaths)
	_release_all()


func test_death_respawn() -> void:
	var spikes := """
#.........#
#.........#
#P..^^^...#
###########
"""
	await arena(spikes)
	_hold(&"move_right")
	await until(func() -> bool: return player.state_name == &"dead", 120)
	_release_all()
	var frames := await until(func() -> bool: return player.state_name == &"idle", 60)
	check("death to control again under 0.5 s", frames < 30, "%d frames" % frames)
	check("respawn puts the hero back at the start", player.position.distance_to(spawn) < 1.0,
			str(player.position))


func test_push_pull() -> void:
	var room := """
#....................#
#....................#
#....PB..............#
######################
"""
	await arena(room)
	var block: PushBlock = _world.find_children("*", "PushBlock", true, false)[0]
	var start := block.position.x
	_hold(&"grab")
	_hold(&"move_right")
	await wait(60)
	var pushed := block.position.x - start
	check("holding grab pushes the block about 60 px/s", absf(pushed - 60.0) < 8.0, "%.1f px" % pushed)
	_release(&"move_right")
	_hold(&"move_left")
	await wait(30)
	var pulled := block.position.x - start
	check("moving away while holding grab pulls the block", pulled < pushed - 20.0,
			"%.1f px" % pulled)
	_release_all()
	await arena(room)
	block = _world.find_children("*", "PushBlock", true, false)[0]
	start = block.position.x
	_hold(&"move_right")
	await wait(30)
	check("without grab the block doesn't move", block.position.x == start, "%.1f" % block.position.x)
	_release_all()


func test_dash() -> void:
	await arena(FLAT, [ORANGE])
	var start_x := player.position.x
	_hold(&"dash")
	await wait(1)
	_release(&"dash")
	await until(func() -> bool: return player.state_name != &"dash", 60)
	var reach := player.position.x - start_x
	measure("Dash reach", reach)
	check("dash covers about 5 tiles", absf(reach - 80.0) <= 6.0, "%.1f px" % reach)
	await arena(FLAT)
	_hold(&"dash")
	await wait(2)
	check("no dash before orange", player.state_name != &"dash", player.state_name)
	_release_all()


func test_dash_up() -> void:
	await arena(FLAT, [ORANGE])
	var start_y := player.position.y
	_hold(&"move_up")
	_hold(&"dash")
	await wait(1)
	_release_all()
	# Skip the dash's opening freeze, which is still on the floor.
	await until(func() -> bool: return not player.is_on_floor(), 30)
	var top := await track_jump()
	measure("Dash straight up, total rise", start_y - top.y)
	await arena(FLAT, [ORANGE])
	start_y = player.position.y
	_hold(&"jump")
	await until(func() -> bool: return player.velocity.y >= 0.0, 60)
	_hold(&"move_up")
	_hold(&"dash")
	await wait(1)
	_release(&"dash")
	_release(&"move_up")
	top = await track_jump()
	_release_all()
	measure("Jump + up dash at apex, rise", start_y - top.y)


func test_ember_refill() -> void:
	var gap := """
#......................................#
#...........E..........................#
#......................................#
#......................................#
#......................................#
#.P....................................#
###....................................#
"""
	await arena(gap, [ORANGE])
	_hold(&"move_right")
	_hold(&"jump")
	await until(func() -> bool: return player.velocity.y >= 0.0, 60)
	_hold(&"dash")
	await wait(1)
	_release(&"dash")
	var refilled := await until(func() -> bool: return player.air_dashes_left > 0, 60)
	check("a dash ember refills the dash in midair", refilled < 60, "after %d frames" % refilled)
	_release_all()


func test_double_jump() -> void:
	await arena(FLAT, [YELLOW])
	var start_y := player.position.y
	_hold(&"jump")
	await until(func() -> bool: return player.velocity.y >= 0.0, 60)
	_release(&"jump")
	await wait(1)
	_hold(&"jump")
	var top := await track_jump()
	_release_all()
	var rise := start_y - top.y
	measure("Jump + double jump height", rise)
	check("double jump adds about 42 px (doc: ~115 total)", absf(rise - 115.0) <= 6.0, "%.1f px" % rise)
	await arena(FLAT)
	_hold(&"jump")
	await until(func() -> bool: return player.velocity.y >= 0.0, 60)
	_release(&"jump")
	await wait(1)
	_hold(&"jump")
	top = await track_jump()
	_release_all()
	check("no double jump before yellow", start_y - top.y < 80.0, "%.1f px" % (start_y - top.y))


func test_wall_jump_single_wall() -> void:
	var wall := """
#.........#
#.........#
#.........#
#.........#
#.........#
#.........#
#.........#
#.........#
#.........#
#.........#
#.........#
#......P..#
###########
"""
	await arena(wall, [GREEN])
	var start_y := player.position.y
	var top := start_y
	_hold(&"move_right")
	_hold(&"jump")
	for frame in 240:
		await wait(1)
		top = minf(top, player.position.y)
		_release(&"jump")
		if not player.is_on_floor() and player.is_wall_at(1):
			_hold(&"jump") # Try to climb the same wall.
	_release_all()
	# One jump plus one wall jump is allowed; climbing higher than that is not.
	var rise := start_y - top
	check("one wall can't be climbed by wall jumping", rise < 156.0, "rose %.1f px" % rise)


func test_wall_jump_shaft() -> void:
	var shaft := "#....#
".repeat(21) + "#P...#
######
"
	await arena(shaft, [GREEN])
	var start_y := player.position.y
	var top := start_y
	var heading := 1
	_hold(&"move_right")
	_hold(&"jump")
	for frame in 300:
		await wait(1)
		top = minf(top, player.position.y)
		var side := player.wall_side()
		if not player.is_on_floor() and side == heading and player.velocity.y > -60.0:
			_release(&"move_right" if heading > 0 else &"move_left")
			heading = -heading
			_hold(&"move_right" if heading > 0 else &"move_left")
			_release(&"jump")
			await wait(1)
			_hold(&"jump")
	_release_all()
	var rise := start_y - top
	measure("Climbed in a 4-wide shaft, 5 s", rise)
	check("two facing walls can be climbed", rise > 120.0, "rose %.1f px" % rise)


func test_slide() -> void:
	await arena(FLAT, [RED])
	_hold(&"move_right")
	await wait(20)
	var start_x := player.position.x
	_hold(&"slide")
	await wait(1)
	_release(&"slide")
	await until(func() -> bool: return player.state_name != &"slide", 60)
	measure("Slide distance", player.position.x - start_x)
	await arena(FLAT, [RED])
	_hold(&"move_right")
	await wait(20)
	_hold(&"slide")
	await wait(3)
	_release(&"slide")
	start_x = player.position.x
	_hold(&"jump")
	var landing := await track_jump()
	_release_all()
	var distance := landing.x - start_x
	measure("Slide jump distance (feet)", distance)
	measure("Widest gap, slide jump", distance + player.tuning.stand_size.x)
	var running := measured("Running jump distance (feet)")
	check("a slide jump goes at least 2 tiles further than a running jump",
			distance - running >= 2.0 * TILE, "%.1f vs %.1f px" % [distance, running])


func test_slide_tunnel() -> void:
	var tunnel := """
#.......########......#
#.......########......#
#.......########......#
#P....................#
#######################
"""
	await arena(tunnel, [RED])
	_hold(&"move_right")
	await wait(10)
	_hold(&"slide")
	await wait(1)
	_release(&"slide")
	await until(func() -> bool: return player.position.x > 17 * TILE, 180)
	check("a slide passes a 1-tile tunnel", player.position.x > 17 * TILE, "x %.0f" % player.position.x)
	_release_all()
	await arena(tunnel)
	_hold(&"move_down")
	_hold(&"move_right")
	await wait(120)
	check("crouching can't pass a 1-tile tunnel", player.position.x < 9 * TILE,
			"x %.0f" % player.position.x)
	_release_all()


func test_ledge_grab() -> void:
	var wall := """
#..............#
#..............#
#..............#
#.........######
#.........######
#.........######
#.........######
#.........######
#......P..######
################
"""
	await arena(wall, [PURPLE])
	_hold(&"move_right")
	_hold(&"jump")
	var grabbed := await until(func() -> bool: return player.state_name == &"ledge_grab", 90)
	check("moving into a 6-tile ledge in midair grabs it", player.state_name == &"ledge_grab",
			"%s after %d frames" % [player.state_name, grabbed])
	_release_all()
	_hold(&"move_up")
	await until(func() -> bool: return player.state_name == &"idle", 60)
	_release_all()
	await wait(2)
	check("up pulls onto the ledge", player.is_on_floor() and player.position.y <= 3 * TILE + 0.5,
			"%s at %s" % [player.state_name, player.position])
	await arena(wall)
	_hold(&"move_right")
	_hold(&"jump")
	await wait(90)
	check("no ledge grab before purple", player.position.y > 4 * TILE, str(player.position))
	_release_all()


func test_vine_climb() -> void:
	var vines := """
#.........#
#.........#
#....|....#
#....|....#
#....|....#
#....|....#
#....|....#
#.........#
#....P....#
###########
"""
	await arena(vines, [PURPLE])
	var start_y := player.position.y
	_hold(&"grab")
	_hold(&"move_up")
	_hold(&"jump")
	await wait(60)
	check("holding grab on vines climbs them", player.state_name == &"climb" or player.position.y < start_y - 50.0,
			"%s, rose %.1f px" % [player.state_name, start_y - player.position.y])
	_release_all()


func test_spirit_through_barrier() -> void:
	var barrier := """
#.....................#
#.....................#
#.........SS..........#
#.........SS..........#
#.........SS..........#
#....P....SS..........#
#######################
"""
	await arena(barrier, [BLUE])
	_hold(&"spirit")
	await wait(1)
	_hold(&"move_right")
	await wait(50)
	_release_all()
	await wait(2)
	check("Spirit Phase carries the body through a spirit barrier", player.position.x > 12 * TILE,
			"x %.0f" % player.position.x)
	measure("Spirit range (1.5 s, straight)", player.tuning.spirit_speed * player.tuning.spirit_time)
	await arena(barrier)
	_hold(&"move_right")
	await wait(60)
	check("the body alone can't pass a spirit barrier", player.position.x < 10 * TILE,
			"x %.0f" % player.position.x)
	_release_all()


func test_spirit_into_hazard() -> void:
	var spikes := """
#.....................#
#.....................#
#.....................#
#....P....^^^^........#
#######################
"""
	await arena(spikes, [BLUE])
	var start := player.position
	_hold(&"spirit")
	await wait(1)
	_hold(&"move_right")
	await wait(30)
	_release_all()
	await wait(2)
	check("releasing over a hazard leaves the body where it was",
			player.position.distance_to(start) < 1.0 and _deaths == 0,
			"moved to %s, deaths %d" % [player.position, _deaths])


# --- Harness -----------------------------------------------------------------------------

## Build a fresh arena from a layout and wait for the hero to settle.
func arena(layout: String, colors: Array = [], settle := true) -> void:
	_release_all()
	if _world:
		_world.free()
	_deaths = 0
	GameState.set_all_colors(false)
	for color: int in colors:
		GameState.set_color(color as GameState.SpiritColor, true)
	_world = Node2D.new()
	add_child(_world)
	var tiles := TileMapLayer.new()
	tiles.tile_set = TILESET
	_world.add_child(tiles)
	var rows := layout.strip_edges().split("\n")
	for y in rows.size():
		for x in rows[y].length():
			var symbol := rows[y][x]
			var cell := Vector2i(x, y)
			var bottom := (Vector2(cell) + Vector2(0.5, 1.0)) * TILE
			if TILES.has(symbol):
				tiles.set_cell(cell, 0, TILES[symbol])
			elif symbol == "P":
				spawn = bottom
			elif symbol == "B":
				var block := PUSH_BLOCK.instantiate()
				block.position = bottom
				_world.add_child(block)
			elif symbol == "E":
				var ember := DASH_EMBER.instantiate()
				ember.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
				_world.add_child(ember)
	player = PLAYER.instantiate()
	player.position = spawn
	_world.add_child(player)
	player.died.connect(_on_died)
	if settle:
		await wait(3)
	else:
		await wait(1)


func _on_died() -> void:
	_deaths += 1
	player.respawn(spawn)


## Let `frames` frames run. The harness steps on process_frame, which fires after each
## physics frame, so button changes land between frames like real input. With
## --fixed-fps 60 there is exactly one physics frame per process frame.
func wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## Run frames until `condition` is true; returns the frames it took (or `limit`).
func until(condition: Callable, limit: int) -> int:
	for i in range(1, limit + 1):
		await get_tree().process_frame
		if condition.call():
			return i
	return limit


## Follow a jump to its landing. Returns the highest point's y in .y and the landing x in .x.
func track_jump() -> Vector2:
	var top := player.position.y
	await wait(2)
	for i in 300:
		top = minf(top, player.position.y)
		if player.is_on_floor() and player.velocity.y >= 0.0:
			break
		await get_tree().process_frame
	return Vector2(player.position.x, top)


func check(label: String, passed: bool, detail := "") -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s  %s%s" % ["PASS" if passed else "FAIL", label, "  (%s)" % detail if detail else ""])


func measure(label: String, value: float) -> void:
	measurements.append([label, value])


func measured(label: String) -> float:
	for row in measurements:
		if row[0] == label:
			return row[1]
	return NAN


func _hold(action: StringName) -> void:
	Input.action_press(action)


func _release(action: StringName) -> void:
	Input.action_release(action)


func _release_all() -> void:
	for action in ACTIONS:
		_release(action)
