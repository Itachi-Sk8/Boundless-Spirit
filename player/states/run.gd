extends PlayerState
## Running on the ground. One top speed, reached almost instantly.


func enter(_previous: StringName) -> void:
	player.set_shape(Player.Shape.STAND)
	player.update_facing()
	player.play(&"run")


func physics_update(delta: float) -> void:
	player.refill()
	if player.try_ground_moves():
		return
	player.update_facing()
	player.accelerate_x(delta, tuning.run_speed)
	player.apply_gravity(delta)
	player.move(delta)
	player.play(&"run")
	if not player.is_on_floor():
		player.change_state(&"fall")
	elif player.move_input.y > 0.0:
		player.change_state(&"crouch")
	elif player.input_x() == 0.0:
		player.change_state(&"idle")
