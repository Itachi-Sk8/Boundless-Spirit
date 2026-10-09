class_name SpeedrunTimer
extends Label
## The optional on-screen timer (Settings > Speedrun timer): total play time, with the current
## Spirit Room run under it during one.

@export var game: Main


func _ready() -> void:
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := GameState.format_time(GameState.play_time)
	if game.is_spirit_run():
		lines += "\nRun  " + GameState.format_time(game.run_time())
	text = lines


func _on_settings_changed() -> void:
	visible = Settings.speedrun_timer
