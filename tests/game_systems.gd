extends Node
## Checks the game's systems through the real game scene: the world map matches the rooms,
## checkpoints set the respawn point, Spirit Rooms restart from their start and count deaths,
## crumbling ledges and leaves behave and reset, region color follows the colors, and saves
## round-trip. Uses save slot 9 and deletes it afterwards.
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
	await test_spirit_door()
	await test_save_round_trip()
	GameState.delete_save()
	await frames(5)
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(_failures)


func test_world_map() -> void:
	for id: StringName in WorldMap.ROOMS:
		var info: Dictionary = WorldMap.ROOMS[id]
		var room: Room = load(info["scene"]).instantiate()
		var terrain := room.get_node(^"Terrain") as TerrainLayout
		check("%s's layout is %s tiles, as the world map says" % [id, info["size"]],
				terrain != null and terrain.layout_size() == info["size"],
				str(terrain.layout_size()) if terrain else "no TerrainLayout")
		var bounds := Rect2(Vector2.ZERO, Vector2(info["size"]) * 16.0)
		var spawns := room.get_node(^"Spawns").get_children()
		check("%s has spawn points, all inside it" % id, not spawns.is_empty()
				and spawns.all(func(s: Node) -> bool: return bounds.has_point((s as Node2D).position - Vector2(0, 1))), "")
		room.free()
	for a: StringName in WorldMap.ROOMS:
		for b: StringName in WorldMap.ROOMS:
			if a < b:
				check("%s and %s don't overlap" % [a, b], not WorldMap.rect_px(a).intersects(WorldMap.rect_px(b)), "")


func test_checkpoint_respawn() -> void:
	main._enter_world_room(&"hollow_east", Vector2(1192, 160))
	await frames(5)
	check("touching a checkpoint stone lights it", _lit_checkpoints() == 1, "")
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	check("dying after a checkpoint respawns at the checkpoint", hero.global_position.distance_to(Vector2(1192, 160)) < 2.0,
			str(hero.global_position))
	main._enter_world_room(&"hollow_east", Vector2(680, 240))
	await frames(5)
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	check("re-entering a room forgets its checkpoint", hero.global_position.x < 700.0, str(hero.global_position))


func test_spirit_room_restart() -> void:
	GameState.set_color(GameState.SpiritColor.ORANGE, false)
	main._enter_world_room(&"ember_spirit_room", Vector2(2450, -64))
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
	main._enter_world_room(&"hollow_east", Vector2(1300, 160))
	await frames(2)
	var crumble: CrumblePlatform = main.room.find_children("*", "CrumblePlatform", true, false)[0]
	await until(func() -> bool: return crumble.phase == CrumblePlatform.Phase.GONE, 60)
	check("a crumbling ledge falls after being stood on", crumble.phase == CrumblePlatform.Phase.GONE, "")
	hero.die()
	await until(func() -> bool: return hero.state_name == &"idle", 60)
	check("dying puts the crumbling ledge back", crumble.phase == CrumblePlatform.Phase.SOLID, "")
	main._enter_world_room(&"hollow_east", Vector2(1192, 160))
	await frames(2)
	crumble = main.room.find_children("*", "CrumblePlatform", true, false)[0]
	crumble.phase = CrumblePlatform.Phase.GONE
	crumble._timer = 0.2
	await frames(20)
	check("a fallen ledge comes back on its own", crumble.phase == CrumblePlatform.Phase.SOLID, "")


