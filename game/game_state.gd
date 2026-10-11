extends Node
## Everything the game remembers: colors, where the hero is, deaths, play time, opened
## shortcuts, rooms visited (for the map), and Spirit Room best times. Saved as JSON to user://save_<slot>.json.

signal colors_changed
signal deaths_changed

## The six colors, in unlock order.
enum SpiritColor { ORANGE, YELLOW, GREEN, RED, PURPLE, BLUE }

const COLOR_NAMES: Array[String] = ["orange", "yellow", "green", "red", "purple", "blue"]
const ABILITY_NAMES: Array[String] = [
	"dash", "double jump", "wall jump", "slide", "climb", "spirit phase",
]
const SAVE_VERSION := 1

var slot := 1
var room_id: StringName = &""
## Where the hero comes back after loading or dying, in world pixels.
var respawn_position := Vector2.ZERO
var deaths := 0
var play_time := 0.0
## Permanent changes such as opened shortcuts, by name.
var flags := {}
## Best clean-run time per Spirit Room, in seconds, by room id.
var best_times := {}
## Deaths it took to clear each Spirit Room, by room id. Recorded for later; nothing shows it yet.
var clear_deaths := {}
## Rooms the hero has been in, by id (the map shows only these).
var visited := {}
## The gate the hero entered the current Spirit Room through, where leaving it goes back to: its
## room id (&"" when not in one) and the spot in its doorway, in world pixels.
var spirit_return_room: StringName = &""
var spirit_return_spot := Vector2.ZERO
## Set when a room scene is run on its own (F6) so the game starts in it.
var pending_room_scene := ""

var _colors: Array[bool] = [false, false, false, false, false, false]


func _ready() -> void:
	# `godot --path . -- --slot=9` plays in another save slot, so automated runs and tests
	# never touch a player's save.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--slot="):
			slot = int(arg.trim_prefix("--slot="))


func has_color(color: SpiritColor) -> bool:
	return _colors[color]


## Which colors are back, indexed by SpiritColor.
func colors() -> Array[bool]:
	return _colors.duplicate()


func set_color(color: SpiritColor, unlocked: bool) -> void:
	if _colors[color] == unlocked:
		return
	_colors[color] = unlocked
	colors_changed.emit()


func set_all_colors(unlocked: bool) -> void:
	for color in SpiritColor.values():
		_colors[color] = unlocked
	colors_changed.emit()


func add_death() -> void:
	deaths += 1
	deaths_changed.emit()


func has_visited(room: StringName) -> bool:
	return visited.has(String(room))


func mark_visited(room: StringName) -> void:
	visited[String(room)] = true


func has_flag(flag: StringName) -> bool:
	return flags.get(String(flag), false)


func set_flag(flag: StringName) -> void:
	flags[String(flag)] = true


## Record a cleared Spirit Room run: its time (kept if best) and the deaths it took.
func record_clear(room: StringName, seconds: float, run_deaths: int) -> void:
	record_time(room, seconds)
	clear_deaths[String(room)] = run_deaths


## Record a Spirit Room time; returns true if it is a new best.
func record_time(room: StringName, seconds: float) -> bool:
	var best: float = best_times.get(String(room), INF)
	if seconds < best:
		best_times[String(room)] = seconds
		return true
	return false


func best_time(room: StringName) -> float:
	return best_times.get(String(room), INF)


# --- Saving --------------------------------------------------------------------------------

func save_path(for_slot := slot) -> String:
	return "user://save_%d.json" % for_slot


func new_game(for_slot := slot) -> void:
	slot = for_slot
	room_id = WorldMap.START_ROOM
	respawn_position = Vector2.ZERO
	deaths = 0
	play_time = 0.0
	flags = {}
	visited = {}
	best_times = {}
	clear_deaths = {}
	spirit_return_room = &""
	spirit_return_spot = Vector2.ZERO
	_colors = [false, false, false, false, false, false]
	colors_changed.emit()
	deaths_changed.emit()


func save_game() -> void:
	if not WorldMap.has_room(room_id):
		return # Test rooms aren't part of the world.
	var data := {
		"version": SAVE_VERSION,
		"room": String(room_id),
		"respawn": [respawn_position.x, respawn_position.y],
		"colors": _colors,
		"deaths": deaths,
		"play_time": play_time,
		"flags": flags,
		"visited": visited,
		"best_times": best_times,
		"clear_deaths": clear_deaths,
		"spirit_return": [String(spirit_return_room), spirit_return_spot.x, spirit_return_spot.y],
	}
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


## Load a slot. Returns false (and leaves a new game) if there is no usable save.
func load_game(for_slot := slot) -> bool:
	new_game(for_slot)
	if not FileAccess.file_exists(save_path()):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if typeof(data) != TYPE_DICTIONARY or not WorldMap.has_room(StringName(data.get("room", ""))):
		return false
	room_id = StringName(data["room"])
	var spot: Array = data.get("respawn", [0, 0])
	respawn_position = Vector2(spot[0], spot[1])
	var saved_colors: Array = data.get("colors", [])
	for i in mini(saved_colors.size(), _colors.size()):
		_colors[i] = bool(saved_colors[i])
	deaths = int(data.get("deaths", 0))
	play_time = float(data.get("play_time", 0.0))
	flags = data.get("flags", {})
	visited = data.get("visited", {})
	best_times = data.get("best_times", {})
	clear_deaths = data.get("clear_deaths", {})
	var back: Array = data.get("spirit_return", ["", 0, 0])
	spirit_return_room = StringName(back[0])
	spirit_return_spot = Vector2(back[1], back[2])
	colors_changed.emit()
	deaths_changed.emit()
	return true


## A time as m:ss.cc, or dashes for none.
func format_time(seconds: float) -> String:
	if seconds == INF:
		return "--:--.--"
	var minutes := int(seconds) / 60
	return "%d:%05.2f" % [minutes, seconds - minutes * 60]


func delete_save(for_slot := slot) -> void:
	if FileAccess.file_exists(save_path(for_slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path(for_slot)))
