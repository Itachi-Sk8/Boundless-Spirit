extends PlayerState
## Standing on the ground with no direction held.

const LANDING_FROM: Array[StringName] = [&"fall", &"jump", &"dash", &"wall_slide"]


func enter(previous: StringName) -> void:
	player.set_shape(Player.Shape.STAND)
	if previous in LANDING_FROM:
		player.play(&"land", true)
	else:
		player.play(&"idle")


func physics_update(delta: float) -> void:
	player.refill()
	if player.try_ground_moves():
		return
	player.accelerate_x(delta, tuning.run_speed)
	player.apply_gravity(delta)
	player.move(delta)
	if not player.is_on_floor():
		player.change_state(&"fall")
	elif player.move_input.y > 0.0:
		player.change_state(&"crouch")
	elif player.input_x() != 0.0:
		player.change_state(&"run")
	elif player.sprite.animation == &"land" and not player.sprite.is_playing():
		player.play(&"idle")
