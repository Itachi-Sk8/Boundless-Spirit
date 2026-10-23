extends Node
## Checks the game's systems through the real game scene: the world map matches the rooms,
## checkpoints set the respawn point, Spirit Rooms stand apart from the world, their gates take
## the hero in and back out, and they restart from their start and count deaths,
## crumbling ledges and leaves behave and reset, region color follows the colors, waystones
## wake with their color and travel between the Hollow and the regions, and saves round-trip. Uses save slot 9 and deletes it afterwards.
##
## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 res://tests/game_systems.tscn
## Exit code is the number of failed checks.

const SLOT := 9

var main: Main
var hero: Player
var _checks := 0
var _failures := 0


func _ready() -> void:
	GameState.slot = SLOT
	GameState.delete_save()
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	hero = main.player
	_run.call_deferred()


func _run() -> void:
	await frames(5)
	test_world_map()
	await test_checkpoint_respawn()
	await test_spirit_room_restart()
	await test_crumble_platform()
	await test_sinking_leaf()
	await test_world_color_cascade()
	await test_thorns()
	await test_push_pin()
	await test_spirit_door()
	await test_menus()
	await test_waystones()
	await test_save_round_trip()
	GameState.delete_save()
	await frames(5)
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(_failures)


func test_world_map() -> void:
	var slice: Array[StringName] = [&"meadow_edge", &"hollow_west", &"hollow_clearing", &"hollow_east",
			&"ember_entry", &"ember_leaves", &"ember_climb", &"ember_gate", &"ember_spirit_room"]
	check("the slice's 9 rooms are on the world map, read from rooms/", slice.all(WorldMap.has_room)
			and not WorldMap.has_room(&"room_template") and not WorldMap.has_room(&"gallery"), str(WorldMap.rooms().keys()))
	check("the Spirit Room is known from its scene, with no checkpoints", WorldMap.rooms()[&"ember_spirit_room"]["spirit_room"]
			and WorldMap.rooms()[&"ember_spirit_room"]["checkpoints"].is_empty(), "")
	check("checkpoint stones are read from the room scenes", not WorldMap.rooms()[&"ember_entry"]["checkpoints"].is_empty(), "")
	var spirit := WorldMap.rect_px(&"ember_spirit_room")
	check("the Spirit Room stands apart: at the origin, its own size, and no room walks into it",
			spirit.position == Vector2.ZERO and WorldMap.room_at(spirit.get_center()) != &"ember_spirit_room"
			and WorldMap.is_spirit_room(&"ember_spirit_room"), str(spirit))
	var door := WorldMap.door_into(&"ember_spirit_room")
	check("the entrance gate in Ember Gate is read as the way in", door.get("room") == &"ember_gate"
			and door["spot"] == WorldMap.rect_px(&"ember_gate").position + Vector2(466, 368), str(door))
	# A room painted by hand (Layout left empty) is measured by its painted tiles.
	var painted: Room = load(WorldMap.scene_of(&"hollow_east")).instantiate()
	add_child(painted)
	var laid_out := painted.world_bounds()
	(painted.terrain as TerrainLayout).layout = ""
	check("a room painted by hand is as big as its tiles, not empty", painted._terrain_bounds() == laid_out,
			str(painted._terrain_bounds()))
	var hand := painted.terrain as TerrainLayout
	check("  and clearing its Layout drops the grass blades but keeps the tiles",
			hand.grass_tops.get_used_cells().is_empty() and not hand.get_used_cells().is_empty(), "")
	painted.free()
	test_room_size()
	for id: StringName in WorldMap.rooms():
		var info: Dictionary = WorldMap.rooms()[id]
		var room: Room = load(info["scene"]).instantiate()
		var terrain := room.get_node(^"Terrain") as TerrainLayout
		if terrain and terrain.layout != "":
			check("%s's layout is %s tiles, as the world map says" % [id, info["size"]],
					terrain.layout_size() == info["size"], str(terrain.layout_size()))
		var bounds := Rect2(Vector2.ZERO, Vector2(info["size"]) * 16.0)
		var spawns := room.get_node(^"Spawns").get_children()
		check("%s has spawn points, all inside it" % id, not spawns.is_empty()
				and spawns.all(func(s: Node) -> bool: return bounds.has_point((s as Node2D).position - Vector2(0, 1))), "")
		room.free()
	check("no two rooms overlap", WorldMap.overlaps().is_empty(), str(WorldMap.overlaps()))


