class_name Backdrop
extends Node2D
## The sky and two strips of distant forest behind every room. A child of the camera, so it
## stays on screen; the strips scroll slower than the camera for depth.

## How much of the camera's movement each strip follows (0 stays put, 1 moves with the world).
@export var far_factor := 0.12
@export var mid_factor := 0.3
## Screen y of each strip's top when the camera is at the bottom of its room.
@export var far_top := -112.0
@export var mid_top := -62.0
## Rising in a tall room lowers the strips a little, as if they were far away.
@export var vertical_factor := 0.08

## The current room's bottom edge in world pixels, set by the game on each room change.
var room_bottom := 0.0

@onready var sky: Sprite2D = $Sky
@onready var far: Sprite2D = $Far
@onready var mid: Sprite2D = $Mid


func _ready() -> void:
	# The three back layers of the world's color (see WorldColor).
	sky.material = WorldColor.material(WorldColor.Layer.SKY)
	far.material = WorldColor.material(WorldColor.Layer.FAR_HILLS)
	mid.material = WorldColor.material(WorldColor.Layer.NEAR_FOREST)


func _process(_delta: float) -> void:
	var camera := get_parent() as Camera2D
	if camera == null:
		return
	var view := get_viewport_rect().size
	var center := camera.global_position
	var rise := maxf(0.0, room_bottom - (center.y + view.y / 2.0))
	_place(far, center.x * far_factor, far_top + rise * vertical_factor, view)
	_place(mid, center.x * mid_factor, mid_top + rise * vertical_factor * 2.0, view)


## Scroll a repeating strip: shift it left by `scroll` (wrapped to its width).
func _place(strip: Sprite2D, scroll: float, top: float, view: Vector2) -> void:
	var width := float(strip.texture.get_width())
	strip.position = Vector2(-view.x / 2.0 - fposmod(scroll, width), top).round()


## Tint the strips, e.g. warmer in autumn regions. Shows as their layers regain color.
func set_tint(tint: Color) -> void:
	far.modulate = tint.lerp(Color.WHITE, 0.5)
	mid.modulate = tint
