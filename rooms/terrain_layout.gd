@tool
class_name TerrainLayout
extends TileMapLayer
## Paints a room's terrain from a text layout, one character per tile, choosing each tile's
## edges from its neighbors. Runs in the editor too, so changing the text repaints the room.
## Leave `layout` empty to paint tiles by hand with the editor's terrain tools instead.
##
## Legend: # grass ground   % rock   = plank (one-way)   ^ v > < thorns pointing that way
##         . empty (anything else is empty too)
##
## Thorns go on their own layer (`hazards`, a child drawn in front of the room's bushes and
## objects) so nothing hides them. Grass tiles have their ground (the soil) on the grid, so the
## hero's feet meet the soil; the grass blades above it go in the empty cell above, on another
## layer (`grass_tops`) that's drawn with the terrain, behind the hero and the decoration. Rooms use Thorns objects (entities/thorns.tscn) instead, which
## can be moved, stretched, and tinted in the editor; the characters still work.

# Atlas layout of art/tilesets/forest.png (see tools/build_art.py).
const GRASS_ROW := 0
const ROCK_ROW := 1
const VARIANT_ROW := 2
const MISC_ROW := 3
## Grass blades over top-edge grass: by edge mask, and for the top-surface variants.
const GRASS_TOP_ROW := 4
const GRASS_TOP_VARIANT_ROW := 5
const PLANK_LEFT := Vector2i(0, MISC_ROW)
const PLANK_MID := Vector2i(1, MISC_ROW)
const PLANK_RIGHT := Vector2i(2, MISC_ROW)
const PLANK_SINGLE := Vector2i(3, MISC_ROW)
const THORNS := {
	"^": Vector2i(4, MISC_ROW), "v": Vector2i(5, MISC_ROW),
	">": Vector2i(6, MISC_ROW), "<": Vector2i(7, MISC_ROW),
}
const SOLID := ["#", "%"]
# Edge bits: set when that neighbor isn't solid.
const UP := 1
const DOWN := 2
const LEFT := 4
const RIGHT := 8
## Thorns draw at this z, in front of the room's decoration (1) and objects (2).
const HAZARD_Z := 3

@export_multiline var layout := "":
	set(value):
		layout = value
		if is_inside_tree():
			rebuild()


## The thorns, on their own layer in front of everything else in the room.
var hazards: TileMapLayer
## The grass blades over top-edge grass, in the cells above it.
var grass_tops: TileMapLayer


func _ready() -> void:
	hazards = TileMapLayer.new()
	hazards.name = "Hazards"
	hazards.tile_set = tile_set
	hazards.z_index = HAZARD_Z
	# Internal: built from the layout every time, never saved into the scene.
	add_child(hazards, false, Node.INTERNAL_MODE_BACK)
	grass_tops = TileMapLayer.new()
	grass_tops.name = "GrassTops"
	grass_tops.tile_set = tile_set
	# Same color layer as the ground (Room paints the terrain).
	grass_tops.use_parent_material = true
	add_child(grass_tops, false, Node.INTERNAL_MODE_BACK)
	rebuild()


## The layout's size in tiles: the longest row by the number of rows.
func layout_size() -> Vector2i:
	var rows := _rows()
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	return Vector2i(width, rows.size())


func rebuild() -> void:
	var rows := _rows()
	if rows.is_empty() or hazards == null:
		return
	clear()
	hazards.clear()
	grass_tops.clear()
	for y in rows.size():
		for x in rows[y].length():
			var symbol := rows[y][x]
			var cell := Vector2i(x, y)
			if symbol in SOLID:
				var tile := _terrain_tile(rows, x, y, symbol)
				set_cell(cell, 0, tile)
				var blades := _grass_top(tile)
				if blades.x >= 0 and y > 0:
					grass_tops.set_cell(cell + Vector2i.UP, 0, blades)
			elif symbol == "=":
				var left := _at(rows, x - 1, y) == "="
				var right := _at(rows, x + 1, y) == "="
				var tile := PLANK_SINGLE
				if left and right:
					tile = PLANK_MID
				elif right:
					tile = PLANK_LEFT
				elif left:
					tile = PLANK_RIGHT
				set_cell(cell, 0, tile)
			elif THORNS.has(symbol):
				hazards.set_cell(cell, 0, THORNS[symbol])


func _terrain_tile(rows: PackedStringArray, x: int, y: int, symbol: String) -> Vector2i:
	# Beyond the room's edge counts as solid, so ground runs on seamlessly into the next room.
	var mask := 0
	if not _at(rows, x, y - 1) in SOLID and y > 0:
		mask |= UP
	if not _at(rows, x, y + 1) in SOLID and y + 1 < rows.size():
		mask |= DOWN
	if not _at(rows, x - 1, y) in SOLID and x > 0:
		mask |= LEFT
	if not _at(rows, x + 1, y) in SOLID and x + 1 < rows[y].length():
		mask |= RIGHT
	var terrain := 0 if symbol == "#" else 1
	# Solid insides and top surfaces have two extra variants; pick one by position so the
	# same layout always paints the same way.
	if mask == 0 or mask == UP:
		var pick := absi((x * 73856093) ^ (y * 19349663)) % 100
		if pick < 35:
			return Vector2i(terrain * 4 + (0 if mask == 0 else 2) + (pick % 2), VARIANT_ROW)
	return Vector2i(mask, GRASS_ROW if terrain == 0 else ROCK_ROW)


# The grass blades to draw above an atlas tile, or (-1, -1) for none (not a top-edge grass tile).
func _grass_top(tile: Vector2i) -> Vector2i:
	if tile.y == GRASS_ROW and tile.x & UP:
		return Vector2i(tile.x, GRASS_TOP_ROW)
	if tile.y == VARIANT_ROW and tile.x in [2, 3]:
		return Vector2i(tile.x, GRASS_TOP_VARIANT_ROW)
	return Vector2i(-1, -1)


func _rows() -> PackedStringArray:
	return rows_of(layout)


## A layout's rows, without blank lines at the start and end (so the text can start on its own
## line). Also used by WorldMap to check a room's terrain without loading it.
static func rows_of(text: String) -> PackedStringArray:
	var rows := text.split("\n")
	# Drop blank lines at the start and end so the text can start on its own line.
	while not rows.is_empty() and rows[0].strip_edges().is_empty():
		rows.remove_at(0)
	while not rows.is_empty() and rows[rows.size() - 1].strip_edges().is_empty():
		rows.remove_at(rows.size() - 1)
	return rows


func _at(rows: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return ""
	return rows[y][x]
