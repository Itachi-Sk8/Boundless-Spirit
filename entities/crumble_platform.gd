@tool
class_name CrumblePlatform
extends StaticBody2D
## A rock ledge that shakes when stood on, then falls away, and comes back after a while.
## Origin at its top-left corner, so it sits on the tile grid. Resets when the room does.

const ATLAS := preload("res://art/tilesets/forest.png")
const ROCK_ROW := 1
# Rock terrain tiles for a one-tile-high strip (see TerrainLayout's edge bits).
const SINGLE := 15
const LEFT_END := 7
const MIDDLE := 3
const RIGHT_END := 11

## Width in tiles.
@export_range(1, 12) var width_tiles := 3:
	set(value):
		width_tiles = value
		_resize()
## Seconds it shakes before falling.
@export var shake_time := 0.45
## Seconds until it comes back after falling.
@export var return_time := 2.5

enum Phase { SOLID, SHAKING, GONE }

var phase := Phase.SOLID
var _timer := 0.0

@onready var shape: CollisionShape2D = $Shape
@onready var sensor: Area2D = $Sensor
@onready var sensor_shape: CollisionShape2D = $Sensor/Shape


func _ready() -> void:
	_resize()
	if not Engine.is_editor_hint():
		add_to_group(&"room_reset")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match phase:
		Phase.SOLID:
			if _hero_standing_on():
				phase = Phase.SHAKING
				_timer = shake_time
		Phase.SHAKING:
			_timer -= delta
			queue_redraw()
			if _timer <= 0.0:
				phase = Phase.GONE
				_timer = return_time
				shape.set_deferred(&"disabled", true)
				Sfx.play(&"crumble", -2.0)
				queue_redraw()
		Phase.GONE:
			_timer -= delta
			if _timer <= 0.0 and not _hero_in_the_way():
				reset_to_start()


func reset_to_start() -> void:
	phase = Phase.SOLID
	shape.set_deferred(&"disabled", false)
	queue_redraw()


func _hero_standing_on() -> bool:
	var rect := Touch.shape_rect(sensor_shape)
	for body in sensor.get_overlapping_bodies():
		if Touch.hero_in(body, rect) and (body as Player).is_on_floor():
			return true
	return false


func _hero_in_the_way() -> bool:
	var rect := Touch.shape_rect(sensor_shape)
	return sensor.get_overlapping_bodies().any(func(body: Node2D) -> bool: return Touch.hero_in(body, rect))


func _resize() -> void:
	if not is_node_ready():
		return
	var size := Vector2(width_tiles * 16, 16)
	(shape.shape as RectangleShape2D).size = size
	shape.position = size / 2.0
	# The sensor covers the top surface and the whole ledge, so it also tells when the hero
	# is in the way of it coming back.
	(sensor_shape.shape as RectangleShape2D).size = Vector2(size.x, size.y + 4)
	sensor_shape.position = Vector2(size.x / 2.0, size.y / 2.0 - 2.0)
	queue_redraw()


func _draw() -> void:
	if phase == Phase.GONE and not Engine.is_editor_hint():
		return
	var shake := Vector2.ZERO
	if phase == Phase.SHAKING:
		shake = Vector2(randi_range(-1, 1), randi_range(0, 1))
	for i in width_tiles:
		var tile := SINGLE
		if width_tiles > 1:
			tile = LEFT_END if i == 0 else (RIGHT_END if i == width_tiles - 1 else MIDDLE)
		draw_texture_rect_region(ATLAS, Rect2(Vector2(i * 16, 0) + shake, Vector2(16, 16)),
				Rect2(tile * 16, ROCK_ROW * 16, 16, 16))
	if phase == Phase.SHAKING:
		# Cracks spreading as it gets ready to fall.
		var progress := 1.0 - _timer / shake_time
		for i in width_tiles:
			var x := i * 16 + 4 + shake.x
			draw_line(Vector2(x, 2) , Vector2(x + 3, 2 + 10 * progress), Color(0.1, 0.07, 0.05), 1.0)
