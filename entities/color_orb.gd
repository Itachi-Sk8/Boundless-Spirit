class_name ColorOrb
extends Area2D
## A lost color floating at the end of a Spirit Room. Touching it ends the run: the game
## (Main.collect_color) lets the hero land, then flows the color into it. Gone for good once
## its color is back. Always drawn in full color.

## Which color, as a GameState.SpiritColor value.
@export var color := 0

const TINTS: Array[Color] = [
	Color(0.87, 0.44, 0.15), Color(0.98, 0.95, 0.21), Color(0.42, 0.75, 0.19),
	Color(0.81, 0.31, 0.31), Color(0.59, 0.09, 0.6), Color(0.37, 0.8, 0.89),
]

var _collected := false
var _time := 0.0
var _home := Vector2.ZERO


func _ready() -> void:
	if GameState.has_color(color as GameState.SpiritColor):
		queue_free()
		return
	add_to_group(&"full_color")
	_home = position
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if not _collected:
		position.y = _home.y + roundf(sin(_time * 2.5) * 3.0)
	queue_redraw()


## Let go after a touch that didn't end in the color being taken (the hero died first).
func release() -> void:
	_collected = false


## Fly into the hero's chest and vanish. The game waits on this.
func fly_into(hero: Player) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, ^"global_position", hero.global_position + Vector2(0, -16), 0.7)
	tween.parallel().tween_property(self, ^"scale", Vector2(0.3, 0.3), 0.7)
	await tween.finished
	hero.sprite.modulate = Color(3.0, 3.0, 3.0)
	var flash := hero.create_tween()
	flash.tween_property(hero.sprite, ^"modulate", Color.WHITE, 0.5)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _collected or not Touch.hero_in(body, Touch.shape_rect($Shape)):
		return
	_collected = true
	if Main.instance:
		Main.instance.collect_color(self)
	else:
		GameState.set_color(color as GameState.SpiritColor, true)
		queue_free()


func _draw() -> void:
	var tint := TINTS[color]
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(Vector2.ZERO, 11.0 + pulse * 2.0, Color(tint, 0.18))
	draw_circle(Vector2.ZERO, 8.0, Color(tint, 0.35))
	draw_circle(Vector2.ZERO, 5.0, tint)
	draw_circle(Vector2(-1, -1), 2.5, tint.lightened(0.6))
