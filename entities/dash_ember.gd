class_name DashEmber
extends Area2D
## A glowing ember that refills the dash in midair. Goes dark once used and relights
## after a moment.

@export var relight_time := 2.0
@export var lit_color := Color(0.87, 0.44, 0.15)
@export var dark_color := Color(0.3, 0.27, 0.25)

var _lit := true
var _dark_left := 0.0


func _ready() -> void:
	add_to_group(&"room_reset")


func _physics_process(delta: float) -> void:
	if not _lit:
		_dark_left -= delta
		if _dark_left <= 0.0:
			_set_lit(true)
		return
	for body in get_overlapping_bodies():
		if body is Player and body.refill_dash():
			_dark_left = relight_time
			_set_lit(false)
			return


func reset_to_start() -> void:
	_set_lit(true)


func _set_lit(lit: bool) -> void:
	_lit = lit
	queue_redraw()


func _draw() -> void:
	var color := lit_color if _lit else dark_color
	var points := PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
	draw_colored_polygon(points, color)
	if _lit:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(2, 0), Vector2(0, 3),
				Vector2(-2, 0)]), color.lightened(0.5))
