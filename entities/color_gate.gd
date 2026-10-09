@tool
class_name ColorGate
extends StaticBody2D
## A rock wall sealed by a color: it shows a faint trace of that color (doc: "gates hint at
## their color") and falls away once the color is back. Origin at its top-left corner.

const ATLAS := preload("res://art/tilesets/forest.png")
const ROCK_ROW := 1

## Which color opens it, as a GameState.SpiritColor value.
@export var color := 0:
	set(value):
		color = value
		queue_redraw()
## Size in tiles.
@export var size_tiles := Vector2i(2, 4):
	set(value):
		size_tiles = value
		_resize()

var _open := false
var _time := 0.0

@onready var shape: CollisionShape2D = $Shape
## The color trace draws above the world's grey pass; the rock itself stays grey.
@onready var trace: Sprite2D = $Trace


func _ready() -> void:
	_resize()
	if Engine.is_editor_hint():
		return
	if GameState.has_color(color as GameState.SpiritColor):
		_set_open()
	else:
		GameState.colors_changed.connect(_on_colors_changed)


func _process(delta: float) -> void:
	_time += delta
	var tint: Color = ColorOrb.TINTS[color]
	tint.a = 0.35 + 0.2 * sin(_time * 2.0)
	trace.modulate = tint


func _on_colors_changed() -> void:
	if not _open and GameState.has_color(color as GameState.SpiritColor):
		Sfx.play(&"crumble")
		var tween := create_tween()
		tween.tween_property(self, ^"modulate:a", 0.0, 0.6)
		_set_open()


func _set_open() -> void:
	_open = true
	shape.set_deferred(&"disabled", true)
	if modulate.a > 0.99:
		hide()
	else:
		trace.hide()


func _resize() -> void:
	if not is_node_ready():
		return
	var size := Vector2(size_tiles) * 16.0
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	trace.position = size / 2.0 + Vector2(0, 8)
	queue_redraw()


func _draw() -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			var mask := 0
			mask |= 1 if y == 0 else 0
			mask |= 2 if y == size_tiles.y - 1 else 0
			mask |= 4 if x == 0 else 0
			mask |= 8 if x == size_tiles.x - 1 else 0
			draw_texture_rect_region(ATLAS, Rect2(x * 16, y * 16, 16, 16), Rect2(mask * 16, ROCK_ROW * 16, 16, 16))
