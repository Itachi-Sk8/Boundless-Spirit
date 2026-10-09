@tool
class_name ArchwayStone
extends Node2D
## A stone arch built from the forest's rock tiles: two pillars and a lintel around an opening,
## with edges picked from each tile's neighbors. Origin at its bottom-left corner. Its size is
## set by the SpiritArchway it belongs to; recolor it with Modulate.

const TILE := 16
const ATLAS := preload("res://art/tilesets/forest.png")

## The opening between the pillars, in tiles.
var opening_size := Vector2i(4, 6):
	set(value):
		opening_size = value.max(Vector2i.ONE)
		queue_redraw()
## Each pillar's width, in tiles.
var pillar_width := 2:
	set(value):
		pillar_width = maxi(1, value)
		queue_redraw()
## The lintel's height over the opening, in tiles.
var lintel_height := 2:
	set(value):
		lintel_height = maxi(1, value)
		queue_redraw()


## The whole arch's size in tiles.
func size_in_tiles() -> Vector2i:
	return Vector2i(opening_size.x + pillar_width * 2, opening_size.y + lintel_height)


## The opening in px from the origin.
func opening_rect() -> Rect2:
	var size := Vector2(opening_size * TILE)
	return Rect2(Vector2(pillar_width * TILE, -size.y), size)


func _draw() -> void:
	var tiles := size_in_tiles()
	var top := -tiles.y * TILE
	for y in tiles.y:
		for x in tiles.x:
			if not _solid(x, y):
				continue
			var mask := 0
			if not _solid(x, y - 1):
				mask |= TerrainLayout.UP
			if not _solid(x, y + 1):
				mask |= TerrainLayout.DOWN
			if not _solid(x - 1, y):
				mask |= TerrainLayout.LEFT
			if not _solid(x + 1, y):
				mask |= TerrainLayout.RIGHT
			var region := Rect2(mask * TILE, TerrainLayout.ROCK_ROW * TILE, TILE, TILE)
			draw_texture_rect_region(ATLAS, Rect2(x * TILE, top + y * TILE, TILE, TILE), region)


# Rows count from the top of the arch; everything outside it is empty.
func _solid(x: int, y: int) -> bool:
	var tiles := size_in_tiles()
	if x < 0 or y < 0 or x >= tiles.x or y >= tiles.y:
		return false
	return y < lintel_height or x < pillar_width or x >= tiles.x - pillar_width
