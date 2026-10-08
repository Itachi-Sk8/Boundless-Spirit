extends PlayerState
## Purple. Hanging from a ledge. Up or Jump pulls up, Down drops, and Jump while holding
## away from the wall jumps off it.

var _climbing := false
var _climb_left := 0.0


func enter(_previous: StringName) -> void:
	_climbing = false
	player.velocity = Vector2.ZERO
	player.global_position = player.ledge_hang_position
	player.play(&"ledge_hang", true)


func physics_update(delta: float) -> void:
	if _climbing:
		_climb_left -= delta
		if _climb_left <= Player.EPSILON:
			player.global_position = player.ledge_top_position
			player.change_state(&"idle")
		return
	if player.try_spirit() or player.try_dash():
		return
	var jumped := player.jump_buffer_timer > Player.EPSILON
	if jumped and player.input_x() == -player.facing:
		player.kick_off_wall(player.facing)
		player.change_state(&"jump")
	elif jumped or player.move_input.y < 0.0:
		player.jump_buffer_timer = 0.0
		_climbing = true
		_climb_left = tuning.ledge_climb_time
		player.play(&"ledge_climb", true)
	elif player.move_input.y > 0.0:
		player.ledge_regrab_timer = tuning.ledge_regrab_delay
		player.change_state(&"fall")
