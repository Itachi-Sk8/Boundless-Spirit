extends PlayerState
## Orange. A quick burst in any of 8 directions, with a tiny freeze at the start so it
## reads clearly. Some speed carries out of it.

var _direction := Vector2.ZERO
var _freeze_left := 0.0
var _time_left := 0.0


func enter(_previous: StringName) -> void:
	player.air_dashes_left -= 1
	var aim := player.move_input
	if aim == Vector2.ZERO:
		aim = Vector2(player.facing, 0.0)
	_direction = aim.normalized()
	if _direction.x != 0.0:
		player.facing = int(signf(_direction.x))
	_freeze_left = tuning.dash_freeze_time
	_time_left = tuning.dash_time
	player.velocity = Vector2.ZERO
	player.jump_hold_timer = 0.0
	player.play(&"dash", true)
	Sfx.play(&"dash")


func physics_update(delta: float) -> void:
	if _freeze_left > Player.EPSILON:
		_freeze_left -= delta
		return
	player.velocity = _direction * (tuning.dash_distance / tuning.dash_time)
	player.move(delta)
	_time_left -= delta
	var blocked := player.is_on_wall() and _direction.y == 0.0
	if _time_left <= Player.EPSILON or blocked:
		_finish()


func _finish() -> void:
	var end := _direction * tuning.dash_end_speed
	if end.y < 0.0:
		end.y *= tuning.dash_up_end_factor
	player.velocity = end
	if player.is_on_floor():
		land()
	else:
		player.change_state(&"fall")
