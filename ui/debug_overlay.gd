extends CanvasLayer
## Debug overlay: the hero's state and charges, plus debug switches. F3 shows or hides it; the
## switches only work while it shows. 1-6 toggle a color, 0 toggles all, R respawns, F8 starts
## a new game, F9 goes to the movement test room. The version in the bottom-right corner always
## shows.

const TEST_ROOM := "res://rooms/test/movement_test.tscn"

## The game (game/main.gd): has `player`, `room`, and respawn_player().
@export var game: Node

@onready var label: Label = $Label
@onready var version_label: Label = $Version


func _ready() -> void:
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		label.visible = not label.visible
		get_viewport().set_input_as_handled()
		return
	if not label.visible:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var color := (key.keycode - KEY_1) as GameState.SpiritColor
			GameState.set_color(color, not GameState.has_color(color))
		KEY_0:
			GameState.set_all_colors(not _all_colors_on())
		KEY_R:
			game.respawn_player()
		KEY_F8:
			GameState.delete_save()
			GameState.pending_room_scene = ""
			get_tree().reload_current_scene()
		KEY_F9:
			GameState.pending_room_scene = TEST_ROOM
			get_tree().reload_current_scene()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not label.visible:
		return
	var hero: Player = game.player
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
	lines.append("room %s   time %s" % [game.room.room_id if game.room else &"-",
			GameState.format_time(GameState.play_time)])
	lines.append("1-6 colors  0 all  R respawn  F8 new game  F9 test room  F3 hide  F11 fullscreen")
	label.text = "\n".join(lines)


func _all_colors_on() -> bool:
	for color: int in GameState.SpiritColor.values():
		if not GameState.has_color(color as GameState.SpiritColor):
			return false
	return true
