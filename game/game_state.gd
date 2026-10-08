extends Node
## Everything the game remembers: colors, deaths, and later wisps, play time, and opened
## shortcuts. Saving to JSON arrives with the vertical slice.

signal colors_changed
signal deaths_changed

## The six colors, in unlock order.
enum SpiritColor { ORANGE, YELLOW, GREEN, RED, PURPLE, BLUE }

const COLOR_NAMES: Array[String] = ["orange", "yellow", "green", "red", "purple", "blue"]
const ABILITY_NAMES: Array[String] = [
	"dash", "double jump", "wall jump", "slide", "climb", "spirit phase",
]

var deaths := 0

var _colors: Array[bool] = [false, false, false, false, false, false]


func has_color(color: SpiritColor) -> bool:
	return _colors[color]


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
