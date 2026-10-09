class_name SinkingLeaf
extends AnimatableBody2D
## A big leaf that sinks while the hero stands on it and floats back up when the hero leaves.
## A one-way platform: jump up through it, land on top. Origin at the center of its top edge.

## How fast it sinks under the hero, in px/s.
@export var sink_speed := 28.0
## How fast it floats back up, in px/s.
@export var rise_speed := 40.0
## How far it can sink before stopping, in px.
@export var max_sink := 96.0

var _start := Vector2.ZERO
var _bob := 0.0
# Set by reset_to_start(); the leaf goes back on its next physics update (see there).
var _reset_pending := false

@onready var sprite: Sprite2D = $Sprite
@onready var sensor: Area2D = $Sensor


func _ready() -> void:
	add_to_group(&"room_reset")
	_start = position


func _physics_process(delta: float) -> void:
	if _reset_pending:
		_reset_pending = false
		_teleport_to_start()
		return
	if not sync_to_physics:
		sync_to_physics = true # Back to smooth carrying, a frame after a teleport.
	var depth := position.y - _start.y
	if _hero_standing_on():
		depth = minf(depth + sink_speed * delta, max_sink)
	else:
		depth = maxf(depth - rise_speed * delta, 0.0)
	position.y = _start.y + depth
	# A gentle bob while floating untouched.
	_bob += delta
	sprite.position.y = roundf(sin(_bob * 2.0) * 0.6) if depth == 0.0 else 0.0


## Go back to the start on the next physics update. Not straight away: a reset comes mid-frame
## (from the hero's death), after this frame's sinking was already queued for the physics step,
## which would put the leaf right back.
func reset_to_start() -> void:
	_reset_pending = true


# Jump back without carrying anything along. With sync_to_physics on, a move is played out by
# the physics step as fast movement (flinging whoever lands on the leaf) and a direct move is
# overridden, so switch it off for this one frame: then setting the position teleports.
func _teleport_to_start() -> void:
	sync_to_physics = false
	position = _start


func _hero_standing_on() -> bool:
	var rect := Touch.shape_rect($Sensor/Shape)
	for body in sensor.get_overlapping_bodies():
		if Touch.hero_in(body, rect) and (body as Player).is_on_floor() and (body as Player).velocity.y >= 0.0:
			return true
	return false
