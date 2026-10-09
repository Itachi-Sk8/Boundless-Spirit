class_name SettingsRows
## Fills a MenuList with the settings rows (see game/settings.gd), ending in a Back row. Used by
## the pause menu (and later the title screen).


static func fill(menu: MenuList, back: Callable) -> void:
	menu.clear_rows()
	menu.add_slider("Music volume", func() -> float: return Settings.music_volume, Settings.set_music_volume)
	menu.add_slider("Sound volume", func() -> float: return Settings.sound_volume, Settings.set_sound_volume)
	menu.add_toggle("Fullscreen", func() -> bool: return Settings.fullscreen, Settings.set_fullscreen)
	var sizes := PackedStringArray(["Fit screen"])
	for scale in range(1, Settings.max_window_scale() + 1):
		sizes.append("%dx  (%d x %d)" % [scale, 480 * scale, 270 * scale])
	menu.add_choice("Window size", sizes, func() -> int: return Settings.window_scale, Settings.set_window_scale)
	menu.add_toggle("Screen shake", func() -> bool: return Settings.screen_shake, Settings.set_screen_shake)
	menu.add_toggle("Speedrun timer", func() -> bool: return Settings.speedrun_timer, Settings.set_speedrun_timer)
	menu.add_button("Back", back)
