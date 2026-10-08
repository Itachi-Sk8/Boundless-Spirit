extends Node
## Player-facing settings. For now window size and fullscreen; volume, remapping, screen
## shake, and the speedrun timer join them with the settings menu.

## Room left for the title bar and window border when fitting the window, in px.
const DECORATION_MARGIN := 64


func _ready() -> void:
	fit_window_to_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Size the window to the largest whole-number scale of the base resolution that fits the
## screen, title bar included, and center it. 4× on a 1440p screen, 3× on a 1080p one.
func fit_window_to_screen() -> void:
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED or _embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	var base := Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var scale := maxi(1, mini(usable.size.x / base.x, (usable.size.y - DECORATION_MARGIN) / base.y))
	window.size = base * scale
	window.position = usable.position + (usable.size - window.size) / 2


func toggle_fullscreen() -> void:
	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
		fit_window_to_screen()
	else:
		window.mode = Window.MODE_FULLSCREEN


## When the editor runs the game inside its own Game tab, the editor owns the window size.
func _embedded_in_editor() -> bool:
	return Engine.has_method(&"is_embedded_in_editor") and Engine.call(&"is_embedded_in_editor")
