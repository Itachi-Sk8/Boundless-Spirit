@tool
class_name PressurePlate
extends Area2D
## A stone plate in the floor, pressed while the hero, a push block, or a hidden snail's shell
## rests on it. It switches everything in `targets` (anything with set_active(bool), such as a
## PlateDoor): on while pressed, off when released, or on for good with `latch` (until the
## room resets). Origin at its bottom center, on the ground.

signal toggled(pressed: bool)

const ART := preload("res://art/objects/plate.png")

## The things it switches: drag nodes in (e.g. a PlateDoor).
@export var targets: Array[NodePath] = []
## Stay pressed once pressed, until the room resets.
@export var latch := false

var pressed := false

@onready var shape_node: CollisionShape2D = $Shape


func _ready() -> void:
	collision_layer = 0
	# The hero (2) and push blocks and shells (16).
	collision_mask = 2 | 16
	monitorable = false
	if not Engine.is_editor_hint():
		add_to_group(&"room_reset")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var down := _something_on()
	if down == pressed or (pressed and latch):
		return
	pressed = down
	Sfx.play(&"plate", -4.0)
	_switch()


func reset_to_start() -> void:
	pressed = false
	_switch()


func _switch() -> void:
	queue_redraw()
	for path in targets:
		var target := get_node_or_null(path)
		if target and target.has_method(&"set_active"):
			target.set_active(pressed)
	toggled.emit(pressed)


func _something_on() -> bool:
	var rect := Touch.shape_rect(shape_node)
	for body in get_overlapping_bodies():
		if body is Player:
			if Touch.hero_in(body, rect, 0.0) and (body as Player).is_on_floor():
				return true
		elif body is PushBlock or body is Snail:
			return true
	return false


func _draw() -> void:
	draw_texture_rect_region(ART, Rect2(-8, -8, 16, 8), Rect2(16 if pressed else 0, 0, 16, 8))