func test_sinking_leaf() -> void:
	main._enter_world_room(&"ember_leaves", Vector2(2424, 230))
	await frames(2)
	var leaf: SinkingLeaf = _nearest(main.room.find_children("*", "SinkingLeaf", true, false), Vector2(2424, 240))
	var top := leaf.global_position.y
	await until(func() -> bool: return leaf.global_position.y > top + 0.5, 60)
	var landed_at := leaf.global_position.y
	await frames(30)
	var sunk := leaf.global_position.y - landed_at
	check("a lily pad sinks twice as fast under the hero (56 px/s: about 28 px in half a second)",
			absf(sunk - 28.0) < 3.0, "%.1f px" % sunk)
	hero.respawn(Vector2(2300, 240), true)
	await frames(90)
	check("a lily pad floats back up when left", absf(leaf.global_position.y - top) < 1.0,
			"%.1f px" % (leaf.global_position.y - top))
	check("the lily pad room has no checkpoint", main.room.find_children("*", "CheckpointStone", true, false).is_empty(), "")
	var deaths := GameState.deaths
	hero.respawn(Vector2(2424, 230), true)
	await until(func() -> bool: return GameState.deaths > deaths, 240)
	check("standing on a lily pad too long sinks you into the pit", GameState.deaths == deaths + 1, "")
	var back := await until(func() -> bool: return absf(leaf.global_position.y - top) < 4.0, 10)
	check("the pit death puts the lily pad back", back, "%.1f px" % (leaf.global_position.y - top))
	await frames(40)
	check("the lily pad snapping back doesn't fling the hero", main.room.room_id == &"ember_leaves"
			and hero.global_position.y > 200.0, "%s at %s" % [main.room.room_id, hero.global_position])
	main._enter_world_room(&"ember_leaves", Vector2(2648, 208))
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
	var terrain := main.room.get_node(^"Terrain") as TerrainLayout
	check("the ground is on the ground layer and thorns on the hazards layer",
			_layer_of(terrain) == WorldColor.Layer.GROUND and _layer_of(terrain.hazards) == WorldColor.Layer.HAZARDS, "")
	check("thorns draw in front of bushes and objects", terrain.hazards.z_index > 2, str(terrain.hazards.z_index))
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	await frames(2)
	check("with orange the sky is full color, far hills 20%, near forest 10%",
			_shown(0, 1.0) and _shown(1, 0.2) and _shown(2, 0.1) and _shown(3, 0.0), str(main._shown_color))
	main._enter_world_room(&"ember_entry", Vector2(1500, 160))
	await frames(2)
	check("the color stays in other rooms", _shown(0, 1.0) and _shown(1, 0.2), str(main._shown_color))
	main._enter_world_room(&"ember_spirit_room", Vector2(2450, -64))
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


func test_spirit_door() -> void:
	GameState.set_color(GameState.SpiritColor.ORANGE, false)
	main._enter_world_room(&"ember_gate", Vector2(2720, -64))
	await frames(3)
	var door: SpiritArchway = main.room.find_children("*", "SpiritArchway", true, false)[0]
	Input.action_press(&"move_left")
	var asked := await until(func() -> bool: return main.confirm.visible, 300)
	Input.action_release(&"move_left")
	check("walking into the door asks if you're ready", asked, str(hero.global_position))
	check("  with the hero held still while it asks", hero.frozen, "")
	await frames(3)
	Input.action_press(&"ui_cancel")
	await frames(2)
	Input.action_release(&"ui_cancel")
	await frames(3)
	check("No closes it and leaves the hero outside the door", not main.confirm.visible
			and main.room.room_id == &"ember_gate" and absf(hero.global_position.x - door.outside_x()) < 2.0 and not hero.frozen,
			"%s at %s" % [main.room.room_id, hero.global_position])
	Input.action_press(&"move_left")
	asked = await until(func() -> bool: return main.confirm.visible, 120)
	Input.action_release(&"move_left")
	check("walking back in asks again", asked, "")
	await frames(3)
	for action: StringName in [&"move_right", &"jump"]:
		Input.action_press(action)
		await frames(2)
		Input.action_release(action)
		await frames(2)
	check("picking No with right then jump also stays outside", main.room.room_id == &"ember_gate"
			and not main.confirm.visible, str(main.room.room_id))
	main._enter_world_room(&"ember_spirit_room", Vector2(2540, -64))
	await frames(3)
	Input.action_press(&"move_right")
	await until(func() -> bool: return main.room.room_id == &"ember_gate" and not main.transitioning, 240)
	await frames(30)
	Input.action_release(&"move_right")
	door = main.room.find_children("*", "SpiritArchway", true, false)[0]
	check("walking out of the Spirit Room through the door never asks, and passes it",
			not main.confirm.visible and hero.global_position.x > door.outside_x(), str(hero.global_position))


func test_save_round_trip() -> void:
	GameState.set_color(GameState.SpiritColor.ORANGE, true)
	GameState.set_flag(&"hollow_shortcut")
	GameState.record_time(&"ember_spirit_room", 42.5)
	main._enter_world_room(&"ember_leaves", Vector2(2300, 240))
	await frames(2)
	GameState.new_game(SLOT)
	var loaded := GameState.load_game(SLOT)
	check("a save loads back", loaded, "")
	check("it remembers the room and spot", GameState.room_id == &"ember_leaves"
			and GameState.respawn_position.distance_to(Vector2(2300, 240)) < 1.0, "%s %s" % [GameState.room_id, GameState.respawn_position])
	check("it remembers colors, shortcuts, and best times", GameState.has_color(GameState.SpiritColor.ORANGE)
			and GameState.has_flag(&"hollow_shortcut") and is_equal_approx(GameState.best_time(&"ember_spirit_room"), 42.5), "")


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
