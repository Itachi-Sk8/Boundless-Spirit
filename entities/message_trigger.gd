class_name MessageTrigger
extends Area2D
## Shows a message in the prompt line the first time the hero walks into it. "{time}" and
## "{deaths}" in the text become the play time and total deaths.

@export_multiline var text := ""
## Seconds the message stays up.
@export var seconds := 6.0
## Size of the trigger area in px, centered on the node.
@export var size := Vector2(32, 64)

var _shown := false


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	($Shape as CollisionShape2D).shape = rect
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _shown or not Touch.hero_in(body, Touch.shape_rect($Shape)) or Main.instance == null:
		return
	_shown = true
	var message := text.replace("{time}", GameState.format_time(GameState.play_time))
	message = message.replace("{deaths}", str(GameState.deaths))
	Main.instance.prompt.show_text(message, seconds)
