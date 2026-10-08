extends PlayerState
## Red. A low, fast slide under 1-tile gaps. Jumping out keeps the speed for a long jump.
## Under a low ceiling the hero stays low, crawling, until there is room.

var _time_left := 0.0


func enter(_previous: StringName) -> void:
	player.set_shape(Player.Shape.SLIDE)
	_time_left = tuning.slide_time
	player.velocity.x = player.facing * tuning.slide_speed
	player.play(&"slide", true)


func physics_update(delta: float) -> void:
	player.refill()
	var can_stand := player.can_fit(Player.Shape.STAND)
	if can_stand and (player.try_spirit() or player.try_dash() or player.try_ground_jump()):
		return # The jump keeps velocity.x: that's the long jump.
	_time_left -= delta
	if _time_left <= Player.EPSILON:
		if can_stand:
			land()
			return
		if player.can_fit(Player.Shape.CROUCH):
			player.change_state(&"crouch")
			return
		# Stuck low: crawl on, steering with the stick.
		player.update_facing()
		player.velocity.x = player.facing * tuning.slide_crawl_speed
		player.sprite.flip_h = player.facing < 0
	player.apply_gravity(delta)
	player.move(delta)
	if not player.is_on_floor():
		player.change_state(&"fall")
	elif player.is_on_wall() and _time_left > Player.EPSILON:
		_time_left = 0.0
