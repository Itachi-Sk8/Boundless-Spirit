@tool
class_name SpiritBarrier
extends StaticBody2D
## A shimmering wall of spirit light: solid to the hero, but the spirit flies straight through
## it during Spirit Phase (blue), so the body can follow to the other side. Size it in tiles.
## Origin at its top-left corner. Always keeps its color in the grey world.

const TILE := 16
const ART := preload("res://art/objects/barrier.png")
const BARRIER_LAYER := 1 << 3

## Size in tiles.
@export var size_tiles := Vector2i(1, 4):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
## Tints the light.
@export var tint := Color(0.75, 0.9, 1.0):
	set(value):
		tint = value
		queue_redraw()
## How fast the light lines drift, in px/s.
@export var drift_speed := 6.0

var _shape := RectangleShape2D.new()
var _owner_id := -1


func _ready() -> void:
	collision_layer = BARRIER_LAYER
	collision_mask = 0
	add_to_group(&"full_color")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rebuild()


func _process(_delta: float) -> void:
	queue_redraw()


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
	var size := Vector2(size_tiles * TILE)
	var drift := floorf(Time.get_ticks_msec() / 1000.0 * drift_speed)
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 2.0)
	draw_texture_rect_region(ART, Rect2(Vector2.ZERO, size), Rect2(Vector2(0, -drift), size), Color(tint, pulse))
	var edge := Color(tint.lightened(0.4), 0.9 * pulse)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1, size.y)), edge)
	draw_rect(Rect2(Vector2(size.x - 1, 0), Vector2(1, size.y)), edge)
