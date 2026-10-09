@tool
class_name PlateDoor
extends AnimatableBody2D
## A stone door that slides open while something switches it on (a PressurePlate lists it in
## its targets) and shuts again when switched off. `inverted` makes it open by default and shut
## when switched on. Size it in tiles; origin at its top-left corner. Resets with the room.

const TILE := 16
const ATLAS := preload("res://art/tilesets/forest.png")
const ROCK_ROW := 1

## Size in tiles.
@export var size_tiles := Vector2i(1, 3):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
## Which way it slides to open.
@export_enum("Up", "Down", "Left", "Right") var opens_toward := 0
## Seconds to slide open or shut.
@export var slide_time := 0.35
## Open when switched off, shut when switched on.
@export var inverted := false
## Color of the rune line that shows it's linked to a plate.
@export var rune_color := Color(0.6, 0.88, 1.0)

var is_open := false

var _shape := RectangleShape2D.new()
var _owner_id := -1
var _home := Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	if Engine.is_editor_hint():
		return
	_home = position
	add_to_group(&"room_reset")
	if inverted:
		_set_open(true, false)


## Called by plates: on opens it (or shuts it, when inverted).
func set_active(on: bool) -> void:
	_set_open(on != inverted, true)


func reset_to_start() -> void:
	_set_open(inverted, false)


func _set_open(open: bool, animate: bool) -> void:
	if open == is_open and animate:
		return
	is_open = open
	if _tween:
		_tween.kill()
	var target := _home + (_slide_offset() if open else Vector2.ZERO)
	if animate:
		Sfx.play(&"door", -4.0)
		_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_tween.tween_property(self, ^"position", target, slide_time).set_trans(Tween.TRANS_QUAD)
	else:
		position = target
	queue_redraw()


func _slide_offset() -> Vector2:
	var size := Vector2(size_tiles * TILE)
	match opens_toward:
		1:
			return Vector2(0, size.y)
		2:
			return Vector2(-size.x, 0)
		3:
			return Vector2(size.x, 0)
	return Vector2(0, -size.y)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	var size := Vector2(size_tiles * TILE)
	_shape.size = size
	shape_owner_set_transform(_owner_id, Transform2D(0.0, size / 2.0))
	queue_redraw()


func _draw() -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			var mask := 0
			if y == 0:
				mask |= TerrainLayout.UP
			if y == size_tiles.y - 1:
				mask |= TerrainLayout.DOWN
			if x == 0:
				mask |= TerrainLayout.LEFT
			if x == size_tiles.x - 1:
				mask |= TerrainLayout.RIGHT
			draw_texture_rect_region(ATLAS, Rect2(x * TILE, y * TILE, TILE, TILE),
					Rect2(mask * TILE, ROCK_ROW * TILE, TILE, TILE))
	# A rune line down the middle, lit while open.
	var size := Vector2(size_tiles * TILE)
	var color := Color(rune_color, 0.95 if is_open else 0.45)
	if size.y >= size.x:
		draw_rect(Rect2(size.x / 2.0 - 1.0, 4.0, 2.0, size.y - 8.0), color)
	else:
		draw_rect(Rect2(4.0, size.y / 2.0 - 1.0, size.x - 8.0, 2.0), color)
