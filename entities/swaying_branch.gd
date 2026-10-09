@tool
class_name SwayingBranch
extends AnimatableBody2D
## A branch to stand on that sways back and forth in a fixed rhythm, dipping a little at each
## end of its swing, and carries the hero with it. Jump up through it from below. Origin at the
## top-left of its resting spot; the editor draws its swing.

const TILE := 16
const ART := preload("res://art/objects/branch.png")
const THICKNESS := 6.0

## Length in tiles.
@export_range(1, 16) var width_tiles := 3:
	set(value):
		width_tiles = value
		_rebuild()
## How far it swings each way, in px.
@export var sway_distance := 24.0:
	set(value):
		sway_distance = value
		queue_redraw()
## Seconds for a full swing there and back.
@export var period := 3.0
## How far it dips at the ends of its swing, in px.
@export var dip := 4.0
## Shifts where in the swing it starts, 0 to 1, so branches side by side can differ.
@export_range(0.0, 1.0) var phase := 0.0

var _shape := RectangleShape2D.new()
var _owner_id := -1
var _home := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	if Engine.is_editor_hint():
		return
	_home = position


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	position = _home + offset_at(_time)


## Where the branch is relative to its resting spot `time` seconds into the room.
func offset_at(time: float) -> Vector2:
	var angle := TAU * (time / period + phase)
	var swing := sin(angle)
	return Vector2(swing * sway_distance, swing * swing * dip).round()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
		shape_owner_set_one_way_collision(_owner_id, true)
		# As a CollisionShape2D does by default; with no margin, nothing lands on it.
		shape_owner_set_one_way_collision_margin(_owner_id, 1.0)
	_shape.size = Vector2(width_tiles * TILE, THICKNESS)
	shape_owner_set_transform(_owner_id, Transform2D(0.0, Vector2(width_tiles * TILE / 2.0, THICKNESS / 2.0)))
	queue_redraw()


func _draw() -> void:
	for i in width_tiles:
		var piece := 0 if i == 0 else (2 if i == width_tiles - 1 else 1)
		if width_tiles == 1:
			piece = 2
		draw_texture_rect_region(ART, Rect2(i * TILE, 0, TILE, TILE), Rect2(piece * TILE, 0, TILE, TILE))
	if Engine.is_editor_hint():
		var length := width_tiles * TILE
		var guide := Color(1, 1, 1, 0.35)
		draw_rect(Rect2(-sway_distance, dip, length, THICKNESS), guide, false, 1.0)
		draw_rect(Rect2(sway_distance, dip, length, THICKNESS), guide, false, 1.0)