# The editor's Room Size buttons (Room.resize_side), used here without the editor.
func test_room_size() -> void:
	var room: Room = load(WorldMap.scene_of(&"hollow_clearing")).instantiate()
	add_child(room)
	var layout := room.terrain as TerrainLayout
	var rows := TerrainLayout.rows_of(layout.layout)
	var size := room.size_in_tiles()
	var start := room.named_spawn(&"Start")
	var origin := room.world_origin
	room.resize_side(SIDE_TOP, 3)
	var grown := TerrainLayout.rows_of(layout.layout)
	check("Room Size: adding rows on top adds empty rows and moves everything down with them",
			grown.size() == rows.size() + 3 and grown[0] == ".".repeat(grown[0].length()) and grown[3] == rows[0]
			and room.named_spawn(&"Start") == start + Vector2(0, 48) and room.world_origin == origin - Vector2i(0, 3),
			"%d rows, start %s, origin %s" % [grown.size(), room.named_spawn(&"Start"), room.world_origin])
	room.resize_side(SIDE_TOP, -3)
	check("  and removing them puts everything back", TerrainLayout.rows_of(layout.layout) == rows
			and room.named_spawn(&"Start") == start and room.world_origin == origin, "")
	room.resize_side(SIDE_RIGHT, 2)
	room.resize_side(SIDE_BOTTOM, -1)
	check("  adding columns on the right and removing a row at the bottom", room.size_in_tiles() == size + Vector2i(2, -1)
			and room.named_spawn(&"Start") == start, str(room.size_in_tiles()))
	room.free()
	var painted: Room = load(WorldMap.scene_of(&"hollow_east")).instantiate()
	add_child(painted)
	(painted.terrain as TerrainLayout).layout = ""
	var tiles := painted.terrain
	var size_before := painted.size_in_tiles()
	var edge := tiles.get_cell_atlas_coords(Vector2i(0, 15))
	painted.resize_side(SIDE_LEFT, 2)
	check("  a painted room gets a Room Size, and adding columns on the left moves its tiles over",
			painted.size_tiles == size_before + Vector2i(2, 0) and tiles.get_cell_source_id(Vector2i(0, 15)) == -1
			and tiles.get_cell_atlas_coords(Vector2i(2, 15)) == edge and painted.world_origin.x == 58,
			"%s %s" % [painted.size_tiles, painted.world_origin])
	painted.free()


func test_checkpoint_respawn() -> void:
	main._enter_world_room(&"ember_entry", Vector2(2760, 240))
	await frames(5)
	check("touching a checkpoint stone lights it", _lit_checkpoints() == 1, "")
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	check("dying after a checkpoint respawns at the checkpoint", hero.global_position.distance_to(Vector2(2760, 240)) < 2.0,
			str(hero.global_position))
	main._enter_world_room(&"ember_entry", Vector2(2232, 160))
	await frames(5)
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	check("re-entering a room forgets its checkpoint", hero.global_position.x < 2300.0, str(hero.global_position))


func test_spirit_room_restart() -> void:
	GameState.set_color(GameState.SpiritColor.ORANGE, false)
	main._enter_world_room(&"ember_spirit_room", Vector2.INF)
	await frames(30)
	check("a Spirit Room run is timed", main._run_active and main._run_time > 0.3, "%.2f s" % main._run_time)
	var deaths := GameState.deaths
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	var start := main.room.named_spawn(&"Start")
	check("dying in a Spirit Room restarts at its start", hero.global_position.distance_to(start) < 2.0,
			"at %s, start %s" % [hero.global_position, start])
	check("the death counts for the room and the game", main._run_deaths == 1 and GameState.deaths == deaths + 1, "")
	check("the run timer starts over", main._run_time < 0.2, "%.2f s" % main._run_time)


func test_crumble_platform() -> void:
	main._enter_world_room(&"hollow_east", Vector2(1672, 160))
	await frames(2)
	var crumble: CrumblePlatform = main.room.find_children("*", "CrumblePlatform", true, false)[0]
	await until(func() -> bool: return crumble.phase == CrumblePlatform.Phase.GONE, 60)
	check("a crumbling ledge falls after being stood on", crumble.phase == CrumblePlatform.Phase.GONE, "")
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	check("dying puts the crumbling ledge back", crumble.phase == CrumblePlatform.Phase.SOLID, "")
	main._enter_world_room(&"hollow_east", Vector2(1860, 160))
	await frames(2)
	crumble = main.room.find_children("*", "CrumblePlatform", true, false)[0]
	crumble.phase = CrumblePlatform.Phase.GONE
	crumble._timer = 0.2
	await frames(20)
	check("a fallen ledge comes back on its own", crumble.phase == CrumblePlatform.Phase.SOLID, "")


