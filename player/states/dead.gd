extends PlayerState
## Touched a hazard or fell out of the room. Plays the death animation, then tells the
## room, which resets itself and respawns the hero. Death to control is under 0.5 s.

var _time_left := 0.0


func enter(_previous: StringName) -> void:
	_time_left = tuning.death_time
	player.velocity = Vector2.ZERO
	player.play(&"death", true)
	Sfx.play(&"death")


func physics_update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= Player.EPSILON:
		_time_left = INF # Wait here until the room calls respawn().
		player.died.emit()
