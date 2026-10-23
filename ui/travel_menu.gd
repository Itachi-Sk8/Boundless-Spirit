class_name TravelMenu
extends CanvasLayer
## The travel menu, opened with Interact at an awake waystone: the Hollow and every region
## whose waystone glows, except the room the hero is in, then Stay. Picking a stop travels
## there behind the letterbox; Stay, Esc, or Back closes it. Pauses the game while open, and
## works with keys or a gamepad (see MenuList).

## The game: travels, and has the hero.
@export var game: Main

## True while the menu shows (and for the frame after it closes, so the press that closed it
## can't also open the pause menu).
var is_open := false

@onready var title: Label = %Title
@onready var info: Label = %Info
@onready var menu: MenuList = %Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	menu.cancelled.connect(close)


func open() -> void:
	is_open = true
	get_tree().paused = true
	show()
	menu.clear_rows()
	var here := game.room.room_id
	var count := 0
	for stop: Dictionary in stops():
		if stop["room"] != here:
			menu.add_button(stop_name(stop), _go.bind(stop))
			count += 1
	info.text = "Where to?" if count > 0 else "No other stone has woken yet."
	menu.add_button("Stay", close)
	menu.active = true
	Sfx.play(&"ui_confirm", -6.0)


func close() -> void:
	menu.active = false
	hide()
	get_tree().paused = false
	# The press that closed the menu shouldn't also make the hero jump.
	game.player.jump_buffer_timer = 0.0
	await get_tree().process_frame
	is_open = false


## Where travel can go now: the Hollow, and each region whose waystone is awake.
static func stops() -> Array:
	return WorldMap.travel_stops().filter(func(stop: Dictionary) -> bool:
		return stop["kind"] == Waystone.Kind.HOLLOW or GameState.has_color(stop["color"]))


static func stop_name(stop: Dictionary) -> String:
	if stop["kind"] == Waystone.Kind.HOLLOW:
		return WorldMap.REGION_NAMES[&"hollow"]
	return WorldMap.REGION_NAMES.get(WorldMap.region_of(stop["room"]), String(stop["room"]))


func _go(stop: Dictionary) -> void:
	await close()
	game.travel_to(stop["room"], stop["spot"])
