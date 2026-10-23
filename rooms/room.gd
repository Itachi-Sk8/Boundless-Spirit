@tool
class_name Room
extends Node2D
## A room: its terrain, spawn points, and everything that resets when the hero dies. The game
## (game/main.gd) places rooms in the world at their WorldMap origin and brings the hero and
## camera; rooms hold neither. Run a room on its own (F6) and the game starts in it.
##
## Nodes it expects: Terrain (TileMapLayer, usually a TerrainLayout) and Spawns (Marker2D
## children). Things that reset on death join the "room_reset" group and have reset_to_start().
## Props, Decor, Leaves, Entities, Terrain, and Thorns are drawn on their color layers (WorldColor);
## anything in the "full_color" group keeps its color.
##
## In the editor, the room's area is outlined (with its neighbours, red where they overlap), and
## the Room Size buttons grow or shrink it on any side.

## Nodes whose children are placed in the room (the room's own children are placed too).
const CONTAINERS: Array[StringName] = [&"Props", &"Decor", &"Hazards", &"Entities", &"Spawns", &"Signs"]
const TILE := 16
const OUTLINE := Color(1.0, 0.85, 0.2)
const OVERLAP := Color(1.0, 0.2, 0.2)
const NEIGHBOUR := Color(0.75, 0.85, 1.0, 0.5)

## Where the room sits in the world, in tiles from the Hollow clearing's top-left corner. Rooms
## connect where their edges touch (see docs/BUILDING_ROOMS.md); open rooms/world_view.tscn to
## see them all in place.
@export var world_origin := Vector2i.ZERO:
	set(value):
		world_origin = value
		_redraw_outline()
## The region the room belongs to: its backdrop tint and its name on the map.
@export_enum("hollow", "ember_grove", "meadow", "canopy", "briar", "caverns", "falls", "heart")
var region := "hollow"
## Spirit Rooms: one run, always restarting from the start, with checkpoints ignored and the
## run timed.
@export var spirit_room := false
## The test room shows the debug overlay on arrival.
@export var debug_room := false
## Camera bounds in room coordinates. Left empty, they come from the room's area.
@export var bounds := Rect2()

@export_group("Room Size")
## The room's size in tiles, when set by the buttons below for a room painted by hand. Zero
## means the room is as big as its terrain (a text layout's size, or the painted tiles).
@export var size_tiles := Vector2i.ZERO:
	set(value):
		size_tiles = value.max(Vector2i.ZERO)
		_redraw_outline()
## How many rows or columns each button below adds or takes away.
@export_range(1, 50) var resize_step := 1
## When on, the buttons also move every room beyond the edge being moved (their World Origin,
## saved in their own scene files) by the same amount, so the rooms next door stay touching and
## nothing overlaps. Spirit Rooms never move. Ctrl+Z moves them back too.
@export var push_neighbours := true
@export_tool_button("Add rows on top", "ArrowUp") var add_top_button := _add_top
@export_tool_button("Remove rows on top", "ArrowDown") var remove_top_button := _remove_top
@export_tool_button("Add rows at bottom", "ArrowDown") var add_bottom_button := _add_bottom
@export_tool_button("Remove rows at bottom", "ArrowUp") var remove_bottom_button := _remove_bottom
@export_tool_button("Add columns on left", "ArrowLeft") var add_left_button := _add_left
@export_tool_button("Remove columns on left", "ArrowRight") var remove_left_button := _remove_left
@export_tool_button("Add columns on right", "ArrowRight") var add_right_button := _add_right
@export_tool_button("Remove columns on right", "ArrowLeft") var remove_right_button := _remove_right
@export_tool_button("Refresh neighbours", "Reload") var refresh_neighbours_button := _read_neighbours

var room_id: StringName = &""

# Editor only: the outline drawn over the room, and the other rooms' areas ([id, world Rect2]).
var _outline: Node2D
var _neighbours: Array = []
var _shown_area := Rect2()

@onready var terrain: TileMapLayer = $Terrain


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor()
		return
	set_process(false)
	if get_tree().current_scene == self:
		# Run on its own: start the game in this room instead.
		GameState.pending_room_scene = scene_file_path
		get_tree().change_scene_to_file.call_deferred("res://game/main.tscn")
		return
	if bounds.size == Vector2.ZERO:
		bounds = _terrain_bounds()
	if not debug_room:
		_paint_color_layers()


func _process(_delta: float) -> void:
	# Editor only: follow the layout text and painting as they change.
	if _outline and _terrain_bounds() != _shown_area:
		_redraw_outline()


## The room's area in world pixels.
func world_bounds() -> Rect2:
	return Rect2(global_position + bounds.position, bounds.size)


