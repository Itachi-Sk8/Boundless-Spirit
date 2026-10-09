@tool
class_name Boar
extends CharacterBody2D
## A boar that walks back and forth, turning at walls and ledges, and charges when it sees the
## hero ahead on its level. Touching it is death. A charge carries on until something stops
## it: a wall leaves it dazed, a breakable wall shatters (opening the way), a ledge drops it,
## and thorns or water kill it (gone until the room resets). Origin at its feet.

enum State { WALK, ALERT, CHARGE, DAZED, DEAD }

const WORLD_LAYER := 1
const HAZARD_LAYER := 1 << 2
const PUSH_BLOCK_LAYER := 1 << 4
## Sheet rows (art/creatures/boar.png): idle (4), walk (6), run (6), hit (4).
const IDLE := 0
const WALK := 1
const RUN := 2
const HIT := 3
const SIZE := Vector2(28, 18)

## Which way it starts facing: 1 right, -1 left.
@export_enum("Left:-1", "Right:1") var facing := -1:
	set(value):
		facing = value
		if is_node_ready():
			sprite.flip_h = facing > 0
## Walk back and forth; off, it stands still until it sees the hero.
@export var walks := true
@export var walk_speed := 30.0
@export var charge_speed := 170.0
## How far ahead it sees the hero, in px (the hero must be within a tile or so of its level).
@export var sight_range := 160.0
## Seconds it snorts before charging.
@export var alert_time := 0.35
## Seconds it stays dazed after hitting a wall.
@export var dazed_time := 1.0
@export var gravity := 900.0

var state := State.WALK

var _start := Vector2.ZERO
var _start_facing := -1
var _timer := 0.0
var _anim: SheetAnim

@onready var sprite: Sprite2D = $Sprite
@onready var hurt: Area2D = $Hurt


func _ready() -> void:
	sprite.flip_h = facing > 0
	if Engine.is_editor_hint():
		return
	_start = global_position
	_start_facing = facing
	_anim = SheetAnim.new(sprite)
	_anim.play(WALK if walks else IDLE, 6 if walks else 4, 8.0)
	add_to_group(&"room_reset")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim.update(delta)
	if state == State.DEAD:
		if _anim.finished:
			hide()
		return
	velocity.y = minf(velocity.y + gravity * delta, 600.0)
	match state:
		State.WALK:
			velocity.x = facing * walk_speed if walks else 0.0
			if walks and is_on_floor() and (is_on_wall() or _ledge_ahead()):
				_turn()
			if _sees_hero():
				state = State.ALERT
				_timer = alert_time
				velocity.x = 0.0
				_anim.play(IDLE, 4, 12.0)
				Sfx.play(&"snort", -4.0)
		State.ALERT:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHARGE
				_anim.play(RUN, 6, 14.0)
		State.CHARGE:
			velocity.x = facing * charge_speed
		State.DAZED:
			velocity.x = 0.0
			_timer -= delta
			sprite.position.x = randi_range(-1, 1) if _timer > dazed_time - 0.3 else 0
			if _timer <= 0.0:
				sprite.position.x = 0.0
				state = State.WALK
				_anim.play(WALK if walks else IDLE, 6 if walks else 4, 8.0)
	move_and_slide()
	if state == State.CHARGE:
		_check_charge_hit()
	if _touching_hazard() or _fell_out():
		_die()


func reset_to_start() -> void:
	global_position = _start
	velocity = Vector2.ZERO
	facing = _start_facing
	state = State.WALK
	sprite.position = Vector2.ZERO
	hurt.set_collision_layer_value(3, true)
	_anim.play(WALK if walks else IDLE, 6 if walks else 4, 8.0, true, true)
	show()


func _check_charge_hit() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if absf(collision.get_normal().x) < 0.5:
			continue
		var wall := collision.get_collider() as BreakableWall
		if wall:
			wall.smash()
			return
		state = State.DAZED
		_timer = dazed_time
		_anim.play(HIT, 4, 8.0, false)
		Sfx.play(&"thud", -2.0)
		if Main.instance:
			Main.instance.camera.shake(2.0, 0.15)
		_turn()
		return


func _turn() -> void:
	facing = -facing


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	hurt.set_collision_layer_value(3, false)
	_anim.play(HIT, 4, 8.0, false, true)
	Sfx.play(&"squash", -4.0)


func _ledge_ahead() -> bool:
	var foot := global_position + Vector2(facing * (SIZE.x / 2.0 + 2.0), -2.0)
	var query := PhysicsRayQueryParameters2D.create(foot, foot + Vector2(0, 12), WORLD_LAYER | PUSH_BLOCK_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _sees_hero() -> bool:
	if Main.instance == null:
		return false
	var hero := Main.instance.player
	if hero.state_name == &"dead":
		return false
	var dx := (hero.global_position.x - global_position.x) * facing
	if dx < 0.0 or dx > sight_range or absf(hero.global_position.y - global_position.y) > 20.0:
		return false
	var eye := global_position + Vector2(0, -SIZE.y / 2.0)
	var query := PhysicsRayQueryParameters2D.create(eye, hero.global_position + Vector2(0, -8), WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _touching_hazard() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE - Vector2(6, 6)
	query.shape = rect
	query.transform = Transform2D(0.0, global_position + Vector2(0, -SIZE.y / 2.0))
	query.collision_mask = HAZARD_LAYER
	query.collide_with_areas = true
	query.exclude = [hurt.get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _fell_out() -> bool:
	return Main.instance != null and Main.instance.room != null \
			and global_position.y > Main.instance.room.world_bounds().end.y + 32.0
