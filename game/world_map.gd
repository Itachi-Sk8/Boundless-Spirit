class_name WorldMap
## Where every room sits in the one connected forest. Origins and sizes are in tiles; a room's
## terrain layout must be exactly `size` tiles (the tests check). Walking off a room's edge
## enters whichever room covers that spot, so rooms connect by where they are, not by wiring.

const TILE := 16
const START_ROOM := &"hollow_clearing"

const ROOMS := {
	&"meadow_edge": {
		"scene": "res://rooms/meadow/meadow_edge.tscn",
		"origin": Vector2i(-70, 0), "size": Vector2i(30, 20), "region": &"meadow",
	},
	&"hollow_west": {
		"scene": "res://rooms/hollow/hollow_west.tscn",
		"origin": Vector2i(-40, 0), "size": Vector2i(40, 20), "region": &"hollow",
	},
	&"hollow_clearing": {
		"scene": "res://rooms/hollow/hollow_clearing.tscn",
		"origin": Vector2i(0, 0), "size": Vector2i(40, 20), "region": &"hollow",
	},
	&"hollow_east": {
		"scene": "res://rooms/hollow/hollow_east.tscn",
		"origin": Vector2i(40, 0), "size": Vector2i(50, 20), "region": &"hollow",
	},
	&"ember_entry": {
		"scene": "res://rooms/ember_grove/ember_entry.tscn",
		"origin": Vector2i(90, 0), "size": Vector2i(50, 20), "region": &"ember_grove",
	},
	&"ember_leaves": {
		"scene": "res://rooms/ember_grove/ember_leaves.tscn",
		"origin": Vector2i(140, 0), "size": Vector2i(50, 20), "region": &"ember_grove",
	},
	&"ember_climb": {
		"scene": "res://rooms/ember_grove/ember_climb.tscn",
		"origin": Vector2i(190, -17), "size": Vector2i(30, 37), "region": &"ember_grove",
	},
	&"ember_gate": {
		"scene": "res://rooms/ember_grove/ember_gate.tscn",
		"origin": Vector2i(160, -17), "size": Vector2i(30, 17), "region": &"ember_grove",
	},
	&"ember_spirit_room": {
		"scene": "res://rooms/ember_grove/ember_spirit_room.tscn",
		"origin": Vector2i(60, -17), "size": Vector2i(100, 17), "region": &"ember_grove",
	},
}


## The room's area in world pixels.
static func rect_px(id: StringName) -> Rect2:
	var room: Dictionary = ROOMS[id]
	return Rect2(Vector2(room["origin"]) * TILE, Vector2(room["size"]) * TILE)


## The room covering a world point, or &"" if none does.
static func room_at(point: Vector2) -> StringName:
	for id: StringName in ROOMS:
		if rect_px(id).has_point(point):
			return id
	return &""


## True if a world point is inside solid terrain (grass or rock) in room `id`. Room changes
## only go through where the room being entered is open, so its solid edge works as a wall.
static func solid_at(id: StringName, point: Vector2) -> bool:
	var rows := _layout_rows(id)
	var cell := Vector2i(((point - rect_px(id).position) / TILE).floor())
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return false
	return rows[cell.y][cell.x] in TerrainLayout.SOLID


static var _layout_cache := {}


static func _layout_rows(id: StringName) -> PackedStringArray:
	if not _layout_cache.has(id):
		# Instantiate without adding to the tree just to read the layout text.
		var room: Node = load(ROOMS[id]["scene"]).instantiate()
		var terrain := room.get_node_or_null(^"Terrain") as TerrainLayout
		_layout_cache[id] = TerrainLayout.rows_of(terrain.layout if terrain else "")
		room.free()
	return _layout_cache[id]


## The room whose scene is at `path`, or &"" if it isn't part of the world.
static func room_for_scene(path: String) -> StringName:
	for id: StringName in ROOMS:
		if ROOMS[id]["scene"] == path:
			return id
	return &""