## The room's size in tiles: its Room Size where set, otherwise its terrain's.
func size_in_tiles() -> Vector2i:
	return Vector2i((_terrain_bounds().size / TILE).round())


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var spawns := get_node_or_null(^"Spawns")
	if spawns:
		for marker in spawns.get_children():
			points.append((marker as Node2D).global_position)
	return points


## A named spawn point (e.g. "Start"), or Vector2.INF if there isn't one.
func named_spawn(spawn_name: StringName) -> Vector2:
	var marker := get_node_or_null(NodePath("Spawns/" + String(spawn_name))) as Node2D
	return marker.global_position if marker else Vector2.INF


## The spawn point closest to a world point, or the point itself if there are none.
func nearest_spawn(point: Vector2) -> Vector2:
	var best := point
	var best_distance := INF
	for spawn in spawn_points():
		var distance := spawn.distance_squared_to(point)
		if distance < best_distance:
			best = spawn
			best_distance = distance
	return best


## Put everything that resets on death back where it started.
func reset_room() -> void:
	get_tree().call_group(&"room_reset", &"reset_to_start")


## Grow (`amount` > 0) or shrink (`amount` < 0) the room on one side, in tiles. A text layout
## gains or loses rows or columns of empty tiles; a room painted by hand gets a Room Size. On the
## top or left, everything in the room moves along and World Origin moves the other way, so
## nothing moves in the world. With `push_neighbours`, the rooms beyond that edge move with it.
## In the editor it's one step that Ctrl+Z undoes.
func resize_side(side: Side, amount: int) -> void:
	var axis := 0 if side == SIDE_LEFT or side == SIDE_RIGHT else 1
	var size := size_in_tiles()
	var new_size := size
	new_size[axis] = maxi(1, size[axis] + amount)
	amount = new_size[axis] - size[axis]
	if amount == 0:
		return
	var shift := Vector2i.ZERO
	if side == SIDE_LEFT or side == SIDE_TOP:
		shift[axis] = amount
	# Each change: [object, property, old value, new value].
	var changes: Array = []
	var layout := terrain as TerrainLayout
	if layout and layout.layout != "":
		changes.append([layout, &"layout", layout.layout, _resized_layout(layout.layout, side, amount)])
		if size_tiles != Vector2i.ZERO:
			changes.append([self, &"size_tiles", size_tiles, new_size])
	else:
		changes.append([self, &"size_tiles", size_tiles, new_size])
		if shift != Vector2i.ZERO:
			changes.append([terrain, &"tile_map_data", terrain.tile_map_data, _shifted_tiles(shift)])
	if shift != Vector2i.ZERO:
		var px := Vector2(shift * TILE)
		changes.append([self, &"world_origin", world_origin, world_origin - shift])
		for node in _placed_nodes():
			changes.append([node, &"position", node.position, node.position + px])
		if bounds.size != Vector2.ZERO:
			changes.append([self, &"bounds", bounds, Rect2(bounds.position + px, bounds.size)])
	var label := "%s %d %s" % ["Add" if amount > 0 else "Remove", absi(amount), "rows" if axis == 1 else "columns"]
	var moves := _neighbours_beyond(side, amount) if push_neighbours and Engine.is_editor_hint() else []
	_apply(changes, "Room size: " + label, moves)


## Put each part of the room on its color layer (see WorldColor): trees behind, decoration in
## front, the ground and everything on it, and the thorns.
func _paint_color_layers() -> void:
	var parts := {
		^"Props": WorldColor.Layer.TREES, ^"Decor": WorldColor.Layer.DECOR,
		^"Leaves": WorldColor.Layer.DECOR, ^"Entities": WorldColor.Layer.GROUND,
	}
	for path: NodePath in parts:
		var part := get_node_or_null(path)
		if part:
			WorldColor.paint(part, parts[path])
	WorldColor.paint(terrain, WorldColor.Layer.GROUND)
	if terrain is TerrainLayout and (terrain as TerrainLayout).hazards:
		(terrain as TerrainLayout).hazards.material = WorldColor.material(WorldColor.Layer.HAZARDS)
	# Thorns objects (wherever they sit in the room).
	for hazard in get_tree().get_nodes_in_group(&"hazards"):
		if is_ancestor_of(hazard):
			WorldColor.paint(hazard, WorldColor.Layer.HAZARDS)


# The room's area in room pixels: a Room Size where set, otherwise the terrain's.
func _terrain_bounds() -> Rect2:
	var tile_size := Vector2(terrain.tile_set.tile_size)
	var area: Rect2
	# A room painted by hand (empty layout) is measured by its painted tiles instead.
	if terrain is TerrainLayout and (terrain as TerrainLayout).layout != "":
		area = Rect2(Vector2.ZERO, Vector2((terrain as TerrainLayout).layout_size()) * tile_size)
	else:
		var used := terrain.get_used_rect()
		area = Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)
	for axis in 2:
		if size_tiles[axis] > 0:
			area.position[axis] = 0.0
			area.size[axis] = size_tiles[axis] * tile_size[axis]
	return area


