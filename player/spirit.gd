class_name Spirit
extends CharacterBody2D
## The hero's spirit during Spirit Phase: the hero's own sprite, glowing blue. It is stopped
## by walls and blocks but flies through spirit barriers, and is the same size as the hero
## so where it can go is where the body can land.

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Body


func setup(hero: Player) -> void:
	global_position = hero.global_position
	var rect := RectangleShape2D.new()
	rect.size = hero.tuning.stand_size
	body_shape.shape = rect
	body_shape.position = Vector2(0.0, -rect.size.y / 2.0)
	sprite.flip_h = hero.facing < 0


func fly(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0
	move_and_slide()
