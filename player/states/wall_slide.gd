extends PlayerState
## Holding toward a wall while falling slows the fall to a slide. Jumping kicks off the wall.

var _side := 0


func enter(_previous: StringName) -> void:
	_side = int(player.input_x())
	player.facing = _side
	player.velocity.x = 0.0
	player.play(&"wall_land", true)


func physics_update(delta: float) -> void:
	if player.try_spirit() or player.try_dash() or player.try_climb() or player.try_air_jump():
		return
	# Lean into the wall so contact holds.
	player.velocity.x = _side * tuning.wall_check_distance
	player.velocity.y = minf(player.velocity.y + tuning.gravity * delta, tuning.wall_slide_speed)
	player.move(delta)
	if player.is_on_floor():
		land()
	elif player.input_x() != _side or not player.is_wall_at(_side):
		player.change_state(&"fall")
	elif not player.sprite.is_playing():
		player.play(&"wall_slide")
