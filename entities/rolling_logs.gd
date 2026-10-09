@tool
class_name RollingLogs
extends Node2D
## Releases logs that roll along the ground in a fixed rhythm: each rolls at `speed`, drops off
## ledges, and smashes against the first wall it meets. Touching one is death. Place it where
## the logs should appear (they rest on the ground below it); the arrow in the editor shows
## which way they roll. Logs clear and the rhythm restarts when the room resets.

const LOG_ART := preload("res://art/objects/log_end.png")
const RADIUS := 11.0
const WORLD_LAYER := 1
const PUSH_BLOCK_LAYER := 1 << 4
const HAZARD_LAYER := 1 << 2

## Which way they roll: 1 right, -1 left.
@export_enum("Left:-1", "Right:1") var direction := 1:
	set(value):
		direction = value
		queue_redraw()
## Rolling speed, in px/s (running is 120).
@export var speed := 110.0
## Seconds between logs.
@export var interval := 2.5
## Seconds before the first log after entering the room (or a reset).
@export var first_delay := 0.5
@export var gravity := 900.0

var _timer := 0.0
# Each log: {"node": the log, "velocity": Vector2}
var _logs: Array[Dictionary] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"room_reset")
	add_to_group(&"hazards")
	_timer = first_delay


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer += interval
		_release()
	for entry in _logs.duplicate():
		_roll(entry, delta)


func reset_to_start() -> void:
	for entry in _logs:
		(entry["node"] as Node).queue_free()
	_logs.clear()
	_timer = first_delay


func _release() -> void:
	var roller := Area2D.new()
	roller.use_parent_material = true
	roller.collision_layer = HAZARD_LAYER
	roller.collision_mask = 0
	roller.monitoring = false
	roller.z_index = Thorns.Z
	roller.add_to_group(&"hazards")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 2.0
	shape.shape = circle
	roller.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = LOG_ART
	sprite.use_parent_material = true
	roller.add_child(sprite)
	roller.position = Vector2(0, -RADIUS)
	add_child(roller)
	_logs.append({"node": roller, "velocity": Vector2(direction * speed, 0)})


func _roll(entry: Dictionary, delta: float) -> void:
	var roller: Area2D = entry["node"]
	var velocity: Vector2 = entry["velocity"]
	velocity.y = minf(velocity.y + gravity * delta, 600.0)
	var space := get_world_2d().direct_space_state
	var center := roller.global_position
	# Ground: stop falling on whatever is below.
	var down := PhysicsRayQueryParameters2D.create(center, center + Vector2(0, RADIUS + velocity.y * delta + 1.0),
			WORLD_LAYER | PUSH_BLOCK_LAYER)
	var floor_hit := space.intersect_ray(down)
	if not floor_hit.is_empty() and velocity.y >= 0.0:
		velocity.y = 0.0
		center.y = floor_hit["position"].y - RADIUS
	# Wall ahead: smash.
	var ahead := PhysicsRayQueryParameters2D.create(center, center + Vector2(signf(velocity.x) * (RADIUS + 1.0) + velocity.x * delta, 0),
			WORLD_LAYER | PUSH_BLOCK_LAYER)
	if not space.intersect_ray(ahead).is_empty() or _out_of_room(center):
		_smash(entry)
		return
	center += velocity * delta
	roller.global_position = center
	(roller.get_child(1) as Sprite2D).rotation += velocity.x * delta / RADIUS
	entry["velocity"] = velocity


func _smash(entry: Dictionary) -> void:
	var roller: Node2D = entry["node"]
	_logs.erase(entry)
	Sfx.play(&"shatter", -6.0)
	roller.queue_free()


func _out_of_room(point: Vector2) -> bool:
	if Main.instance == null or Main.instance.room == null:
		return false
	return not Main.instance.room.world_bounds().grow(32.0).has_point(point)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_texture(LOG_ART, Vector2(-12, -24))
		var tip := Vector2(direction * 28, -12)
		draw_line(Vector2(0, -12), tip, Color(1, 0.4, 0.3, 0.8), 2.0)
		draw_line(tip, tip + Vector2(-direction * 5, -4), Color(1, 0.4, 0.3, 0.8), 2.0)
		draw_line(tip, tip + Vector2(-direction * 5, 4), Color(1, 0.4, 0.3, 0.8), 2.0)
