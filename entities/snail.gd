@tool
class_name Snail
extends PushBlock
## A harmless snail that crawls along floors, walls, and ceilings, around every corner. When
## the hero comes near it hides in its shell, and the shell is a solid block: stand on it, or
## push and pull it like a push block. A shell hidden on a wall or ceiling drops to the floor.
## It comes out again once the hero has stayed away for a moment. Origin at its feet, on the
## surface it starts on.

enum Surface { FLOOR, CEILING, LEFT_WALL, RIGHT_WALL }
enum State { CRAWL, HIDING, HIDDEN, WAKING }

const ART := preload("res://art/creatures/snail.png")
const TILE := 16
const WORLD_LAYER := 1
## Sheet rows (art/creatures/snail.png): walk, hide, dead; eight frames each.
const WALK := 0
const HIDE := 1

## The surface it starts on (the solid side is under its feet).
@export var surface := Surface.FLOOR:
	set(value):
		surface = value
		_place_preview()
## Which way it goes around: clockwise moves right along a floor, left along a ceiling.
@export var clockwise := true:
	set(value):
		clockwise = value
		_place_preview()
## Crawling speed, in px/s.
@export var crawl_speed := 14.0
## Hides when the hero comes this close, in px...
@export var hide_distance := 40.0
## ...and comes out once the hero has been farther than this for `wake_delay` seconds.
@export var wake_distance := 64.0
@export var wake_delay := 1.5

var state := State.CRAWL

# The empty tile it's in, the way out of its surface (away from the solid side), and the way
# it's heading along the surface; all in tiles.
var _cell := Vector2i.ZERO
var _normal := Vector2i.UP
var _heading := Vector2i.RIGHT
# Points still to crawl through (world px) and the surface normal to take at each.
var _path: Array[Dictionary] = []
var _timer := 0.0
var _anim: SheetAnim
var _start_state := {}

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	_place_preview()
	if Engine.is_editor_hint():
		return
	super()
	_anim = SheetAnim.new(sprite)
	_set_surface_from_export()
	_start_state = {"cell": _cell, "normal": _normal, "heading": _heading}
	_crawl()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim.update(delta)
	var near := _hero_distance()
	match state:
		State.CRAWL:
			if near < hide_distance:
				_hide()
				return
			_crawl_step(delta)
		State.HIDING:
			super(delta)
			if _anim.finished:
				state = State.HIDDEN
				_timer = wake_delay
		State.HIDDEN:
			super(delta)
			_timer = wake_delay if near < wake_distance or not is_on_floor() else _timer - delta
			if _timer <= 0.0:
				state = State.WAKING
				_anim.play(HIDE, 8, 16.0, false, true)
				sprite.flip_v = false
		State.WAKING:
			_show_waking()
			if _anim.finished:
				_wake()


func reset_to_start() -> void:
	super()
	_cell = _start_state["cell"]
	_normal = _start_state["normal"]
	_heading = _start_state["heading"]
	_path.clear()
	_snap_to_surface()
	_crawl()


func _hide() -> void:
	state = State.HIDING
	_path.clear()
	# The shell is an upright block: stand it on the floor, or let it drop from a wall or ceiling.
	rotation = 0.0
	global_position = _cell_center(_cell) + Vector2(0, TILE / 2.0)
	velocity = Vector2.ZERO
	collision_layer = 1 << 4
	_anim.play(HIDE, 8, 16.0, false, true)
	Sfx.play(&"hide", -6.0)


func _wake() -> void:
	# Out again on whatever floor the shell came to rest on, lined up with the tiles.
	_cell = Vector2i(((global_position - Vector2(0, TILE / 2.0)) / TILE).floor())
	_normal = Vector2i.UP
	if _heading.x == 0:
		_heading = Vector2i.RIGHT if clockwise else Vector2i.LEFT
	_crawl()
	_path.append({"point": _surface_point(_cell, _normal), "normal": _normal})


func _crawl() -> void:
	state = State.CRAWL
	collision_layer = 0
	velocity = Vector2.ZERO
	_anim.play(WALK, 8, 8.0, true, true)


func _crawl_step(delta: float) -> void:
	if _path.is_empty():
		if not _solid(_cell - _normal):
			# Its surface is gone (a ledge crumbled): drop as a shell.
			_hide()
			return
		_plan_next()
	var step := crawl_speed * delta
	while step > 0.0 and not _path.is_empty():
		var goal: Vector2 = _path[0]["point"]
		var to_goal := global_position.distance_to(goal)
		if to_goal <= step:
			global_position = goal
			_normal = _path[0]["normal"]
			_path.pop_front()
			step -= to_goal
		else:
			global_position = global_position.move_toward(goal, step)
			step = 0.0
	rotation = Vector2(_normal).angle() + PI / 2.0
	sprite.flip_h = _heading == _turned(_normal, 1)


# Decide the next stretch from the tile it's in: straight on, up a wall in front (inside
# corner), or around the edge it's reached (outside corner).
func _plan_next() -> void:
	var ahead := _cell + _heading
	var corner := _cell_center(_cell) + Vector2(_heading) * (TILE / 2.0) - Vector2(_normal) * (TILE / 2.0)
	if _solid(ahead):
		var new_normal := -_heading
		_heading = _normal
		_path.append({"point": corner, "normal": new_normal})
		_path.append({"point": _surface_point(_cell, new_normal), "normal": new_normal})
	elif not _solid(ahead - _normal):
		var new_normal := _heading
		_heading = -_normal
		_cell = ahead - _normal
		_path.append({"point": corner, "normal": new_normal})
		_path.append({"point": _surface_point(_cell, new_normal), "normal": new_normal})
	else:
		_cell = ahead
		_path.append({"point": _surface_point(_cell, _normal), "normal": _normal})


func _show_waking() -> void:
	# Play the hiding animation backwards.
	sprite.frame = HIDE * sprite.hframes + (7 - (sprite.frame - HIDE * sprite.hframes))


func _set_surface_from_export() -> void:
	_normal = [Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT][surface]
	_heading = _turned(_normal, 1 if clockwise else -1)
	_cell = Vector2i(((global_position + Vector2(_normal) * (TILE / 2.0)) / TILE).floor())
	_snap_to_surface()


func _snap_to_surface() -> void:
	global_position = _surface_point(_cell, _normal)
	rotation = Vector2(_normal).angle() + PI / 2.0
	sprite.flip_h = _heading == _turned(_normal, 1)


# The heading that goes around clockwise (1) or counterclockwise (-1) for a surface normal.
func _turned(normal: Vector2i, way: int) -> Vector2i:
	return Vector2i(-normal.y, normal.x) * way


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _surface_point(cell: Vector2i, normal: Vector2i) -> Vector2:
	return _cell_center(cell) - Vector2(normal) * (TILE / 2.0)


func _solid(cell: Vector2i) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = _cell_center(cell)
	query.collision_mask = WORLD_LAYER
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _hero_distance() -> float:
	if Main.instance == null:
		return INF
	# From the middle of the hero's body.
	var hero := Main.instance.player
	return (hero.global_position + Vector2(0, -hero.tuning.stand_size.y / 2.0)).distance_to(global_position)


# In the editor, stand the art on its surface so it's placed right.
func _place_preview() -> void:
	if not is_node_ready() or not Engine.is_editor_hint():
		return
	var normal: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT][surface]
	rotation = Vector2(normal).angle() + PI / 2.0
	sprite.flip_h = _turned(normal, 1 if clockwise else -1) == _turned(normal, 1)


func _draw() -> void:
	pass # The sprite draws the snail; PushBlock's box isn't needed.
