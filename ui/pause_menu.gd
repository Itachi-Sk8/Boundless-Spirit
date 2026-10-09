class_name PauseMenu
extends CanvasLayer
## The pause menu: Esc (or Start) stops the game and shows play time, deaths, and colors, with
## Resume, Map, Settings, Leave Spirit Room (inside one), and Quit. Esc again, or Back, closes
## it. Works with keys or a gamepad (see MenuList).

## The game: has can_pause(), the map, and the Spirit Room helpers.
@export var game: Main
@export var map_screen: MapScreen

var is_open := false

@onready var title: Label = %Title
@onready var stats: Label = %Stats
@onready var menu: MenuList = %Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	menu.cancelled.connect(_on_cancelled)


func _process(_delta: float) -> void:
	if not is_open and not map_screen.is_open and Input.is_action_just_pressed(&"pause") and game.can_pause():
		open()


func open() -> void:
	is_open = true
	get_tree().paused = true
	show()
	_show_main()
	Sfx.play(&"ui_confirm", -6.0)


func close() -> void:
	is_open = false
	menu.active = false
	hide()
	get_tree().paused = false
	# The press that closed the menu shouldn't also make the hero jump.
	game.player.jump_buffer_timer = 0.0


func _show_main() -> void:
	title.text = "Paused"
	stats.text = _stats_text()
	stats.show()
	menu.clear_rows()
	menu.add_button("Resume", close)
	menu.add_button("Map", _open_map)
	menu.add_button("Settings", _show_settings)
	if game.can_leave_spirit_room():
		menu.add_button("Leave Spirit Room", _leave_spirit_room)
	menu.add_button("Quit", _quit)
	menu.active = true


func _show_settings() -> void:
	title.text = "Settings"
	stats.hide()
	SettingsRows.fill(menu, _back_from_settings)
	menu.active = true


func _back_from_settings() -> void:
	_show_main()
	menu.pick(2)


func _on_cancelled() -> void:
	if title.text == "Settings":
		_back_from_settings()
	else:
		close()


func _open_map() -> void:
	menu.active = false
	hide()
	await map_screen.open(false)
	show()
	menu.active = true


func _leave_spirit_room() -> void:
	close()
	game.leave_spirit_room()


func _quit() -> void:
	GameState.save_game()
	get_tree().quit()


func _stats_text() -> String:
	var colors := GameState.colors().count(true)
	var lines := PackedStringArray()
	lines.append("Time  %s      Deaths  %d      Colors  %d / 6" % [
			GameState.format_time(GameState.play_time), GameState.deaths, colors])
	if game.is_spirit_run():
		lines.append("This run:  %s,  %d deaths" % [GameState.format_time(game.run_time()), game.run_deaths()])
	elif game.room and GameState.best_time(game.room.room_id) != INF:
		lines.append("Best clear here:  %s" % GameState.format_time(GameState.best_time(game.room.room_id)))
	return "\n".join(lines)
