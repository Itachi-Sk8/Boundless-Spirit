class_name Touch
## Confirms that the hero really overlaps a trigger before it acts. For one frame after a room
## loads, the physics engine can report the hero inside an area it is nowhere near (it pairs the
## new area with stale positions), so every trigger checks the actual geometry too.


## The world rectangle of a rectangle or circle collision shape.
static func shape_rect(shape_node: CollisionShape2D) -> Rect2:
	var center := shape_node.global_position
	var shape := shape_node.shape
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size
		return Rect2(center - size / 2.0, size)
	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return Rect2(center, Vector2.ZERO)


## True if `body` is the hero and its collision box overlaps `rect` (with `margin` px of slack).
static func hero_in(body: Node2D, rect: Rect2, margin := 1.0) -> bool:
	var hero := body as Player
	if hero == null:
		return false
	var size := hero.shape_size(hero.shape)
	var box := Rect2(hero.global_position + Vector2(-size.x / 2.0, -size.y), size)
	return box.grow(margin).intersects(rect)
