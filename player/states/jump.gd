extends PlayerState
## Rising. Holding jump keeps the upward speed for up to the hold time, so a tap is a short
## hop and a hold is a full jump. Plays air_spin for a double jump.


func enter(_previous: StringName) -> void:
	player.stand_up_if_room()
	player.play(player.jump_anim, true)


func physics_update(delta: float) -> void:
	if player.try_air_moves():
		return
	player.update_facing()
	player.accelerate_x(delta, tuning.run_speed)
	if player.jump_hold_timer > Player.EPSILON and Input.is_action_pressed(&"jump"):
		player.jump_hold_timer -= delta
		player.velocity.y = -player.jump_hold_speed
	else:
		player.jump_hold_timer = 0.0
		player.apply_gravity(delta)
	player.move(delta)
	player.sprite.flip_h = player.facing < 0
	if player.is_on_ceiling():
		player.jump_hold_timer = 0.0
	if player.is_on_floor() and player.velocity.y >= 0.0:
		land()
	elif player.velocity.y >= 0.0:
		player.change_state(&"fall")
