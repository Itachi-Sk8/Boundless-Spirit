class_name ShortcutGate
extends StaticBody2D
## A one-way wooden gate: it opens only when the hero reaches it from the far side, then stays
## open for good (saved), turning that route into a shortcut. Origin at its bottom center.

## Name of the saved flag that records it open.
@export var flag := &"gate"
## The side it opens from: 1 for the right, -1 for the left.
@export var opens_from := 1

var is_open := false

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var trigger: Area2D = $Trigger


func _ready() -> void:
	trigger.position.x = opens_from * 14.0
	if GameState.has_flag(flag):
		_set_open(false)
	else:
		trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if is_open or not Touch.hero_in(body, Touch.shape_rect($Trigger/Shape)):
		return
	GameState.set_flag(flag)
	GameState.save_game()
	Sfx.play(&"gate")
	_set_open(true)


func _set_open(animate: bool) -> void:
	is_open = true
	shape.set_deferred(&"disabled", true)
	if animate:
		create_tween().tween_property(sprite, ^"position:y", -48.0, 0.7).set_trans(Tween.TRANS_QUAD)
	else:
		sprite.position.y = -48.0
