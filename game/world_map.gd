class_name WorldMap
## Where every room sits in the one connected forest. Every scene under res://rooms/ is a room,
## except in test/ and anything whose name starts with "_" (the template, the world view); its id is its file name, and its root node says where it
## sits (`world_origin`, in tiles) and which region it belongs to. Its size is its terrain
## layout's size. Walking off a room's edge enters whichever room covers that spot, so rooms
## connect by where they are, not by wiring. Adding a room is just saving a new scene there.

const TILE := 16
const START_ROOM := &"hollow_clearing"
const ROOMS_DIR := "res://rooms/"
## Folders under rooms/ that aren't part of the world (nor is anything starting with "_").
const SKIP_DIRS: Array[String] = ["test"]
const CHECKPOINT_SCENE := "res://entities/checkpoint_stone.tscn"
const ARCHWAY_SCENE := "res://entities/spirit_archway.tscn"
## Region ids (Room.region) and the names the map shows for them.
const REGION_NAMES := {
	&"hollow": "The Hollow", &"ember_grove": "Ember Grove", &"meadow": "Sunlit Meadow",
	&"canopy": "The Canopy", &"briar": "The Briar", &"caverns": "Underroot Caverns",
	&"falls": "Misty Falls", &"heart": "The Heart",
}

# Room id -> {scene, origin (tiles), size (tiles), region, spirit_room, rows (layout),
# checkpoints, doors}. Read from the room scenes the first time it's needed.
static var _rooms := {}


## Every room, by id. Each is a Dictionary: "scene" (path), "origin" and "size" (Vector2i,
## tiles), "region" (StringName), "spirit_room" (bool), "rows" (the layout's rows), and
## "checkpoints" (checkpoint stone positions in room px), and "doors" (each Spirit Room
## archway: {"target": the room it leads to, "outside": where to stand outside it, room px}).
static func rooms() -> Dictionary:
	if _rooms.is_empty():
		for path in _room_scenes(ROOMS_DIR):
			_rooms[StringName(path.get_file().get_basename())] = _read_room(path)
		for pair: Array in overlaps():
			push_warning("Rooms %s and %s overlap: change one's World Origin (open rooms/_world_view.tscn to see)." % pair)
	return _rooms


static func has_room(id: StringName) -> bool:
	return rooms().has(id)


## Forget what was read, so changed room scenes are read again.
static func reload() -> void:
	_rooms.clear()


## The room's area in world pixels.
static func rect_px(id: StringName) -> Rect2:
	var room: Dictionary = rooms()[id]
	return Rect2(Vector2(room["origin"]) * TILE, Vector2(room["size"]) * TILE)


static func scene_of(id: StringName) -> String:
	return rooms()[id]["scene"]


static func region_of(id: StringName) -> StringName:
	return rooms()[id]["region"] if has_room(id) else &""


## The room covering a world point, or &"" if none does.
static func room_at(point: Vector2) -> StringName:
	for id: StringName in rooms():
		if rect_px(id).has_point(point):
			return id
	return &""


## True if a world point is inside solid terrain (grass or rock) in room `id`. Room changes
## only go through where the room being entered is open, so its solid edge works as a wall.
static func solid_at(id: StringName, point: Vector2) -> bool:
	var rows: PackedStringArray = rooms()[id]["rows"]
	var cell := Vector2i(((point - rect_px(id).position) / TILE).floor())
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return false
	return rows[cell.y][cell.x] in TerrainLayout.SOLID


## The room whose scene is at `path`, or &"" if it isn't part of the world.
static func room_for_scene(path: String) -> StringName:
	for id: StringName in rooms():
		if rooms()[id]["scene"] == path:
			return id
	return &""


## The archway leading into room `id`: {"room": the room it stands in, "outside": the world
## spot just outside it}, or an empty Dictionary if no archway leads there.
static func door_into(id: StringName) -> Dictionary:
	for other: StringName in rooms():
		for door: Dictionary in rooms()[other]["doors"]:
			if door["target"] == id:
				return {"room": other, "outside": rect_px(other).position + door["outside"]}
	return {}


## Pairs of rooms that overlap (each a two-item Array of ids): every one is a mistake.
static func overlaps() -> Array:
	var found := []
	var ids := rooms().keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rect_px(ids[i]).intersects(rect_px(ids[j])):
				found.append([ids[i], ids[j]])
	return found


static func _room_scenes(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for entry in ResourceLoader.list_directory(dir):
		if entry.begins_with("_"):
			continue
		if entry.ends_with("/"):
			if not entry.trim_suffix("/") in SKIP_DIRS:
				found.append_array(_room_scenes(dir + entry))
		elif entry.ends_with(".tscn"):
			found.append(dir + entry)
	found.sort()
	return found


# Read a room's place, size, and markers from its scene file without building it.
static func _read_room(path: String) -> Dictionary:
	var info := {
		"scene": path, "origin": Vector2i.ZERO, "size": Vector2i.ZERO, "region": &"hollow",
		"spirit_room": false, "rows": PackedStringArray(), "checkpoints": [], "doors": [],
	}
	var state := (load(path) as PackedScene).get_state()
	var offsets := {}  # node path -> position in the room
	var has_layout := false
	for i in state.get_node_count():
		var node_path := _clean(state.get_node_path(i))
		var parent_path := _clean(state.get_node_path(i, true)) if i > 0 else ""
		var local := Vector2.ZERO
		var properties := {}
		for p in state.get_node_property_count(i):
			var property := state.get_node_property_name(i, p)
			var value: Variant = state.get_node_property_value(i, p)
			properties[property] = value
			if property == &"position":
				local = value
			elif i == 0 and property == &"world_origin":
				info["origin"] = value
			elif i == 0 and property == &"region":
				info["region"] = StringName(value)
			elif i == 0 and property == &"spirit_room":
				info["spirit_room"] = value
			elif node_path == "Terrain" and property == &"layout":
				info["rows"] = TerrainLayout.rows_of(value)
				has_layout = true
		var offset: Vector2 = offsets.get(parent_path, Vector2.ZERO) + local if i > 0 else Vector2.ZERO
		offsets[node_path] = offset
		var instance := state.get_node_instance(i)
		if instance and instance.resource_path == CHECKPOINT_SCENE:
			info["checkpoints"].append(offset)
		elif instance and instance.resource_path == ARCHWAY_SCENE:
			info["doors"].append(_door(properties, offset))
	var rows: PackedStringArray = info["rows"]
	if has_layout and not rows.is_empty():
		var width := 0
		for row in rows:
			width = maxi(width, row.length())
		info["size"] = Vector2i(width, rows.size())
	else:
		# Painted by hand: measure the painted tiles.
		var room: Node = (load(path) as PackedScene).instantiate()
		var terrain := room.get_node_or_null(^"Terrain") as TileMapLayer
		if terrain:
			info["size"] = terrain.get_used_rect().end
		room.free()
	return info


# Where an archway leads and the spot just outside its opening (as SpiritArchway.outside_x()),
# from the properties set on it in the room and the script's defaults for the rest.
static func _door(properties: Dictionary, offset: Vector2) -> Dictionary:
	var script: Script = SpiritArchway
	var value := func(property: StringName) -> Variant:
		return properties.get(property, script.get_property_default_value(property))
	var opening: Vector2i = value.call(&"opening_size")
	var pillar: int = value.call(&"pillar_width")
	var outside := offset + Vector2((pillar + opening.x) * TILE + 8, 0)
	return {"target": StringName(value.call(&"target_room")), "outside": outside}


static func _clean(node_path: NodePath) -> String:
	var text := String(node_path)
	return "" if text == "." else text.trim_prefix("./")
