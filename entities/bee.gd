@tool
class_name Bee
extends Node2D
## A bee that flies a fixed patrol loop and dives straight down when the hero passes beneath
## it, after a short buzzing warning. Touching it is death. A dive that ends in thorns or
## water kills it (gone until the room resets); one that hits the ground leaves it dazed, then
## it flies back up and carries on. Origin at the bee, at the first point of its loop; the
## editor draws the loop and the strip beneath that sets off a dive.

enum State { PATROL, WARN, DIVE, DAZED, RETURN, DEAD }

const ART := preload("res://art/creatures/bee.png")
const WORLD_LAYER := 1
const HAZARD_LAYER := 1 << 2
const PUSH_BLOCK_LAYER := 1 << 4
## Sheet rows (art/creatures/bee.png): fly, attack, hit; four frames each.
const FLY := 0
const ATTACK := 1
const HIT := 2
const BODY_RADIUS := 6.0

## The loop it flies, as points relative to where it starts (the first should be 0, 0).
@export var patrol := PackedVector2Array([Vector2.ZERO, Vector2(96, 0)]):
	set(value):
		patrol = value
		queue_redraw()
## Patrol speed, in px/s.
@export var speed := 40.0
## How far below it a dive reaches, in px, and how far to each side of it the hero sets it off.
@export var dive_range := 160.0:
	set(value):
		dive_range = value
		queue_redraw()
@export var dive_half_width := 10.0:
	set(value):
		dive_half_width = value
		queue_redraw()
## Seconds of buzzing before it dives.
@export var warn_time := 0.4
@export var dive_speed := 280.0
## Seconds it stays dazed after hitting the ground.
@export var dazed_time := 0.7
@export var return_speed := 70.0

var state := State.PATROL

var _start := Vector2.ZERO
var _target := 1
var _timer := 0.0
var _dive_from := Vector2.ZERO
var _anim: SheetAnim

@onready var sprite: Sprite2D = $Sprite
@onready var hurt: Area2D = $Hurt


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_start = global_position
	_anim = SheetAnim.new(sprite)
	_anim.play(FLY, 4, 14.0)
	add_to_group(&"room_reset")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim.update(delta)
	match state:
		State.PATROL:
			_patrol(delta)
			if _hero_below():
				state = State.WARN
				_timer = warn_time
				_anim.play(ATTACK, 4, 16.0)
				Sfx.play(&"buzz", -6.0)
		State.WARN:
			_timer -= delta
			sprite.position.x = randi_range(-1, 1)
			if _timer <= 0.0:
				sprite.position.x = 0.0
				state = State.DIVE
				_dive_from = global_position
		State.DIVE:
			global_position.y += dive_speed * delta
			if _touching(HAZARD_LAYER):
				_die()
			elif _touching(WORLD_LAYER | PUSH_BLOCK_LAYER):
				global_position.y -= dive_speed * delta
				state = State.DAZED
				_timer = dazed_time
				_anim.play(HIT, 4, 8.0)
		State.DAZED:
			_timer -= delta
			if _timer <= 0.0:
				state = State.RETURN
				_anim.play(FLY, 4, 14.0)
		State.RETURN:
			global_position = global_position.move_toward(_dive_from, return_speed * delta)
			if global_position.is_equal_approx(_dive_from):
				state = State.PATROL
		State.DEAD:
			if _anim.finished:
				hide()


func reset_to_start() -> void:
	global_position = _start
	_target = 1 if patrol.size() > 1 else 0
	state = State.PATROL
	sprite.position = Vector2.ZERO
	hurt.set_collision_layer_value(3, true)
	_anim.play(FLY, 4, 14.0, true, true)
	show()


func _patrol(delta: float) -> void:
	if patrol.size() < 2:
		return
	var goal := _start + patrol[_target]
	var before := global_position.x
	global_position = global_position.move_toward(goal, speed * delta)
	if global_position.x != before:
		sprite.flip_h = global_position.x > before
	if global_position.is_equal_approx(goal):
		_target = (_target + 1) % patrol.size()


func _die() -> void:
	state = State.DEAD
	hurt.set_collision_layer_value(3, false)
	_anim.play(HIT, 4, 10.0, false, true)
	Sfx.play(&"squash", -4.0)


func _hero_below() -> bool:
	if Main.instance == null:
		return false
	var hero := Main.instance.player
	if hero.state_name == &"dead":
		return false
	var zone := Rect2(global_position + Vector2(-dive_half_width, 0), Vector2(dive_half_width * 2.0, dive_range))
	if not Touch.hero_in(hero, zone, 0.0):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, hero.global_position + Vector2(0, -8), WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# Does its body overlap anything on `mask` (other than its own sting)?
func _touching(mask: int) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = mask
	query.collide_with_areas = true
	query.exclude = [hurt.get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var guide := Color(1, 0.85, 0.3, 0.6)
	for i in patrol.size():
		draw_line(patrol[i], patrol[(i + 1) % patrol.size()], guide, 1.0)
		draw_circle(patrol[i], 2.0, guide)
	draw_rect(Rect2(-dive_half_width, 0, dive_half_width * 2.0, dive_range), Color(1, 0.4, 0.3, 0.15))
