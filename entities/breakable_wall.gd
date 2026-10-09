@tool
class_name BreakableWall
extends StaticBody2D
## A cracked rock wall that shatters when the hero dashes into it, or when a charging boar
## slams into it. With a `flag` set it stays broken for good (saved); without one it comes back
## when the room resets. Size it in tiles; origin at its top-left corner.

const TILE := 16
const ATLAS := preload("res://art/tilesets/forest.png")
const CRACKS := preload("res://art/objects/cracks.png")
const ROCK_ROW := 1

## Size in tiles.
@export var size_tiles := Vector2i(1, 3):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
## The saved flag that keeps it broken. Leave empty for a wall that comes back on reset.
@export var flag := &""
## A dash breaks it (the hero dashes on through; see Player.smash_breakables).
@export var dash_breaks := true

var broken := false

var _shape := RectangleShape2D.new()
var _owner_id := -1

@onready var debris: CPUParticles2D = $Debris


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"room_reset")
	if flag != &"" and GameState.has_flag(flag):
		_set_broken(true)


## Shatter it (dash, boar). Saves its flag if it has one.
func smash() -> void:
	if broken:
		return
	_set_broken(true)
	debris.emitting = true
	Sfx.play(&"break")
	if Main.instance:
		Main.instance.camera.shake(2.0, 0.15)
	if flag != &"":
		GameState.set_flag(flag)
		GameState.save_game()


func reset_to_start() -> void:
	if flag != &"" and GameState.has_flag(flag):
		return
	_set_broken(false)


func _set_broken(value: bool) -> void:
	broken = value
	set_collision_layer_value(1, not value)
	queue_redraw()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _owner_id < 0:
		_owner_id = create_shape_owner(self)
		shape_owner_add_shape(_owner_id, _shape)
	var size := Vector2(size_tiles * TILE)
	_shape.size = size
	shape_owner_set_transform(_owner_id, Transform2D(0.0, size / 2.0))
	if is_node_ready():
		debris.position = size / 2.0
		debris.emission_rect_extents = size / 2.0
	queue_redraw()


func _draw() -> void:
	if broken:
		return
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
			var cell := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_texture_rect_region(ATLAS, cell, Rect2(mask * TILE, ROCK_ROW * TILE, TILE, TILE))
			draw_texture(CRACKS, cell.position)
