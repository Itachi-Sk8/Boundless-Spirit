extends PlayerState
## Blue. The body hangs in place while the player steers a glowing spirit for up to the
## spirit time. The spirit flies through spirit barriers. On release the body jumps to the
## spirit's spot, unless that spot is inside a wall or hazard, in which case it stays put.

const SPIRIT_SCENE := preload("res://player/spirit.tscn")

var _spirit: Spirit
var _time_left := 0.0


func enter(_previous: StringName) -> void:
	player.spirit_ready = false
	player.velocity = Vector2.ZERO
	player.jump_hold_timer = 0.0
	_time_left = tuning.spirit_time
	_spirit = SPIRIT_SCENE.instantiate()
	player.add_sibling(_spirit)
	_spirit.setup(player)
	player.spirit = _spirit
	player.sprite.pause()
	player.sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.5)


func exit() -> void:
	if is_instance_valid(_spirit):
		_spirit.queue_free()
	player.spirit = null
	player.sprite.self_modulate = Color.WHITE
	player.sprite.play()


func physics_update(delta: float) -> void:
	_time_left -= delta
	_spirit.fly(player.move_input, tuning.spirit_speed)
	if _time_left > Player.EPSILON and Input.is_action_pressed(&"spirit"):
		return
	var target := _spirit.global_position
	if player.can_fit_at(target, Player.Shape.STAND, true):
		player.global_position = target
	player.velocity = Vector2.ZERO
	player.change_state(&"fall")
