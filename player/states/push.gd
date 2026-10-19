extends PlayerState
## Holding Grab beside a block: moving toward it pushes, moving away pulls.

var _block: PushBlock
var _side := 0


func enter(_previous: StringName) -> void:
	_block = player.push_block
	_side = player.push_side
	player.facing = _side
	player.velocity.x = 0.0
	player.play(&"push_idle")


func physics_update(delta: float) -> void:
	player.refill()
	# The block is gone when a pull carries the hero into the next room: let go of it.
	if not is_instance_valid(_block) or not Input.is_action_pressed(&"grab") \
			or not player.is_on_floor() or player.adjacent_block(_side) != _block:
		land()
		return
	if player.try_ground_jump():
		return
	var direction := player.input_x()
	var step := direction * tuning.push_speed * delta
	if direction == _side:
		player.move_and_collide(Vector2(_block.push(step), 0.0))
		player.play(&"push")
	elif direction == -_side:
		var before := player.global_position.x
		player.move_and_collide(Vector2(step, 0.0))
		_block.push(player.global_position.x - before)
		player.play(&"pull")
	else:
		player.play(&"push_idle")
	player.velocity.x = 0.0
	player.apply_gravity(delta)
	player.move(delta)
