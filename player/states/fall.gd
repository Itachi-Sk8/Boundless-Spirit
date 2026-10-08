extends PlayerState
## Falling, from the top of a jump or off a ledge. Coyote time lets a jump still work
## for a moment after running off a ledge.


func enter(_previous: StringName) -> void:
	player.stand_up_if_room()
	# Let a double jump's spin finish before switching to the falling pose.
	if player.sprite.animation != &"air_spin" or not player.sprite.is_playing():
		player.play(&"fall")


func physics_update(delta: float) -> void:
	if player.try_air_moves():
		return
	player.update_facing()
	player.accelerate_x(delta, tuning.run_speed)
	player.apply_gravity(delta)
	player.move(delta)
	player.sprite.flip_h = player.facing < 0
	if player.is_on_floor():
		land()
	elif player.sprite.animation == &"air_spin" and not player.sprite.is_playing():
		player.play(&"fall")
