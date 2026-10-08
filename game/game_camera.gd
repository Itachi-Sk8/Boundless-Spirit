class_name GameCamera
extends Camera2D
## Follows the hero like Super Meat Boy's camera: smooth, kept inside the room, looking ahead
## in the direction of movement, with a vertical dead zone so jumps don't shake the view.
## Crouching still peeks down.

## How fast the camera catches up, per second. Higher is snappier.
@export var smoothing := 8.0
## How far ahead of the hero the camera looks, in px.
@export var look_ahead := 40.0
## How fast the look-ahead swings to a new direction, in px/s.
@export var look_ahead_speed := 120.0
## The hero can rise this far above its last footing before the camera follows, in px.
@export var dead_zone_up := 48.0
## ...and fall this far below it, in px. Small, so landings below stay in view.
@export var dead_zone_down := 8.0
## The camera centers on this point above the hero's feet, in px.
@export var focus_height := 24.0
## How far down a crouch peek looks, in px.
@export var peek_distance := 64.0

var target: Player
var bounds := Rect2()

var _anchor_y := 0.0
var _look := 0.0
var _peek := 0.0
var _position := Vector2.ZERO


func _ready() -> void:
	# Run after the hero has moved this frame.
	process_physics_priority = 10


func setup(new_target: Player, room_bounds: Rect2) -> void:
	target = new_target
	bounds = room_bounds
	snap_to_target()


## Jump straight to the hero, e.g. after a respawn.
func snap_to_target() -> void:
	var focus := _focus()
	_anchor_y = focus.y
	_look = 0.0
	_peek = 0.0
	_position = _clamp_to_room(focus)
	global_position = _position.round()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var focus := _focus()
	if _is_grounded():
		_anchor_y = focus.y
	else:
		_anchor_y = clampf(_anchor_y, focus.y - dead_zone_down, focus.y + dead_zone_up)
	if absf(target.velocity.x) > 1.0:
		_look = move_toward(_look, signf(target.velocity.x) * look_ahead, look_ahead_speed * delta)
	_peek = move_toward(_peek, peek_distance if target.peeking else 0.0, peek_distance * 4.0 * delta)
	var desired := Vector2(focus.x + _look, _anchor_y + _peek)
	_position = _clamp_to_room(_position.lerp(desired, 1.0 - exp(-smoothing * delta)))
	global_position = _position.round()


func _focus() -> Vector2:
	return target.camera_focus() - Vector2(0.0, focus_height)


func _is_grounded() -> bool:
	return target.is_on_floor() or is_instance_valid(target.spirit) \
			or target.state_name in [&"climb", &"ledge_grab", &"wall_slide"]


func _clamp_to_room(point: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return point
	var half := get_viewport_rect().size / zoom / 2.0
	var clamped := point
	for axis in 2:
		if bounds.size[axis] <= half[axis] * 2.0:
			clamped[axis] = bounds.get_center()[axis]
		else:
			clamped[axis] = clampf(point[axis], bounds.position[axis] + half[axis],
					bounds.end[axis] - half[axis])
	return clamped
