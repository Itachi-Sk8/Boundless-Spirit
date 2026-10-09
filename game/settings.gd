extends Node
## Player-facing settings, saved to user://settings.cfg and applied at once: music and sound
## volume, fullscreen and window size, screen shake, and the speedrun timer. The settings menu
## (ui/settings_menu.gd) changes them through the setters below. Control remapping comes with
## the polish milestone.

signal changed

const PATH := "user://settings.cfg"
## Room left for the title bar and window border when fitting the window, in px.
const DECORATION_MARGIN := 64

## 0 to 1.
var music_volume := 0.8
var sound_volume := 0.8
var fullscreen := false
## Whole-number scale of the 480×270 view in a window; 0 picks the largest that fits.
var window_scale := 0
var screen_shake := true
var speedrun_timer := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_volumes()
	if fullscreen and not _windowing_locked():
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		fit_window_to_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_changed()


func set_sound_volume(value: float) -> void:
	sound_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_changed()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	if not _windowing_locked():
		if on:
			get_window().mode = Window.MODE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
			fit_window_to_screen()
	_changed()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


func set_window_scale(scale: int) -> void:
	window_scale = clampi(scale, 0, max_window_scale())
	fit_window_to_screen()
	_changed()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_changed()


func set_speedrun_timer(on: bool) -> void:
	speedrun_timer = on
	_changed()


## The largest whole-number window scale that fits the screen, title bar included.
func max_window_scale() -> int:
	if DisplayServer.get_name() == "headless":
		return 4
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var base := _base_size()
	return maxi(1, mini(usable.size.x / base.x, (usable.size.y - DECORATION_MARGIN) / base.y))


## Size the window to the chosen scale of the base resolution (or the largest that fits the
## screen, title bar included) and center it. 4× on a 1440p screen, 3× on a 1080p one.
func fit_window_to_screen() -> void:
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED or _windowing_locked():
		return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var scale := max_window_scale()
	if window_scale > 0:
		scale = mini(window_scale, scale)
	window.size = _base_size() * scale
	window.position = usable.position + (usable.size - window.size) / 2


func _base_size() -> Vector2i:
	return Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))


func _apply_volumes() -> void:
	_set_bus_volume(&"Music", music_volume)
	_set_bus_volume(&"SFX", sound_volume)


func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))


func _changed() -> void:
	_save()
	changed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	music_volume = config.get_value("audio", "music_volume", music_volume)
	sound_volume = config.get_value("audio", "sound_volume", sound_volume)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	window_scale = config.get_value("video", "window_scale", window_scale)
	screen_shake = config.get_value("game", "screen_shake", screen_shake)
	speedrun_timer = config.get_value("game", "speedrun_timer", speedrun_timer)


func _save() -> void:
	# Automated runs (tests) never change a player's settings file.
	if DisplayServer.get_name() == "headless":
		return
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sound_volume", sound_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "window_scale", window_scale)
	config.set_value("game", "screen_shake", screen_shake)
	config.set_value("game", "speedrun_timer", speedrun_timer)
	config.save(PATH)


# Headless runs have no window, and when the editor runs the game inside its own Game tab, the
# editor owns the window.
func _windowing_locked() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	return Engine.has_method(&"is_embedded_in_editor") and Engine.call(&"is_embedded_in_editor")
