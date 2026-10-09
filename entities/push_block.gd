class_name PushBlock
extends CharacterBody2D
## A block the hero can push and pull while holding Grab. Falls when nothing holds it up,
## and goes back to its start when the room resets. Origin at the bottom center.

@export var gravity := 990.0
@export var max_fall_speed := 480.0
@export var color := Color(0.55, 0.5, 0.45)
## Art for the block: a 16×16 region of `texture`. Left empty, it draws a plain box in `color`.
@export var texture: Texture2D
@export var texture_region := Rect2(0, 0, 16, 16)

var _start := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"room_reset")
	_start = global_position


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()


## Slide sideways by up to `dx` px. Returns how far it actually moved.
func push(dx: float) -> float:
	if not is_on_floor() or dx == 0.0:
		return 0.0
	var before := global_position.x
	move_and_collide(Vector2(dx, 0.0))
	return global_position.x - before


# Redraw on whole game pixels as it moves (see Player._process).
func _process(_delta: float) -> void:
	queue_redraw()


func reset_to_start() -> void:
	global_position = _start
	velocity = Vector2.ZERO


func _draw() -> void:
	draw_set_transform(global_position.round() - global_position)
	if texture:
		draw_texture_rect_region(texture, Rect2(-8, -16, 16, 16), texture_region)
		return
	draw_rect(Rect2(-8, -16, 16, 16), color.darkened(0.4))
	draw_rect(Rect2(-7, -15, 14, 14), color)
	draw_rect(Rect2(-5, -13, 10, 10), color.darkened(0.15), false, 1.0)
