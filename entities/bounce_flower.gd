@tool
class_name BounceFlower
extends Area2D
## A springy flower: landing on it (or walking onto it) throws the hero high into the air and
## refills the dash and double jump. Origin at its bottom center, on the ground.

const ART := preload("res://art/objects/flower.png")
const SIZE := 16
## Frames in the art: resting, squashed, springing.
const REST := 0
const SQUASH := 1
const SPRING := 2

## Launch speed, in px/s. A normal jump is about 390.
@export var launch_speed := 560.0
## Refill the dash and double jump on bounce.
@export var refills := true
## Seconds before it can bounce again.
@export var cooldown := 0.25

var _frame := REST
var _cooldown_left := 0.0
var _anim_left := 0.0

@onready var shape_node: CollisionShape2D = $Shape


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _anim_left > 0.0:
		_anim_left -= delta
		if _anim_left <= 0.0:
			_set_frame(REST)
	if _cooldown_left > 0.0:
		return
	var rect := Touch.shape_rect(shape_node)
	for body in get_overlapping_bodies():
		var hero := body as Player
		# Only from above: falling, or walking on the ground it grows from (feet no lower than
		# its base), never rising up through it.
		if hero and Touch.hero_in(hero, rect) and hero.velocity.y >= 0.0 and not hero.frozen \
				and hero.state_name != &"dead" and hero.global_position.y <= global_position.y + 0.5:
			hero.global_position.y = global_position.y - 8.0
			hero.launch(launch_speed, refills)
			Sfx.play(&"bounce")
			_cooldown_left = cooldown
			_set_frame(SQUASH)
			await get_tree().create_timer(0.06, false).timeout
			_set_frame(SPRING)
			_anim_left = 0.2
			return


func _set_frame(frame: int) -> void:
	_frame = frame
	queue_redraw()


func _draw() -> void:
	draw_texture_rect_region(ART, Rect2(-SIZE / 2.0, -SIZE, SIZE, SIZE), Rect2(_frame * SIZE, 0, SIZE, SIZE))
