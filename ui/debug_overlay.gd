extends CanvasLayer
## Test-room overlay: the hero's state and charges, plus debug switches.
## 1-6 toggle a color, 0 toggles all, R respawns, F3 hides the text. The version in the
## bottom-right corner stays visible.

@export var room: Room

@onready var label: Label = $Label
@onready var version_label: Label = $Version


func _ready() -> void:
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var color := (key.keycode - KEY_1) as GameState.SpiritColor
			GameState.set_color(color, not GameState.has_color(color))
		KEY_0:
			GameState.set_all_colors(not _all_colors_on())
		KEY_R:
			room.respawn_player()
		KEY_F3:
			label.visible = not label.visible
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not label.visible:
		return
	var hero := room.player
	var lines := PackedStringArray()
	lines.append("%s   vx %d  vy %d   dash %d  air jump %s  spirit %s   deaths %d" % [
		hero.state_name, hero.velocity.x, hero.velocity.y, hero.air_dashes_left,
		"yes" if hero.has_air_jump else "no", "yes" if hero.spirit_ready else "no",
		GameState.deaths,
	])
	var colors := PackedStringArray()
	for color: int in GameState.SpiritColor.values():
		var on := GameState.has_color(color as GameState.SpiritColor)
		colors.append("%d %s %s" % [color + 1, GameState.ABILITY_NAMES[color], "ON" if on else "off"])
	lines.append("   ".join(colors.slice(0, 3)))
	lines.append("   ".join(colors.slice(3)))
	lines.append("1-6 colors  0 all  R respawn  F3 hide  F11 fullscreen")
	label.text = "\n".join(lines)


func _all_colors_on() -> bool:
	for color: int in GameState.SpiritColor.values():
		if not GameState.has_color(color as GameState.SpiritColor):
			return false
	return true
