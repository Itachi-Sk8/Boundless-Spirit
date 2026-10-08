class_name PlayerState
extends RefCounted
## One movement state. The player calls enter() on the way in, physics_update() every
## physics frame while active, and exit() on the way out. States read input and timers from
## the player and switch with player.change_state().

var player: Player
var tuning: PlayerTuning:
	get:
		return player.tuning


func _init(owner: Player) -> void:
	player = owner


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## Pick the right ground state once the hero has landed.
func land() -> void:
	player.change_state(&"run" if player.input_x() != 0.0 else &"idle")
