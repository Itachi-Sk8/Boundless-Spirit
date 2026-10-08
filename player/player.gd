class_name Player
extends CharacterBody2D
## The hero. For now it only falls and stands; the movement state machine
## (one script per state) arrives with the movement test room.

@export var tuning: PlayerTuning

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + tuning.gravity * delta, tuning.max_fall_speed)
	move_and_slide()