# --- Resizing -------------------------------------------------------------------------------

func _add_top() -> void:
	resize_side(SIDE_TOP, resize_step)


func _remove_top() -> void:
	resize_side(SIDE_TOP, -resize_step)


func _add_bottom() -> void:
	resize_side(SIDE_BOTTOM, resize_step)


func _remove_bottom() -> void:
	resize_side(SIDE_BOTTOM, -resize_step)


func _add_left() -> void:
	resize_side(SIDE_LEFT, resize_step)


func _remove_left() -> void:
	resize_side(SIDE_LEFT, -resize_step)


func _add_right() -> void:
	resize_side(SIDE_RIGHT, resize_step)


func _remove_right() -> void:
	resize_side(SIDE_RIGHT, -resize_step)


# The layout text with rows or columns of empty tiles added (or taken off) on one side.
func _resized_layout(text: String, side: Side, amount: int) -> String:
	var rows := TerrainLayout.rows_of(text)
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	for i in rows.size():
		rows[i] = rows[i].rpad(width, ".")
	match side:
		SIDE_TOP:
			if amount > 0:
				for i in amount:
					rows.insert(0, ".".repeat(width))
			else:
				rows = rows.slice(-amount)
		SIDE_BOTTOM:
			if amount > 0:
				for i in amount:
					rows.append(".".repeat(width))
			else:
				rows = rows.slice(0, rows.size() + amount)
		SIDE_LEFT:
			for i in rows.size():
				rows[i] = ".".repeat(amount) + rows[i] if amount > 0 else rows[i].substr(-amount)
		SIDE_RIGHT:
			for i in rows.size():
				rows[i] = rows[i] + ".".repeat(amount) if amount > 0 else rows[i].left(width + amount)
	return "\n".join(rows)


# The painted tiles moved by `shift` tiles, as TileMapLayer data. Shrinking (a negative shift)
# drops the tiles in the rows or columns taken off.
func _shifted_tiles(shift: Vector2i) -> PackedByteArray:
	var old := terrain.tile_map_data
	var cells := []
	for cell in terrain.get_used_cells():
		var removed := (shift.x < 0 and cell.x >= 0 and cell.x < -shift.x) \
				or (shift.y < 0 and cell.y >= 0 and cell.y < -shift.y)
		if not removed:
			cells.append([cell + shift, terrain.get_cell_source_id(cell), terrain.get_cell_atlas_coords(cell),
					terrain.get_cell_alternative_tile(cell)])
	terrain.clear()
	for cell: Array in cells:
		terrain.set_cell(cell[0], cell[1], cell[2], cell[3])
	var shifted := terrain.tile_map_data
	terrain.tile_map_data = old
	return shifted


# Everything placed in the room: its own children (but the terrain) and the children of Props,
# Decor, Hazards, Entities, Spawns, and Signs.
func _placed_nodes() -> Array[CanvasItem]:
	var placed: Array[CanvasItem] = []
	for child in get_children():
		if child == terrain or not (child is Node2D or child is Control):
			continue
		if child.name in CONTAINERS:
			for item in child.get_children():
				if item is Node2D or item is Control:
					placed.append(item)
		else:
			placed.append(child)
	return placed


# The rooms entirely beyond the edge on `side`, and how far they move with it: [[scene path,
# shift in tiles], ...]. Read from the saved rooms; Spirit Rooms stand apart and never move.
func _neighbours_beyond(side: Side, amount: int) -> Array:
	var area := _terrain_bounds()
	var mine := Rect2(Vector2(world_origin * TILE) + area.position, area.size)
	var shift := Vector2i.ZERO
	match side:
		SIDE_LEFT: shift.x = -amount
		SIDE_RIGHT: shift.x = amount
		SIDE_TOP: shift.y = -amount
		SIDE_BOTTOM: shift.y = amount
	WorldMap.reload()
	var moves := []
	for id: StringName in WorldMap.rooms():
		var path := WorldMap.scene_of(id)
		if path == scene_file_path or WorldMap.is_spirit_room(id):
			continue
		var rect := WorldMap.rect_px(id)
		var beyond: bool
		match side:
			SIDE_LEFT: beyond = rect.end.x <= mine.position.x + 0.5
			SIDE_RIGHT: beyond = rect.position.x >= mine.end.x - 0.5
			SIDE_TOP: beyond = rect.end.y <= mine.position.y + 0.5
			SIDE_BOTTOM: beyond = rect.position.y >= mine.end.y - 0.5
		if beyond:
			moves.append([path, shift])
	return moves


