class_name SpiritArchway
extends Node2D
## The stone archway in front of a Spirit Room. Runes carved into its stone glow in the color
## that waits inside, and its doorway shimmers with that light. It's the room's only way in:
## walking into the doorway asks "Are you ready to challenge your Spirit?" (Main.knock), and a
## one-way wall at the back of the opening stops the hero walking past. Coming back out through
## it never asks. Origin at its bottom-left corner.

## The doorway opening in the arch art, in px from the origin.
const OPENING := Rect2(32, -96, 64, 96)

## Which color waits inside, as a GameState.SpiritColor value.
@export var color := 0
## Where the door leads: a WorldMap room id and one of its spawn points.
@export var target_room := &"ember_spirit_room"
@export var target_spawn := &"Start"

# Disarmed after asking, until the hero steps out of the doorway.
var _armed := true
var _time := 0.0

@onready var glow: Sprite2D = $Glow
@onready var portal: ColorRect = $Portal
@onready var motes: CPUParticles2D = $Motes
@onready var doorway: Area2D = $Doorway


func _ready() -> void:
	var tint: Color = ColorOrb.TINTS[color]
	glow.modulate = tint.lightened(0.2)
	(portal.material as ShaderMaterial).set_shader_parameter(&"glow_color", tint.lightened(0.15))
	motes.color = tint.lightened(0.35)


func _process(delta: float) -> void:
	_time += delta
	glow.modulate.a = 0.6 + 0.3 * sin(_time * 1.8)


func _physics_process(_delta: float) -> void:
	var hero := _hero_in_doorway()
	if hero == null:
		_armed = true
		return
	# Only when walking in (facing the room), so stepping back out of the room never asks.
	if _armed and hero.facing < 0 and not hero.frozen and hero.state_name != &"dead" and Main.instance:
		_armed = false
		Main.instance.knock(self)


## Where the hero stands after answering No: just outside the doorway.
func outside_x() -> float:
	return global_position.x + OPENING.end.x + 8.0


func _hero_in_doorway() -> Player:
	var rect := Touch.shape_rect($Doorway/Shape)
	for body in doorway.get_overlapping_bodies():
		if Touch.hero_in(body, rect):
			return body
	return null
