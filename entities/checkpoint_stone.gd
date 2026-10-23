@tool
class_name CheckpointStone
extends Area2D
## A standing stone whose rune lights when the hero passes it, setting the respawn point for
## the rest of the room. Ignored in Spirit Rooms. Origin at the bottom center, on the ground.
## Every checkpoint stone in a region carries that region's rune (REGION_GLYPHS), so the
## stones of one region match and differ from the next; `glyph` picks another for one stone.

## The checkpoint rune of each region (Room.region), from art/entities/runes.png.
const REGION_GLYPHS := {
	&"hollow": 2, &"ember_grove": 2, &"meadow": 7, &"canopy": 20, &"briar": 4,
	&"caverns": 1, &"falls": 15, &"heart": 10,
}
## The light of a lit rune.
const LIGHT := Color(0.78, 0.93, 0.97)

## This stone's rune (0-23); -1 uses its region's.
@export_range(-1, 23) var glyph := -1:
	set(value):
		glyph = value
		_paint()

var lit := false

@onready var rune: Rune = $Rune


func _ready() -> void:
	_paint()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


## The rune this stone shows: its own, or its room's region's.
func shown_glyph() -> int:
	if glyph >= 0:
		return glyph
	var room := owner as Room
	return REGION_GLYPHS.get(StringName(room.region) if room else &"hollow", 2)


func _on_body_entered(body: Node2D) -> void:
	if lit or not Touch.hero_in(body, Touch.shape_rect($Shape)) or Main.instance == null:
		return
	if Main.instance.checkpoint_reached(global_position):
		lit = true
		_paint()
		Sfx.play(&"checkpoint")


func _paint() -> void:
	if not is_node_ready():
		return
	rune.glyph = shown_glyph()
	rune.color = LIGHT
	rune.brightness = 0.9 if lit else 0.0
