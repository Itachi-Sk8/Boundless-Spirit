@tool
class_name Water
extends Area2D
## Deep, fast water (river rapids): touching it is death, like thorns. The top row of tiles is
## the surface. Size it in tiles; origin at its top-left corner. Drawn on the hazards color
## layer, so it keeps some color in the grey world.

const TILE := 16
const ART := preload("res://art/objects/water.png")
const FRAMES := 4
const HAZARD_LAYER := 1 << 2
## The deadly part starts this far below the top of the surface tile, in px (under the foam).
const SURFACE_DROP := 6.0

## Size in tiles.
@export var size_tiles := Vector2i(6, 2):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
## Animation frames per second: faster reads as rapids.
@export var flow_speed := 8.0
## Which way the surface flows: 1 right, -1 left.
@export_enum("Left:-1", "Right:1") var flow_direction := 1

var _shape := RectangleShape2D.new()
var _owner_id := -1


func _ready() -> void:
	collision_layer = HAZARD_LAYER
	collision_mask = 0
	monitoring = false
	z_index = Thorns.Z
	add_to_group(&"hazards")
	_rebuild()


func _process(_delta: float) -> void:
	queue_redraw()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	var size := Vector2(size_tiles * TILE) - Vector2(0, SURFACE_DROP)
	_shape.size = size
	shape_owner_set_transform(_owner_id, Transform2D(0.0, Vector2(size.x / 2.0, SURFACE_DROP + size.y / 2.0)))
	queue_redraw()


func _draw() -> void:
	var frame := int(Time.get_ticks_msec() / 1000.0 * flow_speed)
	for y in size_tiles.y:
		for x in size_tiles.x:
			var f := posmod(frame * -flow_direction, FRAMES)
			draw_texture_rect_region(ART, Rect2(x * TILE, y * TILE, TILE, TILE),
					Rect2(f * TILE, (0 if y == 0 else 1) * TILE, TILE, TILE))