func test_sinking_leaf() -> void:
	main._enter_world_room(&"ember_leaves", Vector2(3176, 230))
	await frames(2)
	var leaf: SinkingLeaf = _nearest(main.room.find_children("*", "SinkingLeaf", true, false), Vector2(3176, 240))
	var top := leaf.global_position.y
	await until(func() -> bool: return leaf.global_position.y > top + 0.5, 60)
	var landed_at := leaf.global_position.y
	await frames(30)
	var sunk := leaf.global_position.y - landed_at
	var expected := leaf.sink_speed / 2.0
	check("a lily pad sinks at its own speed under the hero (%d px/s: about %d px in half a second)" % [leaf.sink_speed, expected],
			absf(sunk - expected) < 3.0, "%.1f px" % sunk)
	hero.respawn(Vector2(3052, 240), true)
	await frames(90)
	check("a lily pad floats back up when left", absf(leaf.global_position.y - top) < 1.0,
			"%.1f px" % (leaf.global_position.y - top))
	check("the lily pad room has no checkpoint", main.room.find_children("*", "CheckpointStone", true, false).is_empty(), "")
	var deaths := GameState.deaths
	hero.respawn(Vector2(3176, 230), true)
	await until(func() -> bool: return GameState.deaths > deaths, 240)
	check("standing on a lily pad too long sinks you into the pit", GameState.deaths == deaths + 1, "")
	var back := await until(func() -> bool: return absf(leaf.global_position.y - top) < 4.0, 10)
	check("the pit death puts the lily pad back", back, "%.1f px" % (leaf.global_position.y - top))
	await frames(40)
	check("the lily pad snapping back doesn't fling the hero", main.room.room_id == &"ember_leaves"
			and hero.global_position.y > 200.0, "%s at %s" % [main.room.room_id, hero.global_position])
	main._enter_world_room(&"ember_leaves", Vector2(3400, 208))
	await frames(2)
	hero.velocity.y = -900.0
	hero.change_state(&"jump")
	await frames(30)
	check("jumping out of the top of a room under the Spirit Room's floor can't get in",
			main.room.room_id == &"ember_leaves", "%s at %s" % [main.room.room_id, hero.global_position])


