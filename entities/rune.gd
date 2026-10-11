@tool
class_name Rune
extends Node2D
## A rune carved into stone that glows from inside: a dark groove with a lit lower edge, filled
## with colored light that pulses. Move, scale, and recolor each one freely. Origin at the
## glyph's top-left corner; a glyph is 16×16 px. Always keeps its color in the grey world.

const SIZE := 16
const SHEET := preload("res://art/entities/runes.png")
const GLYPHS := 24
const GROOVE := Color(0.0, 0.0, 0.0, 0.6)
const EDGE := Color(1.0, 1.0, 1.0, 0.3)

## Which glyph, from the glyph sheet (8 per row).
@export_range(0, 23) var glyph := 0:
	set(value):
		glyph = clampi(value, 0, GLYPHS - 1)
		queue_redraw()
## The glyph sheet: 16×16 glyphs, 8 per row. Empty uses art/entities/runes.png. Inside a
## SpiritGate the gate's `glyph_sheet` sets this.
@export var sheet: Texture2D:
	set(value):
		sheet = value
		queue_redraw()
## The light's color. Inside a SpiritGate the gate's `rune_color` sets this, unless
## `own_color` is on.
@export var color := Color(0.95, 0.55, 0.22):
	set(value):
		color = value
		queue_redraw()
## Keep this rune's own color instead of the gate's.
@export var own_color := false
## Draw the groove and lit edge, so the rune looks cut into the stone.
@export var carved := true:
	set(value):
		carved = value
		queue_redraw()
## The light breathes in and out (all runes in step).
@export var pulse := true:
	set(value):
		pulse = value
		queue_redraw()
## How bright the light is at its brightest, 0 to 1.
@export_range(0.0, 1.0) var brightness := 0.9:
	set(value):
		brightness = value
		queue_redraw()


func _ready() -> void:
	add_to_group(&"full_color")


func _process(_delta: float) -> void:
	if pulse:
		queue_redraw()


func _draw() -> void:
	var glyphs := sheet if sheet else SHEET
	var region := Rect2((glyph % 8) * SIZE, floori(glyph / 8.0) * SIZE, SIZE, SIZE)
	if carved:
		draw_texture_rect_region(glyphs, Rect2(1, 1, SIZE, SIZE), region, EDGE)
		draw_texture_rect_region(glyphs, Rect2(0, 0, SIZE, SIZE), region, GROOVE)
	var alpha := brightness
	if pulse:
		var time := Time.get_ticks_msec() / 1000.0
		alpha *= (0.6 + 0.3 * sin(time * 1.8)) / 0.9
	draw_texture_rect_region(glyphs, Rect2(0, 0, SIZE, SIZE), region, Color(color, color.a * alpha))
