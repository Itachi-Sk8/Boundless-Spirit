@tool
class_name SpiritGate
extends Node2D
## A Spirit Room's gate: one stone image you can repaint (art/gate/spirit_gate.png), a portal
## glowing in its doorway, runes on the stone, and motes drifting up through the doorway.
## Standing in the doorway and pressing Interact (C / RB) uses it:
## - An entrance asks "Are you ready to challenge your Spirit?" and takes the hero to
##   `target_room` at `target_spawn` (Main.knock).
## - An exit, inside a Spirit Room, takes the hero back to the gate they came in through
##   (Main.leave_spirit_room). It stays dark until the room's color is taken.
## Origin at the bottom center of the doorway, on the ground. Move, recolor, or change the glyph
## of each Rune under Runes; draw new glyphs in art/gate/runes.png.

enum Mode { ENTRANCE, EXIT }

const LOCKED_MESSAGE := "The way out opens when the color returns."

@export_group("Art")
## The gate's stone, drawn as one image. Its bottom edge stands on the ground.
@export var texture: Texture2D = preload("res://art/gate/spirit_gate.png"):
	set(value):
		texture = value
		_layout()
## The doorway in the image, in px from the image's top-left corner. The portal fills it, and
## the gate's origin is at its bottom center.
@export var opening := Rect2i(32, 32, 64, 96):
	set(value):
		opening = value
		_layout()
## Tints the stone (white keeps the image's own colors).
@export var stone_tint := Color.WHITE:
	set(value):
		stone_tint = value
		_paint()
## The sheet the runes draw their glyphs from: 16×16 glyphs, 8 per row.
@export var glyph_sheet: Texture2D = preload("res://art/gate/runes.png"):
	set(value):
		glyph_sheet = value
		_paint()

@export_group("Colors")
## The runes' light (each Rune with `own_color` off).
@export var rune_color := Color(0.95, 0.55, 0.22):
	set(value):
		rune_color = value
		_paint()
## The glow filling the doorway.
@export var portal_color := Color(0.89, 0.52, 0.28):
	set(value):
		portal_color = value
		_paint()
## How far the glow reaches past the doorway's sides and top, in px, behind the stone. The glow
## fades toward its edges, so reaching under the stone lets it fill the doorway.
@export var portal_overhang := Vector2i(12, 10):
	set(value):
		portal_overhang = value
		_layout()
## How fast the doorway's light drifts.
@export var portal_speed := 1.4:
	set(value):
		portal_speed = value
		_paint()
## The motes drifting up through the doorway.
@export var motes_color := Color(0.92, 0.64, 0.45):
	set(value):
		motes_color = value
		_paint()

@export_group("Door")
## Entrance: leads into a Spirit Room. Exit: inside a Spirit Room, leads back out.
@export var mode := Mode.ENTRANCE
## Where an entrance leads: a Spirit Room's id and one of its spawn points.
@export var target_room := &"ember_spirit_room"
@export var target_spawn := &"Start"

@onready var portal: ColorRect = $Portal
@onready var stone: Sprite2D = $Stone
@onready var runes: Node2D = $Runes
@onready var motes: CPUParticles2D = $Motes
@onready var doorway: Area2D = $Doorway
@onready var doorway_shape: CollisionShape2D = $Doorway/Shape
@onready var hint: Label = $Hint


func _ready() -> void:
	_layout()
	_paint()
	hint.hide()
	if not Engine.is_editor_hint():
		hint.text = _key_name(&"interact")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var open := is_open()
	portal.visible = open
	motes.emitting = open
	var hero := _hero_in_doorway()
	var usable := hero != null and _can_use(hero)
	hint.visible = usable
	if usable and Input.is_action_just_pressed(&"interact"):
		_use()


## True when the gate can be walked through: always for an entrance; for an exit, once the
## room's color is taken (no Spirit Room run going on).
func is_open() -> bool:
	return mode == Mode.ENTRANCE or Main.instance == null or not Main.instance.is_spirit_run()


func _use() -> void:
	if mode == Mode.ENTRANCE:
		Main.instance.knock(self)
	elif is_open():
		Main.instance.leave_spirit_room()
	else:
		Main.instance.prompt.show_text(LOCKED_MESSAGE, 3.0)


func _can_use(hero: Player) -> bool:
	return Main.instance != null and not Main.instance.transitioning and not hero.frozen \
			and not hero.input_locked and hero.state_name != &"dead"


# Fit the stone, portal, motes, trigger, and hint to the image and its doorway.
func _layout() -> void:
	if not is_node_ready():
		return
	var size := texture.get_size() if texture else Vector2.ZERO
	# The image point that sits on the gate's origin: the doorway's bottom center.
	var anchor := Vector2(Rect2(opening).get_center().x, size.y)
	var door := Rect2(Vector2(opening.position) - anchor, opening.size)
	stone.texture = texture
	stone.offset = -anchor
	var reach := Vector2(portal_overhang)
	portal.position = door.position - reach
	portal.size = door.size + Vector2(reach.x * 2.0, reach.y)
	motes.position = door.get_center() + Vector2(0, 8)
	motes.emission_rect_extents = (door.size / 2.0 - Vector2(8, 12)).max(Vector2.ONE)
	# The trigger: the bottom of the doorway, a little in from the sides.
	var trigger := Vector2(maxf(door.size.x - 8.0, 8.0), minf(48.0, door.size.y))
	(doorway_shape.shape as RectangleShape2D).size = trigger
	doorway_shape.position = Vector2(0, -trigger.y / 2.0)
	hint.position = Vector2(-hint.size.x / 2.0, -64.0)


func _paint() -> void:
	if not is_node_ready():
		return
	stone.modulate = stone_tint
	for rune in runes.get_children():
		if rune is Rune:
			(rune as Rune).sheet = glyph_sheet
			if not (rune as Rune).own_color:
				(rune as Rune).color = rune_color
	var glow := portal.material as ShaderMaterial
	glow.set_shader_parameter(&"glow_color", portal_color)
	glow.set_shader_parameter(&"speed", portal_speed)
	motes.color = motes_color


func _hero_in_doorway() -> Player:
	var rect := Touch.shape_rect(doorway_shape)
	for body in doorway.get_overlapping_bodies():
		if Touch.hero_in(body, rect):
			return body
	return null


# The keyboard key bound to an action, for the hint ("C").
static func _key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "?"
