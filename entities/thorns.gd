@tool
class_name Thorns
extends Area2D
## A row of thorns that kill the hero on touch. Move it anywhere, stretch it with `length`
## (whole tiles) and `adjust_px` (a few pixels longer or shorter), point it any way with
## `direction`, and tint it. Origin at the top-left corner of its first
## tile, so with grid snap at 16 px it lines up with the terrain. Up and down rows run to the
## right; left and right rows run downward. Drawn in front of the room's decoration and
## objects, on the hazards color layer.

enum Direction { UP, DOWN, RIGHT, LEFT }

const TILE := 16
const ATLAS := preload("res://art/tilesets/forest.png")
# The thorn tiles in the forest atlas (row 3), by direction.
const ATLAS_COLUMN: Array[int] = [4, 5, 6, 7]
const ATLAS_ROW := 3
const HAZARD_LAYER := 1 << 2
## Drawn in front of the room's decoration (1) and objects (2).
const Z := 3
## Each tile's hurt area (px from the tile's top-left): the spikes, not the empty space beside
## and behind them.
const INSET := 2
const DEPTH := 9

## How many tiles long.
@export_range(1, 64, 1, "or_greater") var length := 1:
	set(value):
		length = maxi(1, value)
		_rebuild()
## Pixels added to the end of the row (or taken off, when negative), for lengths between whole
## tiles. The last tile's art is cut off where the row ends.
@export_range(-15, 15, 1) var adjust_px := 0:
	set(value):
		adjust_px = clampi(value, -15, 15)
		_rebuild()
@export var direction := Direction.UP:
	set(value):
		direction = value
		_rebuild()
## Multiplies the thorn art. White leaves it as drawn.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

var _shape := RectangleShape2D.new()
var _owner_id := -1


func _ready() -> void:
	collision_layer = HAZARD_LAYER
	collision_mask = 0
	monitoring = false
	z_index = Z
	add_to_group(&"hazards")
	if Engine.is_editor_hint():
		set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_refresh_soil()


## The row's length in px: whole tiles plus the adjustment.
func length_px() -> int:
	return maxi(INSET * 2 + 1, length * TILE + adjust_px)


## The hurt area in px from the origin.
func hurt_rect() -> Rect2:
	var span := length_px() - INSET * 2
	match direction:
		Direction.DOWN:
			return Rect2(INSET, 0, span, DEPTH)
		Direction.RIGHT:
			return Rect2(0, INSET, DEPTH, span)
		Direction.LEFT:
			return Rect2(TILE - DEPTH, INSET, DEPTH, span)
	return Rect2(INSET, TILE - DEPTH, span, DEPTH)


## The area the art covers in px from the origin.
func art_rect() -> Rect2:
	var along := Vector2(length_px(), TILE)
	return Rect2(Vector2.ZERO, along if _horizontal() else Vector2(along.y, along.x))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	var rect := hurt_rect()
	_shape.size = rect.size
	shape_owner_set_transform(_owner_id, Transform2D(0.0, rect.get_center()))
	queue_redraw()
	_refresh_soil()


# In the editor, keep the ground under the thorns bare dirt as they move or change (see
# TerrainLayout.refresh_bare_soil); in the game, the terrain does it once when the room loads.
func _refresh_soil() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var room := owner if owner else get_parent()
	var terrain: TerrainLayout = room.get_node_or_null(^"Terrain") as TerrainLayout if room else null
	if terrain:
		terrain.refresh_bare_soil()


func _draw() -> void:
	var region := Rect2(ATLAS_COLUMN[direction] * TILE, ATLAS_ROW * TILE, TILE, TILE)
	var along := Vector2(1, 0) if _horizontal() else Vector2(0, 1)
	var across := Vector2.ONE - along
	var total := length_px()
	var start := 0
	while start < total:
		# Full tiles, then the last one cut off where the row ends.
		var piece := mini(TILE, total - start)
		var size := along * piece + across * TILE
		draw_texture_rect_region(ATLAS, Rect2(along * start, size), Rect2(region.position, size), tint)
		start += TILE


func _horizontal() -> bool:
	return direction == Direction.UP or direction == Direction.DOWN
