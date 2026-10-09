@tool
class_name WindGust
extends Area2D
## A stretch of wind that pushes the hero while inside it: sideways winds carry the hero along
## (it can still walk against them, slowly), updrafts lift, downdrafts press down. It can blow
## in a fixed rhythm (`on_time` and `off_time`). Streaks show its direction and strength.
## Size it in tiles; origin at its top-left corner.

const TILE := 16

enum Direction { UP, DOWN, LEFT, RIGHT }

## Size in tiles.
@export var size_tiles := Vector2i(6, 3):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
@export var direction := Direction.RIGHT:
	set(value):
		direction = value
		_rebuild()
## Sideways: how fast it carries the hero, in px/s (running is 120). Up or down: how hard it
## pushes, in px/s² (gravity is about 1100, so an updraft needs more than that to lift).
@export var strength := 70.0
## Seconds it blows, then seconds it rests. An off_time of 0 blows all the time.
@export var on_time := 2.0
@export var off_time := 0.0
## Shifts where in the rhythm it starts, in seconds, so gusts side by side can take turns.
@export var phase := 0.0
@export var streak_color := Color(1, 1, 1, 0.55)

var blowing := true

var _shape := RectangleShape2D.new()
var _owner_id := -1
var _time := 0.0

@onready var streaks: CPUParticles2D = $Streaks


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	# Push before the hero moves this frame.
	process_physics_priority = -1
	_rebuild()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var now := off_time <= 0.0 or fmod(_time + phase, on_time + off_time) < on_time
	if now != blowing:
		blowing = now
		streaks.emitting = blowing
	if not blowing:
		return
	var rect := Rect2(global_position, Vector2(size_tiles * TILE))
	for body in get_overlapping_bodies():
		if Touch.hero_in(body, rect, 0.0):
			(body as Player).add_push(force())


## The push it gives the hero each frame while blowing (see Player.add_push).
func force() -> Vector2:
	match direction:
		Direction.UP:
			return Vector2(0, -strength)
		Direction.DOWN:
			return Vector2(0, strength)
		Direction.LEFT:
			return Vector2(-strength, 0)
	return Vector2(strength, 0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	var size := Vector2(size_tiles * TILE)
	_shape.size = size
	shape_owner_set_transform(_owner_id, Transform2D(0.0, size / 2.0))
	if not is_node_ready():
		return
	# Streaks start along the upwind edge and blow across.
	var along := Vector2.RIGHT
	match direction:
		Direction.UP:
			along = Vector2.UP
		Direction.DOWN:
			along = Vector2.DOWN
		Direction.LEFT:
			along = Vector2.LEFT
	var length := size.x if along.x != 0.0 else size.y
	var speed := 60.0 + absf(strength) * (0.6 if along.x != 0.0 else 0.08)
	streaks.position = size / 2.0 - along * length / 2.0
	streaks.emission_rect_extents = Vector2(1, size.y / 2.0) if along.x != 0.0 else Vector2(size.x / 2.0, 1)
	streaks.direction = along
	streaks.initial_velocity_min = speed
	streaks.initial_velocity_max = speed * 1.2
	streaks.lifetime = length / speed
	streaks.amount = maxi(4, int(size.x * size.y / 160.0))
	streaks.color = streak_color
	streaks.scale_amount_min = 1.0
	streaks.scale_amount_max = 1.0
