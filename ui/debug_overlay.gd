extends CanvasLayer
## Debug overlay: the hero's state and charges, plus debug switches, on a dark panel. F3 shows
## or hides it; the switches only work while it shows. 1-6 toggle a color, 0 toggles all, R
## respawns, F8 starts a new game, F9 goes to the movement test room, F10 to the gallery of
## hazards, objects, and creatures. The version in the bottom-right corner always shows.

const TEST_ROOM := "res://rooms/test/movement_test.tscn"
const GALLERY := "res://rooms/test/gallery.tscn"

## The game (game/main.gd): has `player`, `room`, and respawn_player().
@export var game: Node

@onready var info: PanelContainer = $Info
@onready var label: Label = $Info/Label
@onready var version_label: Label = $Version


func _ready() -> void:
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")


func show_info() -> void:
	info.show()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		info.visible = not info.visible
		get_viewport().set_input_as_handled()
		return
	if not info.visible:
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
			_restart_in("")
		KEY_F9:
			_restart_in(TEST_ROOM)
		KEY_F10:
			_restart_in(GALLERY)
		_:
			return
	# After a restart the overlay is out of the tree (no viewport); the restart handled it.
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Reload the game, starting in the room scene at `path` (empty: the saved spot or a new game).
func _restart_in(path: String) -> void:
	get_viewport().set_input_as_handled()
	GameState.pending_room_scene = path
	# This takes the current scene, overlay included, out of the tree at once.
	get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if not info.visible:
		return
	var hero: Player = game.player
	var lines := PackedStringArray()
	lines.append("State: %s      Speed: %d, %d" % [hero.state_name, hero.velocity.x, hero.velocity.y])
	lines.append("Dash: %d      Air jump: %s      Spirit: %s" % [hero.air_dashes_left,
			"yes" if hero.has_air_jump else "no", "yes" if hero.spirit_ready else "no"])
	lines.append("Room: %s      Time: %s      Deaths: %d" % [game.room.room_id if game.room else &"-",
			GameState.format_time(GameState.play_time), GameState.deaths])
	var colors := PackedStringArray()
	for color: int in GameState.SpiritColor.values():
		var on := GameState.has_color(color as GameState.SpiritColor)
		colors.append("%d %s %s" % [color + 1, GameState.ABILITY_NAMES[color].capitalize(), "ON" if on else "off"])
	lines.append("Colors:  " + "    ".join(colors.slice(0, 3)))
	lines.append("               " + "    ".join(colors.slice(3)))
	lines.append("Keys:  1-6 colors   0 all   R respawn   F8 new game   F9 test room   F10 gallery   F3 hide   F11 fullscreen")
	label.text = "\n".join(lines)


func _all_colors_on() -> bool:
	for color: int in GameState.SpiritColor.values():
		if not GameState.has_color(color as GameState.SpiritColor):
			return false
	return true
