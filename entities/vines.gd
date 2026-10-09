@tool
class_name Vines
extends Area2D
## Hanging vines the hero can climb once purple returns (hold Grab). Stretch with `length`.
## Origin at the top-left of the top tile, so with grid snap at 16 px it hangs from a ceiling
## or ledge edge.

const TILE := 16
const ART := preload("res://art/objects/vine.png")
const VINE_LAYER := 1 << 5
## The climbable strip down the middle of each tile, in px.
const GRAB_WIDTH := 10.0

## How many tiles long.
@export_range(1, 64, 1, "or_greater") var length := 3:
	set(value):
		length = maxi(1, value)
		_rebuild()

var _shape := RectangleShape2D.new()
var _owner_id := -1


func _ready() -> void:
	collision_layer = VINE_LAYER
	collision_mask = 0
	monitoring = false
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	_shape.size = Vector2(GRAB_WIDTH, length * TILE)
	shape_owner_set_transform(_owner_id, Transform2D(0.0, Vector2(TILE / 2.0, length * TILE / 2.0)))
	queue_redraw()


func _draw() -> void:
	for i in length:
		# Top piece, middle pieces, then the tip (a single tile uses the top piece).
		var piece := 0 if i == 0 else (2 if i == length - 1 else 1)
		draw_texture_rect_region(ART, Rect2(0, i * TILE, TILE, TILE), Rect2(0, piece * TILE, TILE, TILE))