func test_world_color_cascade() -> void:
	# The table approved in the playtest: color i fills its layer, then 20% and 10% cascade on.
	var table: Array[Array] = [
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[1.0, 0.2, 0.1, 0.0, 0.0, 0.0],
		[1.0, 1.0, 0.3, 0.1, 0.0, 0.0],
		[1.0, 1.0, 1.0, 0.3, 0.1, 0.0],
		[1.0, 1.0, 1.0, 1.0, 0.3, 0.1],
		[1.0, 1.0, 1.0, 1.0, 1.0, 0.3],
		[1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	]
	for collected_count in table.size():
		var collected: Array[bool] = []
		for color in 6:
			collected.append(color < collected_count)
		var values := WorldColor.strengths(collected)
		var matches := true
		for layer in 6:
			matches = matches and is_equal_approx(values[layer], table[collected_count][layer])
		check("after %d colors the layers are %s" % [collected_count, table[collected_count]], matches, str(values))
		check("  and spikes are at %d%%" % roundi(maxf(0.1, table[collected_count][5]) * 100.0),
				is_equal_approx(values[WorldColor.Layer.HAZARDS], maxf(0.1, table[collected_count][5])), str(values[6]))
	GameState.set_all_colors(false)
	main._enter_world_room(&"hollow_clearing", Vector2(88, 240))
	await frames(2)
	check("the world starts grey, spikes at 10%", _shown(0, 0.0) and _shown(5, 0.0) and _shown(6, 0.1), str(main._shown_color))
	var props := main.room.get_node(^"Props").get_child(0) as CanvasItem
	check("trees behind the ground are on the trees layer", _layer_of(props) == WorldColor.Layer.TREES, "")
	main._enter_world_room(&"hollow_east", Vector2(1000, 240))
	await frames(2)
	var terrain := main.room.get_node(^"Terrain") as TerrainLayout
	var thorns := main.room.get_node(^"Hazards").get_child(0) as Thorns
	check("the ground is on the ground layer and thorns on the hazards layer",
			_layer_of(terrain) == WorldColor.Layer.GROUND and _layer_of(thorns) == WorldColor.Layer.HAZARDS, "")
	check("thorns draw in front of bushes and objects", thorns.z_index > 2, str(thorns.z_index))
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	await frames(2)
	check("with orange the sky is full color, far hills 20%, near forest 10%",
			_shown(0, 1.0) and _shown(1, 0.2) and _shown(2, 0.1) and _shown(3, 0.0), str(main._shown_color))
	main._enter_world_room(&"ember_entry", Vector2(2252, 160))
	await frames(2)
	check("the color stays in other rooms", _shown(0, 1.0) and _shown(1, 0.2), str(main._shown_color))
	main._enter_world_room(&"ember_spirit_room", Vector2.INF)
	await frames(2)
	GameState.new_game(SLOT)
	GameState.load_game(SLOT)
	await frames(2)
	check("and after saving and loading", _shown(0, 1.0) and _shown(1, 0.2) and _shown(2, 0.1), str(main._shown_color))
	GameState.set_color(GameState.SpiritColor.ORANGE, false)
	await frames(2)
	var before := WorldColor.strengths(GameState.colors())
	main._cascading = true
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	main._cascade(before, WorldColor.strengths(GameState.colors()))
	await frames(20)
	check("a returning color starts at the back: the sky colors first", main._shown_color[0] > 0.05
			and main._shown_color[2] < 0.01, str(main._shown_color))
	await until(func() -> bool: return not main._cascading, 400)
	check("the cascade ends on the table's values", _shown(0, 1.0) and _shown(1, 0.2) and _shown(2, 0.1), str(main._shown_color))


func test_thorns() -> void:
	main._enter_world_room(&"hollow_east", Vector2(1000, 240))
	await frames(2)
	var thorns := main.room.get_node(^"Hazards").get_child(0) as Thorns
	check("a Thorns row's hurt area spans its length", thorns.hurt_rect() == Rect2(2, 7, thorns.length * 16 - 4 + thorns.adjust_px, 9),
			str(thorns.hurt_rect()))
	# Hollow East's thorns stand on the floor, with open floor (and its grass) to their left.
	var terrain := main.room.terrain as TerrainLayout
	var row := int(thorns.position.y / 16.0)
	var mid := int((thorns.position.x + thorns.length_px() / 2.0) / 16.0)
	var left := int(thorns.position.x / 16.0) - 9
	# Grass with a top surface: the grassy top-edge tiles (the blades grow in the cell above).
	var grassy := func(column: int) -> bool:
		var tile := terrain.get_cell_atlas_coords(Vector2i(column, row + 1))
		return terrain.grass_tops.get_cell_source_id(Vector2i(column, row)) != -1 \
				and ((tile.y == 0 and tile.x & TerrainLayout.UP) or (tile.y == 2 and tile.x in [2, 3]))
	var under := terrain.get_cell_atlas_coords(Vector2i(mid, row + 1))
	var dirt := (under.y == 0 and under.x & TerrainLayout.UP == 0) or (under.y == 2 and under.x in [0, 1])
	check("thorns sit on bare dirt: plain dirt tiles and no grass under them, grass beside them",
			not grassy.call(mid) and dirt and grassy.call(left), str(under))
	thorns.position.x -= 160.0
	terrain.refresh_bare_soil()
	check("  and the bare dirt follows the thorns when they move", grassy.call(mid) and not grassy.call(left), "")
	thorns.position.x += 160.0
	terrain.refresh_bare_soil()
	var deaths := GameState.deaths
	hero.global_position = thorns.global_position + Vector2(thorns.length * 8.0, -4.0)
	hero.velocity = Vector2.ZERO
	check("dropping onto thorns kills the hero", await until(func() -> bool: return GameState.deaths == deaths + 1, 120), "")
	await until(func() -> bool: return hero.state_name != &"dead" and not hero.frozen, 240)
	thorns.direction = Thorns.Direction.LEFT
	thorns.length = 3
	check("turned left and stretched to 3, it runs downward", thorns.hurt_rect() == Rect2(7, 2, 9, 44 + thorns.adjust_px), str(thorns.hurt_rect()))
	thorns.direction = Thorns.Direction.UP
	thorns.length = 2


func test_push_pin() -> void:
	# Pull Hollow East's stone right until the hero is pressed against the big block. The stone
	# used to slide into the hero there, wedging the hero for good.
	main._enter_world_room(&"hollow_east", Vector2.INF)
	await frames(5)
	var block: PushBlock = main.room.find_children("*", "PushBlock", true, false)[0]
	hero.global_position = block.global_position + Vector2(20, 0)
	hero.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press(&"grab")
	Input.action_press(&"move_left")
	await frames(4)
	Input.action_release(&"move_left")
	Input.action_press(&"move_right")
	await frames(400)
	Input.action_release(&"move_right")
	Input.action_release(&"grab")
	await frames(5)
	var gap := (hero.global_position.x - hero.tuning.stand_size.x / 2.0) - (block.global_position.x + 8.0)
	check("pulling a stone until pinned against a wall never drags it into the hero",
			gap >= 0.0 and hero.is_on_floor(), "gap %.2f, on floor %s" % [gap, hero.is_on_floor()])
	var y := hero.global_position.y
	await press(&"jump")
	await frames(8)
	check("  and the hero can still jump out", y - hero.global_position.y > 10.0, "rose %.1f" % (y - hero.global_position.y))
	await frames(60)
	# Pull it left across the room's edge: the stone stays behind, so the hero lets go of it.
	main._enter_world_room(&"hollow_east", Vector2.INF)
	await frames(5)
	block = main.room.find_children("*", "PushBlock", true, false)[0]
	hero.global_position = block.global_position + Vector2(-20, 0)
	hero.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press(&"grab")
	Input.action_press(&"move_right")
	await frames(4)
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await until(func() -> bool: return main.room.room_id == &"hollow_clearing" and not main.transitioning, 600)
	await frames(10)
	Input.action_release(&"move_left")
	Input.action_release(&"grab")
	check("pulling a stone into the next room lets go of it", main.room.room_id == &"hollow_clearing"
			and hero.state_name != &"push", "%s %s" % [main.room.room_id, hero.state_name])


func test_spirit_door() -> void:
	GameState.set_color(GameState.SpiritColor.ORANGE, false)
	main._enter_world_room(&"ember_gate", Vector2(3752, -512))
	await frames(3)
	var gate: SpiritGate = main.room.find_children("*", "SpiritGate", true, false)[0]
	var reach := Vector2(gate.portal_overhang)
	check("the gate is one stone image with 7 runes, and a portal filling its doorway", gate.stone.texture != null
			and gate.runes.get_child_count() == 7 and gate.portal.size == Vector2(64, 96) + Vector2(reach.x * 2.0, reach.y)
			and gate.portal.position == Vector2(-32, -96) - reach, "%s %s" % [gate.portal.position, gate.portal.size])
	Input.action_press(&"move_left")
	var shown := await until(func() -> bool: return gate.hint.visible, 300)
	Input.action_release(&"move_left")
	await frames(20)
	check("standing in the doorway shows the Interact key", shown and gate.hint.visible and gate.hint.text == "C", gate.hint.text)
	check("  and walking in doesn't ask by itself", not main.confirm.visible, "")
	await press(&"interact")
	var asked := await until(func() -> bool: return main.confirm.visible, 30)
	check("pressing Interact in the doorway asks if you're ready", asked, str(hero.global_position))
	check("  with the hero held still while it asks", hero.frozen, "")
	await frames(3)
	await press(&"ui_cancel")
	await frames(3)
	check("No closes it and leaves the hero at the gate", not main.confirm.visible
			and main.room.room_id == &"ember_gate" and not hero.frozen, str(main.room.room_id))
	await press(&"interact")
	asked = await until(func() -> bool: return main.confirm.visible, 30)
	check("pressing Interact again asks again", asked, "")
	await frames(3)
	for action: StringName in [&"move_right", &"jump"]:
		await press(action)
		await frames(1)
	await frames(3)
	check("picking No with right then jump also stays outside", main.room.room_id == &"ember_gate"
			and not main.confirm.visible, str(main.room.room_id))
	var doorway := gate.global_position
	await press(&"interact")
	await until(func() -> bool: return main.confirm.visible, 30)
	await frames(3)
	await press(&"jump")
	var entered := await until(func() -> bool: return main.room.room_id == &"ember_spirit_room" and not main.transitioning, 120)
	check("Yes enters the Spirit Room at its start", entered
			and hero.global_position.distance_to(main.room.named_spawn(&"Start")) < 2.0, str(hero.global_position))
	check("  remembering the gate it came in through", GameState.spirit_return_room == &"ember_gate"
			and GameState.spirit_return_spot == doorway, "%s %s" % [GameState.spirit_return_room, GameState.spirit_return_spot])
	await frames(10)
	Input.action_press(&"move_right")
	await frames(60)
	Input.action_release(&"move_right")
	check("a Spirit Room's edge is a wall: walking off it goes nowhere", main.room.room_id == &"ember_spirit_room"
			and not main.transitioning and hero.global_position.x <= main.room.world_bounds().end.x, str(hero.global_position))
	# An exit gate, placed where the hero stands.
	var exit: SpiritGate = load("res://entities/spirit_gate.tscn").instantiate()
	exit.mode = SpiritGate.Mode.EXIT
	main.room.add_child(exit)
	exit.global_position = hero.global_position
	await frames(3)
	check("an exit gate stays dark during the run", main.is_spirit_run() and not exit.is_open()
			and not exit.portal.visible and exit.hint.visible, "")
	await press(&"interact")
	await frames(5)
	check("  and Interact there doesn't leave yet, but says why", main.room.room_id == &"ember_spirit_room"
			and main.prompt.text == SpiritGate.LOCKED_MESSAGE, main.prompt.text)
	main._run_active = false  # As taking the room's color does.
	await frames(2)
	check("once the color is taken it opens", exit.is_open() and exit.portal.visible, "")
	await press(&"interact")
	var left := await until(func() -> bool: return main.room.room_id == &"ember_gate" and not main.transitioning, 120)
	check("Interact at the open exit goes back to the gate the hero came in through", left
			and hero.global_position.distance_to(doorway) < 2.0, "%s at %s" % [main.room.room_id, hero.global_position])
	check("  and forgets it", GameState.spirit_return_room == &"", str(GameState.spirit_return_room))


func test_menus() -> void:
	main._enter_world_room(&"hollow_clearing", Vector2(88, 240))
	await frames(3)
	await press(&"pause")
	check("Esc pauses the game and opens the pause menu", get_tree().paused and main.pause_menu.is_open, "")
	var x := hero.global_position.x
	Input.action_press(&"move_right")
	await frames(10)
	Input.action_release(&"move_right")
	check("  the hero stays still while paused", hero.global_position.x == x, "")
	# Rows: Resume, Map, Settings, Quit.
	await press(&"move_down")
	await press(&"move_down")
	await press(&"ui_accept")
	check("Settings opens from the pause menu", main.pause_menu.title.text == "Settings", main.pause_menu.title.text)
	# Rows: Music, Sound, Fullscreen, Window size, Screen shake, Speedrun timer, Back.
	var music := Settings.music_volume
	await press(&"move_left")
	check("  the music slider steps down by 10%", is_equal_approx(Settings.music_volume, music - 0.1), str(Settings.music_volume))
	await press(&"move_right")
	for i in 4:
		await press(&"move_down")
	var shake := Settings.screen_shake
	await press(&"ui_accept")
	check("  screen shake toggles", Settings.screen_shake != shake, "")
	await press(&"ui_accept")
	await press(&"move_down")
	await press(&"ui_accept")
	check("  the speedrun timer shows when turned on", Settings.speedrun_timer and main.get_node(^"Hud/SpeedrunTimer").visible, "")
	await press(&"ui_accept")
	await press(&"pause")
	check("Esc in Settings goes back to the pause menu", main.pause_menu.title.text == "Paused" and main.pause_menu.is_open, "")
	await press(&"move_up")
	await press(&"ui_accept")
	check("Map opens from the pause menu", main.map_screen.is_open and get_tree().paused, "")
	await press(&"map")
	check("closing it goes back to the pause menu", not main.map_screen.is_open and main.pause_menu.visible
			and get_tree().paused, "")
	await press(&"pause")
	check("Esc again resumes", not get_tree().paused and not main.pause_menu.is_open, "")
	await press(&"map")
	check("Tab opens the map on its own", main.map_screen.is_open and get_tree().paused, "")
	check("  showing the rooms visited", main.map_screen._visited_rooms().has(&"ember_gate")
			and main.map_screen._visited_rooms().has(&"hollow_clearing"), str(main.map_screen._visited_rooms()))
	check("  but not Spirit Rooms, which stand apart", not main.map_screen._visited_rooms().has(&"ember_spirit_room"), "")
	await press(&"map")
	check("  and Tab closes it", not main.map_screen.is_open and not get_tree().paused, "")
	main._enter_world_room(&"ember_spirit_room", Vector2.INF)
	await frames(3)
	await press(&"map")
	check("the map opens inside a Spirit Room too", main.map_screen.is_open, "")
	await press(&"map")
	await press(&"pause")
	# Rows: Resume, Map, Settings, Leave Spirit Room, Quit.
	for i in 3:
		await press(&"move_down")
	await press(&"ui_accept")
	await until(func() -> bool: return main.room.room_id == &"ember_gate" and not main.transitioning, 120)
	var gate: SpiritGate = main.room.find_children("*", "SpiritGate", true, false)[0]
	check("Leave Spirit Room puts the hero back at its gate", main.room.room_id == &"ember_gate"
			and hero.global_position.distance_to(gate.global_position) < 2.0 and not get_tree().paused, str(hero.global_position))


func test_waystones() -> void:
	GameState.set_all_colors(false)
	var stops := WorldMap.travel_stops()
	check("the world map knows where travel goes: the Hollow first, then each region's waystone",
			stops.size() >= 3 and stops[0]["kind"] == Waystone.Kind.HOLLOW and stops[0]["room"] == &"hollow_clearing"
			and stops.any(func(stop: Dictionary) -> bool: return stop["room"] == &"ember_gate" and stop["color"] == 0)
			and stops.any(func(stop: Dictionary) -> bool: return stop["room"] == &"meadow_gate" and stop["color"] == 1),
			str(stops))
	# Checkpoint stones carry their region's rune.
	var glyphs := {}
	for id: StringName in [&"ember_entry", &"meadow_breakers"]:
		var room: Room = load(WorldMap.scene_of(id)).instantiate()
		add_child(room)
		glyphs[id] = (room.find_children("*", "CheckpointStone", true, false)[0] as CheckpointStone).rune.glyph
		room.free()
	check("checkpoint stones carry their region's rune, different from region to region",
			glyphs[&"ember_entry"] == CheckpointStone.REGION_GLYPHS[&"ember_grove"]
			and glyphs[&"meadow_breakers"] == CheckpointStone.REGION_GLYPHS[&"meadow"]
			and glyphs[&"ember_entry"] != glyphs[&"meadow_breakers"], str(glyphs))
	# The Hollow: a center stone and a ring of six, each with its own rune.
	main._enter_world_room(&"hollow_clearing", Vector2(272, 240))
	await frames(5)
	var stones := main.room.find_children("*", "Waystone", true, false)
	var runes := {}
	for stone: Waystone in stones:
		runes[stone.rune.glyph] = true
	var center: Waystone = stones.filter(func(stone: Waystone) -> bool: return stone.kind == Waystone.Kind.HOLLOW)[0]
	var orange: Waystone = stones.filter(func(stone: Waystone) -> bool:
		return stone.kind == Waystone.Kind.RING and stone.color == GameState.SpiritColor.ORANGE)[0]
	check("the Hollow has its center stone and six region stones, each with its own rune",
			stones.size() == 7 and runes.size() == 7, "%d stones, %d runes" % [stones.size(), runes.size()])
	check("  with no colors back, only the center stone is awake",
			stones.filter(func(stone: Waystone) -> bool: return stone.is_awake()).size() == 1 and center.is_awake(), "")
	check("standing at the center stone shows the Interact key", center.hint.visible and not orange.hint.visible, "")
	await press(&"interact")
	await frames(2)
	check("Interact opens the travel menu and pauses, with nowhere to go yet", main.travel_menu.is_open
			and get_tree().paused and main.travel_menu.info.text.begins_with("No other"), main.travel_menu.info.text)
	await press(&"ui_cancel")
	await frames(3)
	check("  and Esc closes it without opening the pause menu", not main.travel_menu.is_open
			and not get_tree().paused and not main.pause_menu.is_open, "")
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	await frames(2)
	check("orange wakes the orange ring stone, glowing orange, and only it", orange.is_awake()
			and orange.rune.color == ColorOrb.TINTS[0] and orange.rune.brightness > 0.5
			and stones.filter(func(stone: Waystone) -> bool: return stone.is_awake()).size() == 2, "")
	await press(&"interact")
	await frames(2)
	check("the menu now offers Ember Grove, then Stay", main.travel_menu.menu._rows.size() == 2
			and main.travel_menu.menu._labels[0].text.contains("Ember Grove"), main.travel_menu.menu._labels[0].text)
	await press(&"ui_accept")
	var arrived := await until(func() -> bool: return main.room.room_id == &"ember_gate" and not main.transitioning, 180)
	var ember: Waystone = main.room.find_children("*", "Waystone", true, false)[0]
	check("picking it travels to Ember Grove's waystone, by its gate", arrived
			and hero.global_position.distance_to(ember.global_position) < 2.0, "%s at %s" % [main.room.room_id, hero.global_position])
	check("  which is awake, and where a death now respawns", ember.is_awake()
			and GameState.respawn_position.distance_to(ember.global_position) < 2.0, str(GameState.respawn_position))
	await frames(3)
	await press(&"interact")
	await frames(2)
	check("its menu offers the Hollow", main.travel_menu.is_open
			and main.travel_menu.menu._labels[0].text.contains("The Hollow"), main.travel_menu.menu._labels[0].text)
	await press(&"ui_accept")
	var home := await until(func() -> bool: return main.room.room_id == &"hollow_clearing" and not main.transitioning, 180)
	check("  and takes the hero home to the center stone", home
			and hero.global_position.distance_to(center.global_position if is_instance_valid(center) else Vector2(272, 240)) < 2.0,
			str(hero.global_position))
	# Asleep, a region stone is still a checkpoint.
	main._enter_world_room(&"meadow_gate", Vector2(600, 240))
	await frames(3)
	var meadow: Waystone = main.room.find_children("*", "Waystone", true, false)[0]
	hero.global_position = meadow.global_position
	await frames(5)
	check("the Meadow's stone sleeps without yellow, but works as a checkpoint", not meadow.is_awake()
			and meadow.lit and not meadow.hint.visible, "")
	GameState.set_all_colors(false)


func test_save_round_trip() -> void:
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	GameState.set_flag(&"hollow_shortcut")
	GameState.record_time(&"ember_spirit_room", 42.5)
	GameState.spirit_return_room = &"ember_gate"
	GameState.spirit_return_spot = Vector2(3378, -64)
	main._enter_world_room(&"ember_leaves", Vector2(3052, 240))
	await frames(2)
	GameState.new_game(SLOT)
	var loaded := GameState.load_game(SLOT)
	check("a save loads back", loaded, "")
	check("it remembers the room and spot", GameState.room_id == &"ember_leaves"
			and GameState.respawn_position.distance_to(Vector2(3052, 240)) < 1.0, "%s %s" % [GameState.room_id, GameState.respawn_position])
	check("it remembers colors, shortcuts, and best times", GameState.has_color(GameState.SpiritColor.ORANGE)
			and GameState.has_flag(&"hollow_shortcut") and is_equal_approx(GameState.best_time(&"ember_spirit_room"), 42.5), "")
	check("it remembers the gate to go back to", GameState.spirit_return_room == &"ember_gate"
			and GameState.spirit_return_spot == Vector2(3378, -64), "%s %s" % [GameState.spirit_return_room, GameState.spirit_return_spot])


# --- Harness -------------------------------------------------------------------------------

func _shown(layer: int, value: float) -> bool:
	return is_equal_approx(main._shown_color[layer], value)


func _layer_of(item: CanvasItem) -> int:
	var shader_material := item.material as ShaderMaterial
	return shader_material.get_shader_parameter(&"layer") if shader_material else -1


func _lit_checkpoints() -> int:
	return main.room.find_children("*", "CheckpointStone", true, false).filter(
			func(stone: Node) -> bool: return (stone as CheckpointStone).lit).size()


func _nearest(nodes: Array, point: Vector2) -> Node2D:
	var best: Node2D
	for node: Node2D in nodes:
		if best == null or node.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = node
	return best


## Press and release a button, a frame each.
func press(action: StringName) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	await frames(1)


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
