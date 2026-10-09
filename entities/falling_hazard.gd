@tool
class_name FallingHazard
extends Node2D
## Something hanging overhead that drops when the hero passes beneath: a stalactite, or a log
## wedged in the branches. It shakes for a moment as a warning, falls, and shatters on whatever
## it hits; touching it while it hangs or falls is death. It grows back (or a new one lodges)
## after `regrow_time`, and is back in place when the room resets. The editor shows the strip
## below it that sets it off. Origin at the top center, where it hangs.

enum Phase { HANGING, SHAKING, FALLING, GONE }

const WORLD_LAYER := 1
const PUSH_BLOCK_LAYER := 1 << 4

## How far to each side of it the hero sets it off, in px.
@export var trigger_half_width := 12.0:
	set(value):
		trigger_half_width = value
		queue_redraw()
## How far below it the hero sets it off, in px (it also needs a clear view down).
@export var trigger_depth := 160.0:
	set(value):
		trigger_depth = value
		queue_redraw()
## Seconds it shakes before falling.
@export var shake_time := 0.35
@export var gravity := 900.0
@export var max_fall_speed := 420.0
## Seconds until it's back after shattering. 0: only when the room resets.
@export var regrow_time := 2.5

var phase := Phase.HANGING

var _speed := 0.0
var _timer := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var hurt: Area2D = $Hurt
@onready var hurt_shape: CollisionShape2D = $Hurt/Shape
@onready var debris: CPUParticles2D = $Debris


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"room_reset")
	add_to_group(&"hazards")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match phase:
		Phase.HANGING:
			if _hero_below():
				phase = Phase.SHAKING
				_timer = shake_time
				Sfx.play(&"crack", -4.0)
		Phase.SHAKING:
			_timer -= delta
			sprite.position.x = randi_range(-1, 1)
			if _timer <= 0.0:
				sprite.position.x = 0.0
				phase = Phase.FALLING
				_speed = 0.0
		Phase.FALLING:
			_speed = minf(_speed + gravity * delta, max_fall_speed)
			var step := _speed * delta
			var hit := _ground_below(step)
			if hit >= 0.0:
				sprite.position.y += hit
				hurt.position.y += hit
				_shatter()
			else:
				sprite.position.y += step
				hurt.position.y += step
				if Main.instance and sprite.global_position.y > Main.instance.room.world_bounds().end.y + 32.0:
					_shatter()
		Phase.GONE:
			if regrow_time > 0.0:
				_timer -= delta
				if _timer <= 0.0:
					reset_to_start()


func reset_to_start() -> void:
	phase = Phase.HANGING
	sprite.position = Vector2.ZERO
	sprite.show()
	hurt.position = Vector2.ZERO
	hurt.set_collision_layer_value(3, true)


func _shatter() -> void:
	phase = Phase.GONE
	_timer = regrow_time
	debris.position = Vector2(0, sprite.position.y + _art_height())
	debris.restart()
	sprite.hide()
	hurt.set_collision_layer_value(3, false)
	Sfx.play(&"shatter", -2.0)


func _art_height() -> float:
	return sprite.texture.get_height() if sprite.texture else 16.0


func _hero_below() -> bool:
	if Main.instance == null:
		return false
	var hero := Main.instance.player
	if hero.state_name == &"dead":
		return false
	var top := global_position + Vector2(-trigger_half_width, 0)
	if not Touch.hero_in(hero, Rect2(top, Vector2(trigger_half_width * 2.0, trigger_depth)), 0.0):
		return false
	# Only with a clear view down to the hero.
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, _art_height()),
			hero.global_position + Vector2(0, -8), WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# How far it can fall this frame before hitting the ground or a block: the distance, or -1.
func _ground_below(step: float) -> float:
	var rect := Touch.shape_rect(hurt_shape)
	var from := Vector2(rect.get_center().x, rect.end.y)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, step + 1.0), WORLD_LAYER | PUSH_BLOCK_LAYER)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return (hit["position"].y - from.y) if not hit.is_empty() else -1.0


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-trigger_half_width, 0, trigger_half_width * 2.0, trigger_depth), Color(1, 0.4, 0.3, 0.18))
