extends PlayerState
## Purple. Holding Grab on vines clings to them; climb in any direction with no stamina
## limit. Jumping off works like a wall jump.


func enter(_previous: StringName) -> void:
	player.velocity = Vector2.ZERO
	player.stand_up_if_room()
	player.jump_hold_timer = 0.0
	player.last_wall_jump_side = 0
	_play_climb()


func exit() -> void:
	player.sprite.play()


func physics_update(delta: float) -> void:
	if player.try_spirit() or player.try_dash():
		return
	if not player.on_vine() or not Input.is_action_pressed(&"grab"):
		# Climbing off the top of the vines gives a small hop onto the ledge.
		if not player.on_vine() and player.move_input.y < 0.0:
			player.velocity.y = -tuning.climb_exit_hop
		player.change_state(&"fall")
		return
	if player.jump_buffer_timer > Player.EPSILON:
		var wall := player.wall_side()
		if wall != 0:
			player.kick_off_wall(wall)
		else:
			player.start_jump(tuning.jump_speed, tuning.jump_hold_time)
			player.velocity.x = player.input_x() * tuning.wall_jump_speed_x
		player.change_state(&"jump")
		return
	player.update_facing()
	player.velocity = player.move_input.normalized() * tuning.climb_speed
	player.move(delta)
	if player.is_on_floor() and player.move_input.y > 0.0:
		player.change_state(&"idle")
		return
	_play_climb()
	if player.move_input == Vector2.ZERO:
		player.sprite.pause()
	else:
		player.sprite.play()


## Side-climb facing the wall when there is one, back-climb on open vines.
func _play_climb() -> void:
	var wall := player.wall_side()
	if wall != 0:
		player.facing = wall
	player.play(&"climb_side" if wall != 0 else &"climb_back")