# Move other rooms by rewriting the World Origin line in their scene files (`direction` 1 does
# `moves`, -1 undoes them). A room open in the editor asks to reload.
func _move_rooms(moves: Array, direction: int) -> void:
	var origin_line := RegEx.create_from_string("(?m)^world_origin = Vector2i\\((-?\\d+), (-?\\d+)\\)$")
	var names := PackedStringArray()
	for move: Array in moves:
		var path: String = move[0]
		var shift: Vector2i = move[1] * direction
		var text := FileAccess.get_file_as_string(path)
		var found := origin_line.search(text)
		var origin := Vector2i(int(found.get_string(1)), int(found.get_string(2))) if found else Vector2i.ZERO
		var line := "world_origin = Vector2i(%d, %d)" % [origin.x + shift.x, origin.y + shift.y]
		if found:
			text = text.substr(0, found.get_start()) + line + text.substr(found.get_end())
		else:
			# No World Origin saved (it's 0, 0): add one to the root node, the first node.
			var root := text.find("\n", text.find("[node "))
			text = text.substr(0, root + 1) + line + "\n" + text.substr(root + 1)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		names.append(path.get_file().get_basename())
		if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
			Engine.get_singleton(&"EditorInterface").call(&"get_resource_filesystem").call(&"update_file", path)
	if not names.is_empty():
		print("Room size: moved %d rooms with it (%s)." % [names.size(), ", ".join(names)])
	_read_neighbours()


# Make the changes: in the editor as one undoable step, otherwise (tests) directly. `moves`
# are other rooms to move along (see _neighbours_beyond).
func _apply(changes: Array, action: String, moves := []) -> void:
	var undo: Object = null
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		undo = Engine.get_singleton(&"EditorInterface").call(&"get_editor_undo_redo")
	if undo:
		undo.call(&"create_action", action)
		for change: Array in changes:
			undo.call(&"add_do_property", change[0], change[1], change[3])
			undo.call(&"add_undo_property", change[0], change[1], change[2])
		if not moves.is_empty():
			undo.call(&"add_do_method", self, &"_move_rooms", moves, 1)
			undo.call(&"add_undo_method", self, &"_move_rooms", moves, -1)
		undo.call(&"add_do_method", self, &"_redraw_outline")
		undo.call(&"add_undo_method", self, &"_redraw_outline")
		undo.call(&"commit_action")
	else:
		for change: Array in changes:
			(change[0] as Object).set(change[1], change[3])
		if not moves.is_empty():
			_move_rooms(moves, 1)


# --- Editor outline -------------------------------------------------------------------------

func _setup_editor() -> void:
	if get_tree().edited_scene_root != self:
		return
	_outline = Node2D.new()
	_outline.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	add_child(_outline, false, Node.INTERNAL_MODE_BACK)
	_outline.draw.connect(_draw_outline)
	_read_neighbours()


# The other rooms' areas from their saved scenes (Refresh neighbours rereads them).
func _read_neighbours() -> void:
	_neighbours.clear()
	if not Engine.is_editor_hint() or spirit_room:
		_redraw_outline()
		return
	WorldMap.reload()
	for id: StringName in WorldMap.rooms():
		if WorldMap.scene_of(id) != scene_file_path and not WorldMap.is_spirit_room(id):
			_neighbours.append([id, WorldMap.rect_px(id)])
	_redraw_outline()


func _redraw_outline() -> void:
	if _outline:
		_outline.queue_redraw()


func _draw_outline() -> void:
	var area := _terrain_bounds()
	_shown_area = area
	var origin := Vector2(world_origin * TILE)
	var mine := Rect2(origin + area.position, area.size)
	var font := ThemeDB.fallback_font
	var overlapping := false
	for neighbour: Array in _neighbours:
		var rect: Rect2 = neighbour[1]
		var local := Rect2(rect.position - origin, rect.size)
		var hit := rect.intersects(mine)
		overlapping = overlapping or hit
		if hit:
			var shared := rect.intersection(mine)
			_outline.draw_rect(Rect2(shared.position - origin, shared.size), Color(OVERLAP, 0.25))
		_outline.draw_rect(local, OVERLAP if hit else NEIGHBOUR, false, 2.0 if hit else 1.0)
		_outline.draw_string(font, local.position + Vector2(6, 18), String(neighbour[0]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, OVERLAP if hit else NEIGHBOUR)
	var color := OVERLAP if overlapping else OUTLINE
	_outline.draw_rect(area, color, false, 3.0)
	var size := Vector2i((area.size / TILE).round())
	var label := "%s   %d x %d tiles" % [name, size.x, size.y]
	if overlapping:
		label += "   overlaps another room"
	_outline.draw_string(font, area.position + Vector2(6, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
