class_name Room
extends Node2D
## A room: its tiles, camera bounds, spawn point, and everything that resets when the hero
## dies. Each room is its own scene copied from rooms/_template/. Nodes it expects:
## Tiles (TileMapLayer), Spawn (Marker2D), Player, and Camera (GameCamera).

## Falling this far below the room's bottom edge is a death, in px.
const PIT_MARGIN := 16.0

## Camera and pit bounds. Left empty, they come from the area painted on Tiles.
@export var bounds := Rect2()

@onready var tiles: TileMapLayer = $Tiles
@onready var spawn: Marker2D = $Spawn
@onready var player: Player = $Player
@onready var camera: GameCamera = $Camera


func _ready() -> void:
	if bounds.size == Vector2.ZERO:
		bounds = _painted_bounds()
	player.global_position = spawn.global_position
	player.died.connect(_on_player_died)
	camera.setup(player, bounds)


func _physics_process(_delta: float) -> void:
	if player.global_position.y > bounds.end.y + PIT_MARGIN:
		player.die()


## Put the hero back at the spawn point with the room reset, as after a death.
func respawn_player() -> void:
	get_tree().call_group(&"room_reset", &"reset_to_start")
	player.respawn(spawn.global_position)
	camera.snap_to_target()


func _painted_bounds() -> Rect2:
	var used := tiles.get_used_rect()
	var tile_size := Vector2(tiles.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)


func _on_player_died() -> void:
	GameState.add_death()
	respawn_player()
