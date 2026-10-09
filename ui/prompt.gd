class_name Prompt
extends Label
## A line of text near the bottom of the screen that fades in, stays, and fades out: button
## prompts such as the one shown when a color returns.

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0


func show_text(message: String, seconds := 5.0) -> void:
	text = message
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, 0.3)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, ^"modulate:a", 0.0, 0.6)
