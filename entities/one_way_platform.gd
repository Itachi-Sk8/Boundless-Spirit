@tool
class_name OneWayPlatform
extends StaticBody2D
## A wooden plank platform: the hero jumps up through it and lands on top. The same planks as
## `=` in a terrain layout, but placeable anywhere. Origin at its top-left corner.

const TILE := 16
const ATLAS := preload("res://art/tilesets/forest.png")
const MISC_ROW := 3
const LEFT_END := 0
const MIDDLE := 1
const RIGHT_END := 2
const SINGLE := 3
## The solid strip along the top, in px.
const THICKNESS := 6.0

## Width in tiles.
@export_range(1, 32, 1, "or_greater") var width_tiles := 3:
	set(value):
		width_tiles = maxi(1, value)
		_rebuild()

var _shape := RectangleShape2D.new()
var _owner_id := -1


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
		shape_owner_set_one_way_collision(_owner_id, true)
		# As a CollisionShape2D does by default; with no margin, nothing lands on it.
		shape_owner_set_one_way_collision_margin(_owner_id, 1.0)
	_shape.size = Vector2(width_tiles * TILE, THICKNESS)
	shape_owner_set_transform(_owner_id, Transform2D(0.0, Vector2(width_tiles * TILE / 2.0, THICKNESS / 2.0)))
	queue_redraw()


func _draw() -> void:
	for i in width_tiles:
		var tile := SINGLE
		if width_tiles > 1:
			tile = LEFT_END if i == 0 else (RIGHT_END if i == width_tiles - 1 else MIDDLE)
		draw_texture_rect_region(ATLAS, Rect2(i * TILE, 0, TILE, TILE), Rect2(tile * TILE, MISC_ROW * TILE, TILE, TILE))
