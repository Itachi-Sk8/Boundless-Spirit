extends PlayerState
## Ducking, and crouch-walking slowly. Holding still long enough peeks the camera down.
## Under a low ceiling the hero stays crouched until there is room to stand.

var _still_time := 0.0


func enter(_previous: StringName) -> void:
	player.set_shape(Player.Shape.CROUCH)
	_still_time = 0.0
	player.play(&"crouch_idle")


func exit() -> void:
	player.peeking = false


func physics_update(delta: float) -> void:
	player.refill()
	var can_stand := player.can_fit(Player.Shape.STAND)
	if can_stand and (player.try_spirit() or player.try_dash() or player.try_ground_jump()):
		return
	player.update_facing()
	player.accelerate_x(delta, tuning.crouch_speed)
	player.apply_gravity(delta)
	player.move(delta)
	if not player.is_on_floor():
		player.change_state(&"fall")
		return
	if player.move_input.y <= 0.0 and can_stand:
		land()
		return
	var moving := player.input_x() != 0.0
	_still_time = 0.0 if moving else _still_time + delta
	player.peeking = _still_time >= tuning.peek_delay
	player.play(&"crouch_walk" if moving else &"crouch_idle")
