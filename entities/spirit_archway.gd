@tool
class_name SpiritArchway
extends Node2D
## The stone archway in front of a Spirit Room, built from parts you can adjust: the Stone arch,
## the Runes carved into it, the Portal glow filling the doorway, and the Motes drifting up
## through it. Its size and colors are set here; move, scale, or swap glyphs on each Rune
## directly. The Doorway trigger and BackWall follow the opening.
##
## It's the room's only way in: walking into the doorway asks "Are you ready to challenge your
## Spirit?" (Main.knock), and a one-way wall at the back of the opening stops the hero walking
## past. Coming back out through it never asks. Origin at its bottom-left corner.

@export_group("Size")
## The opening between the pillars, in tiles.
@export var opening_size := Vector2i(4, 6):
	set(value):
		opening_size = value.max(Vector2i.ONE)
		_layout()
## Each pillar's width, in tiles.
@export_range(1, 8) var pillar_width := 2:
	set(value):
		pillar_width = value
		_layout()
## The lintel's height over the opening, in tiles.
@export_range(1, 8) var lintel_height := 2:
	set(value):
		lintel_height = value
		_layout()
## How tall the one-way wall at the back of the opening reaches, in px from the ground.
@export var wall_height := 208.0:
	set(value):
		wall_height = value
		_layout()

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
## Where the door leads: a WorldMap room id and one of its spawn points.
@export var target_room := &"ember_spirit_room"
@export var target_spawn := &"Start"

# Disarmed after asking, until the hero steps out of the doorway.
var _armed := true

@onready var stone: ArchwayStone = $Stone
@onready var runes: Node2D = $Runes
@onready var portal: ColorRect = $Portal
@onready var motes: CPUParticles2D = $Motes
@onready var doorway: Area2D = $Doorway
@onready var doorway_shape: CollisionShape2D = $Doorway/Shape
@onready var back_wall: CollisionShape2D = $BackWall/Shape


func _ready() -> void:
	_layout()
	_paint()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var hero := _hero_in_doorway()
	if hero == null:
		_armed = true
		return
	# Only when walking in (facing the room), so stepping back out of the room never asks.
	if _armed and hero.facing < 0 and not hero.frozen and hero.state_name != &"dead" and Main.instance:
		_armed = false
		Main.instance.knock(self)


## The doorway opening in px from the origin.
func opening_rect() -> Rect2:
	var size := Vector2(opening_size * ArchwayStone.TILE)
	return Rect2(Vector2(pillar_width * ArchwayStone.TILE, -size.y), size)


## Where the hero stands after answering No: just outside the doorway.
func outside_x() -> float:
	return global_position.x + opening_rect().end.x + 8.0


# Fit the stone, glow, motes, trigger, and wall to the opening.
func _layout() -> void:
	if not is_node_ready():
		return
	stone.opening_size = opening_size
	stone.pillar_width = pillar_width
	stone.lintel_height = lintel_height
	var opening := opening_rect()
	portal.position = opening.position
	portal.size = opening.size
	motes.position = opening.get_center() + Vector2(0, 8)
	motes.emission_rect_extents = (opening.size / 2.0 - Vector2(8, 12)).max(Vector2.ONE)
	# The trigger: the bottom of the opening, a little in from the edges.
	var trigger := Vector2(opening.size.x - 4.0, minf(48.0, opening.size.y))
	(doorway_shape.shape as RectangleShape2D).size = trigger
	doorway_shape.position = Vector2(opening.get_center().x + 2.0, -trigger.y / 2.0)
	(back_wall.shape as RectangleShape2D).size = Vector2(wall_height, 4.0)
	back_wall.position = Vector2(opening.position.x, -wall_height / 2.0)


func _paint() -> void:
	if not is_node_ready():
		return
	for rune in runes.get_children():
		if rune is Rune and not (rune as Rune).own_color:
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
