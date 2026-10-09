@tool
extends Node2D
## The whole world in the editor: every room drawn where the game puts it, outlined and
## labeled, so you can see how rooms line up and where a new one fits. Overlapping rooms are
## outlined in red. Open rooms/_world_view.tscn; press Refresh after saving a room. Nothing
## here is saved: it only shows the room scenes.

const TILE := 16
const OUTLINE := Color(1.0, 0.9, 0.4, 0.9)
const SPIRIT_OUTLINE := Color(0.95, 0.55, 0.22, 1.0)
const OVERLAP := Color(1.0, 0.15, 0.15, 1.0)

## Reread the room scenes and redraw them.
@export_tool_button("Refresh", "Reload") var refresh_button := refresh
## Draw each room's art, not just its outline (slower with many rooms).
@export var show_rooms := true:
	set(value):
		show_rooms = value
		refresh()


func _ready() -> void:
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if child.get_meta(&"world_view", false):
			child.queue_free()
	WorldMap.reload()
	if show_rooms:
		for id: StringName in WorldMap.rooms():
			var room: Node2D = (load(WorldMap.scene_of(id)) as PackedScene).instantiate()
			room.position = WorldMap.rect_px(id).position
			room.set_meta(&"world_view", true)
			add_child(room, false, Node.INTERNAL_MODE_BACK)
	queue_redraw()


func _draw() -> void:
	var overlapping := {}
	for pair: Array in WorldMap.overlaps():
		overlapping[pair[0]] = true
		overlapping[pair[1]] = true
	var font := ThemeDB.fallback_font
	for id: StringName in WorldMap.rooms():
		var rect := WorldMap.rect_px(id)
		var color := OUTLINE
		if WorldMap.rooms()[id]["spirit_room"]:
			color = SPIRIT_OUTLINE
		if overlapping.has(id):
			color = OVERLAP
		draw_rect(rect, color, false, 2.0)
		var origin: Vector2i = WorldMap.rooms()[id]["origin"]
		var label := "%s  (%d, %d)  %dx%d" % [id, origin.x, origin.y, rect.size.x / TILE, rect.size.y / TILE]
		draw_string(font, rect.position + Vector2(6, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
