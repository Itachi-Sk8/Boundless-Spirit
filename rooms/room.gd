class_name Room
extends Node2D
## A room: its terrain, spawn points, and everything that resets when the hero dies. The game
## (game/main.gd) places rooms in the world at their WorldMap origin and brings the hero and
## camera; rooms hold neither. Run a room on its own (F6) and the game starts in it.
##
## Nodes it expects: Terrain (TileMapLayer, usually a TerrainLayout) and Spawns (Marker2D
## children). Things that reset on death join the "room_reset" group and have reset_to_start().
## Props, Decor, Leaves, Entities, and Terrain are drawn on their color layers (WorldColor);
## anything in the "full_color" group keeps its color.

## Spirit Rooms: one run, always restarting from the start, with checkpoints ignored and the
## run timed.
@export var spirit_room := false
## The test room shows the debug overlay on arrival.
@export var debug_room := false
## Camera bounds in room coordinates. Left empty, they come from the terrain's area.
@export var bounds := Rect2()

var room_id: StringName = &""

@onready var terrain: TileMapLayer = $Terrain


func _ready() -> void:
	if get_tree().current_scene == self:
		# Run on its own: start the game in this room instead.
		GameState.pending_room_scene = scene_file_path
		get_tree().change_scene_to_file.call_deferred("res://game/main.tscn")
		return
	if bounds.size == Vector2.ZERO:
		bounds = _terrain_bounds()
	if not debug_room:
		_paint_color_layers()


## The room's area in world pixels.
func world_bounds() -> Rect2:
	return Rect2(global_position + bounds.position, bounds.size)


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var spawns := get_node_or_null(^"Spawns")
	if spawns:
		for marker in spawns.get_children():
			points.append((marker as Node2D).global_position)
	return points


## A named spawn point (e.g. "Start"), or Vector2.INF if there isn't one.
func named_spawn(spawn_name: StringName) -> Vector2:
	var marker := get_node_or_null(NodePath("Spawns/" + String(spawn_name))) as Node2D
	return marker.global_position if marker else Vector2.INF


## The spawn point closest to a world point, or the point itself if there are none.
func nearest_spawn(point: Vector2) -> Vector2:
	var best := point
	var best_distance := INF
	for spawn in spawn_points():
		var distance := spawn.distance_squared_to(point)
		if distance < best_distance:
			best = spawn
			best_distance = distance
	return best


## Put everything that resets on death back where it started.
func reset_room() -> void:
	get_tree().call_group(&"room_reset", &"reset_to_start")


## Put each part of the room on its color layer (see WorldColor): trees behind, decoration in
## front, the ground and everything on it, and the thorns.
func _paint_color_layers() -> void:
	var parts := {
		^"Props": WorldColor.Layer.TREES, ^"Decor": WorldColor.Layer.DECOR,
		^"Leaves": WorldColor.Layer.DECOR, ^"Entities": WorldColor.Layer.GROUND,
	}
	for path: NodePath in parts:
		var part := get_node_or_null(path)
		if part:
			WorldColor.paint(part, parts[path])
	WorldColor.paint(terrain, WorldColor.Layer.GROUND)
	if terrain is TerrainLayout and (terrain as TerrainLayout).hazards:
		(terrain as TerrainLayout).hazards.material = WorldColor.material(WorldColor.Layer.HAZARDS)


func _terrain_bounds() -> Rect2:
	var tile_size := Vector2(terrain.tile_set.tile_size)
	if terrain is TerrainLayout:
		return Rect2(Vector2.ZERO, Vector2((terrain as TerrainLayout).layout_size()) * tile_size)
	var used := terrain.get_used_rect()
	return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)
