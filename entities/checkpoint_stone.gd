class_name CheckpointStone
extends Area2D
## A standing stone whose rune lights when the hero passes it, setting the respawn point for
## the rest of the room. Ignored in Spirit Rooms. Origin at the bottom center, on the ground.

var lit := false

@onready var glow: Sprite2D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	glow.hide()


func _process(_delta: float) -> void:
	if lit:
		glow.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 300.0)


func _on_body_entered(body: Node2D) -> void:
	if lit or not Touch.hero_in(body, Touch.shape_rect($Shape)) or Main.instance == null:
		return
	if Main.instance.checkpoint_reached(global_position):
		lit = true
		glow.show()
		Sfx.play(&"checkpoint")
