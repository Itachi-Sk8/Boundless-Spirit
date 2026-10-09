@tool
class_name Waterfall
extends Area2D
## Falling water that presses the hero down while inside it: jumping up through it is hard,
## falling through it is fast. Not deadly. Size it in tiles; origin at its top-left corner.

const TILE := 16
const ART := preload("res://art/objects/waterfall.png")
const FRAMES := 4

## Size in tiles.
@export var size_tiles := Vector2i(2, 6):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
## How hard it presses down, in px/s² (gravity is about 1100).
@export var strength := 1400.0
## Animation frames per second.
@export var flow_speed := 12.0

var _shape := RectangleShape2D.new()
var _owner_id := -1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	process_physics_priority = -1
	_rebuild()


func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var rect := Rect2(global_position, Vector2(size_tiles * TILE))
	for body in get_overlapping_bodies():
		if Touch.hero_in(body, rect, 0.0):
			(body as Player).add_push(Vector2(0, strength))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	var size := Vector2(size_tiles * TILE)
	_shape.size = size
	shape_owner_set_transform(_owner_id, Transform2D(0.0, size / 2.0))
	queue_redraw()


func _draw() -> void:
	var frame := int(Time.get_ticks_msec() / 1000.0 * flow_speed) % FRAMES
	for y in size_tiles.y:
		for x in size_tiles.x:
			draw_texture_rect_region(ART, Rect2(x * TILE, y * TILE, TILE, TILE),
					Rect2(frame * TILE, 0, TILE, TILE))
