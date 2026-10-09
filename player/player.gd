class_name Player
extends CharacterBody2D
## The hero. Hand-written movement run by a state machine, one small script per state in
## player/states/. This script holds what the states share: input, timers, ability charges,
## collision shapes, and the moves that several states can start (jump, dash, climb...).

signal died
signal state_changed(state_name: StringName)

enum Shape { STAND, CROUCH, SLIDE }

const STATE_SCRIPTS := {
	&"idle": preload("res://player/states/idle.gd"),
	&"run": preload("res://player/states/run.gd"),
	&"crouch": preload("res://player/states/crouch.gd"),
	&"jump": preload("res://player/states/jump.gd"),
	&"fall": preload("res://player/states/fall.gd"),
	&"dash": preload("res://player/states/dash.gd"),
	&"wall_slide": preload("res://player/states/wall_slide.gd"),
	&"slide": preload("res://player/states/slide.gd"),
	&"ledge_grab": preload("res://player/states/ledge_grab.gd"),
	&"climb": preload("res://player/states/climb.gd"),
	&"spirit_phase": preload("res://player/states/spirit_phase.gd"),
	&"push": preload("res://player/states/push.gd"),
	&"dead": preload("res://player/states/dead.gd"),
}

## Shader switch for each color, indexed by GameState.SpiritColor.
const PART_PARAMS: Array[StringName] = [
	&"torso_orange", &"back_leg_yellow", &"back_arm_green",
	&"front_leg_red", &"front_arm_purple", &"head_blue",
]

## Collision layer bits (see Project Settings > Layer Names > 2D Physics).
const HAZARD_LAYER := 1 << 2
const VINE_LAYER := 1 << 5

## Timers count down in floating point; anything under this counts as run out, so a
## 0.15 s timer lasts exactly 9 frames rather than sometimes 10.
const EPSILON := 0.0001

## Vines are grabbed with a small box at the chest, this far above the feet.
const VINE_SENSOR_HEIGHT := 14.0
const VINE_SENSOR_SIZE := Vector2(4, 4)

## Where the sprite sits relative to the feet (the art's feet are 16 px below its center).
const SPRITE_OFFSET := Vector2(0, -16)

## Landing faster than this plays the landing sound, in px/s.
const LAND_SOUND_SPEED := 120.0

## How far below a ledge's top the feet hang. Set by the art: in the ledge_hang frame the
## hand is 29 px above the feet.
const LEDGE_HANG_DROP := 29.0

@export var tuning: PlayerTuning

## 1 when facing right, -1 when facing left.
var facing := 1
## Digital move input: each axis is -1, 0, or 1.
var move_input := Vector2.ZERO
var air_dashes_left := 0
var has_air_jump := false
var spirit_ready := false
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jump_hold_timer := 0.0
var jump_hold_speed := 0.0
## Animation the jump state plays: jump, or air_spin for a double jump.
var jump_anim: StringName = &"jump"
## Side of the last wall jump since landing: 1 right, -1 left, 0 none.
var last_wall_jump_side := 0
var ledge_regrab_timer := 0.0
var shape := Shape.STAND
var state_name: StringName = &""
## True while crouched and still long enough to peek the camera down.
var peeking := false
## While frozen the hero ignores input and stops moving, keeping its velocity: used during
## room transitions and the color unlock.
var frozen := false
## While input is locked the hero ignores the controls but still falls and lands: used after
## touching a color orb, so the color is absorbed on the ground.
var input_locked := false:
	set(value):
		input_locked = value
		if value:
			jump_hold_timer = 0.0
			jump_buffer_timer = 0.0
## The spirit during Spirit Phase, so the camera can follow it.
var spirit: Node2D
## Filled by try_ledge_grab() for the ledge_grab state.
var ledge_hang_position := Vector2.ZERO
var ledge_top_position := Vector2.ZERO
## Filled by try_push() for the push state.
var push_block: PushBlock
var push_side := 0
## Pushes from wind gusts and waterfalls this frame (see add_push), cleared after moving.
var push_drift := 0.0
var push_lift := 0.0

var _lock_timer := 0.0
var _lock_side := 0
var _states := {}
var _state: PlayerState
# Reused for overlap checks. Hazards and vines are checked with direct queries every frame
# rather than Area2D signals: an Area2D never reports tile collision layers, and a query is
# exact to the frame.
var _query := PhysicsShapeQueryParameters2D.new()
var _query_rect := RectangleShape2D.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Body


func _ready() -> void:
	# Own copies, so resizing them never touches another instance.
	body_shape.shape = RectangleShape2D.new()
	sprite.material = sprite.material.duplicate()
	_query.shape = _query_rect
	_query.exclude = [get_rid()]
	for id: StringName in STATE_SCRIPTS:
		_states[id] = STATE_SCRIPTS[id].new(self)
	GameState.colors_changed.connect(_update_colors)
	set_shape(Shape.STAND)
	_update_colors()
	refill()
	change_state(&"idle")


# The game draws at screen resolution (so text is sharp), so keep the art on whole game
# pixels: without this the hero could be drawn between the pixels of the world around it.
func _process(_delta: float) -> void:
	sprite.position = SPRITE_OFFSET + (global_position.round() - global_position)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if input_locked:
		_fall_without_control(delta)
	else:
		_read_input(delta)
		_state.physics_update(delta)
	if state_name != &"dead" and touching_hazard():
		die()
	push_drift = 0.0
	push_lift = 0.0
	_update_spent_parts()


func change_state(next: StringName) -> void:
	var previous := state_name
	if _state:
		_state.exit()
	state_name = next
	_state = _states[next]
	_state.enter(previous)
	state_changed.emit(next)


func can(color: GameState.SpiritColor) -> bool:
	return GameState.has_color(color)


# --- Input -------------------------------------------------------------------------------

## Horizontal input, minus any direction locked out after a wall jump.
func input_x() -> float:
	if _lock_timer > EPSILON and move_input.x == _lock_side:
		return 0.0
	return move_input.x


func update_facing() -> void:
	if input_x() != 0.0:
		facing = int(input_x())


## Ignore input toward `side` for `time` seconds.
func lock_input_toward(side: int, time: float) -> void:
	_lock_side = side
	_lock_timer = time


func _read_input(delta: float) -> void:
	move_input = Vector2(_digital(&"move_left", &"move_right"), _digital(&"move_up", &"move_down"))
	_lock_timer = maxf(_lock_timer - delta, 0.0)
	ledge_regrab_timer = maxf(ledge_regrab_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = tuning.jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)


func _digital(negative: StringName, positive: StringName) -> float:
	var value := Input.get_axis(negative, positive)
	return signf(value) if absf(value) >= 0.5 else 0.0


# --- Motion ------------------------------------------------------------------------------

## Move toward `top_speed` in the input direction, using ground or air rates.
func accelerate_x(delta: float, top_speed: float) -> void:
	if _lock_timer > EPSILON and move_input.x == _lock_side:
		return # A wall jump's kick carries on untouched while input is locked.
	var target := input_x() * top_speed
	var rate: float
	# On a jump's first frame is_on_floor() is still true; moving up counts as airborne.
	if is_on_floor() and velocity.y >= 0.0:
		var turning := target != 0.0 and velocity.x != 0.0 and signf(target) != signf(velocity.x)
		rate = tuning.ground_accel if target != 0.0 and not turning else tuning.ground_decel
	elif target != 0.0 and absf(velocity.x) > top_speed and signf(velocity.x) == signf(target):
		rate = tuning.air_over_speed_decel
	else:
		rate = tuning.air_accel if target != 0.0 else tuning.air_decel
	velocity.x = move_toward(velocity.x, target, rate * delta)


func apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + tuning.gravity * delta, tuning.max_fall_speed)


## Gravity and landing with no input, easing to a stop sideways.
func _fall_without_control(delta: float) -> void:
	var rate := tuning.ground_decel if is_on_floor() else tuning.air_decel
	velocity.x = move_toward(velocity.x, 0.0, rate * delta)
	apply_gravity(delta)
	move(delta)
	play(&"idle" if is_on_floor() else &"fall")


## move_and_slide() plus corner correction and coyote time. States move through this.
func move(delta: float) -> void:
	if velocity.y < 0.0:
		_correct_corner(delta)
	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	# Wind carries the hero sideways like a moving walkway, and pushes up or down on its speed.
	# Pressing down (a waterfall) also cuts a held jump short.
	if push_lift > 0.0:
		jump_hold_timer = 0.0
	velocity.y += push_lift * delta
	velocity.x += push_drift
	move_and_slide()
	if push_drift != 0.0:
		velocity.x = 0.0 if is_on_wall() else velocity.x - push_drift
	if is_on_floor() and not was_on_floor and fall_speed > LAND_SOUND_SPEED:
		Sfx.play(&"land", -4.0)
	if is_on_floor():
		coyote_timer = tuning.coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)


## Clipping a ceiling corner by a few px slides the hero around it instead of stopping the jump.
func _correct_corner(delta: float) -> void:
	var rise := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, rise):
		return
	var first := -1 if velocity.x < 0.0 else 1
	for offset in range(1, tuning.corner_correction + 1):
		for side: int in [first, -first]:
			var shift := Vector2(offset * side, 0.0)
			if not test_move(global_transform, shift) \
					and not test_move(global_transform.translated(shift), rise):
				global_position += shift
				return


## Shatter any breakable wall the last move ran into (dashes do this). True if one broke.
func smash_breakables() -> bool:
	var smashed := false
	for i in get_slide_collision_count():
		var wall := get_slide_collision(i).get_collider() as BreakableWall
		if wall and wall.dash_breaks and not wall.broken:
			wall.smash()
			smashed = true
	return smashed


## Wind gusts and waterfalls call this every physics frame the hero is in them: `force.x`
## carries the hero sideways (px/s), `force.y` changes its vertical speed (px/s², up is negative).
func add_push(force: Vector2) -> void:
	push_drift += force.x
	push_lift += force.y


## Bounce flowers call this: throw the hero straight up at `speed` px/s, like a jump that can't
## be cut short, refilling the dash and double jump when `refill_charges` is set.
func launch(speed: float, refill_charges := true) -> void:
	if refill_charges:
		refill()
	velocity.y = -speed
	jump_hold_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	jump_anim = &"jump"
	change_state(&"jump")


# --- Charges -----------------------------------------------------------------------------

## Ground states call this every frame: landing refills the dash, double jump, and spirit.
func refill() -> void:
	air_dashes_left = tuning.air_dashes
	has_air_jump = true
	spirit_ready = true
	last_wall_jump_side = 0


## Dash embers call this. Returns true if it refilled anything.
func refill_dash() -> bool:
	if not can(GameState.SpiritColor.ORANGE) or air_dashes_left >= tuning.air_dashes:
		return false
	air_dashes_left = tuning.air_dashes
	return true


# --- Moves several states can start. Each returns true if it changed state. ---------------

func try_ground_moves() -> bool:
	return try_spirit() or try_dash() or try_climb() or try_ground_jump() or try_slide() \
			or try_push()


func try_air_moves() -> bool:
	return try_spirit() or try_dash() or try_climb() or try_air_jump() or try_ledge_grab() \
			or try_wall_slide()


func start_jump(speed: float, hold_time: float, anim: StringName = &"jump") -> void:
	velocity.y = -speed
	jump_hold_speed = speed
	jump_hold_timer = hold_time
	jump_anim = anim
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func try_ground_jump() -> bool:
	if jump_buffer_timer <= EPSILON or not (is_on_floor() or coyote_timer > EPSILON):
		return false
	start_jump(tuning.jump_speed, tuning.jump_hold_time)
	Sfx.play(&"jump")
	change_state(&"jump")
	return true


## In the air a jump is, in order: a late (coyote) jump, a wall jump, or a double jump.
func try_air_jump() -> bool:
	if jump_buffer_timer <= EPSILON:
		return false
	if coyote_timer > EPSILON:
		return try_ground_jump()
	if try_wall_jump():
		return true
	if has_air_jump and can(GameState.SpiritColor.YELLOW):
		has_air_jump = false
		start_jump(tuning.double_jump_speed, tuning.double_jump_hold_time, &"air_spin")
		Sfx.play(&"double_jump")
		change_state(&"jump")
		return true
	return false


func try_wall_jump() -> bool:
	if not can(GameState.SpiritColor.GREEN):
		return false
	var side := wall_side()
	if side == 0:
		return false
	if tuning.wall_jump_needs_opposite_wall and side == last_wall_jump_side:
		return false
	last_wall_jump_side = side
	kick_off_wall(side)
	change_state(&"jump")
	return true


## Jump away from a wall on `side`, briefly ignoring input back toward it.
func kick_off_wall(side: int) -> void:
	velocity.x = -side * tuning.wall_jump_speed_x
	facing = -side
	lock_input_toward(side, tuning.wall_jump_lock_time)
	start_jump(tuning.jump_speed, tuning.jump_hold_time)
	Sfx.play(&"wall_jump")


func try_wall_slide() -> bool:
	if not can(GameState.SpiritColor.GREEN) or velocity.y <= 0.0 or input_x() == 0.0:
		return false
	if not is_wall_at(int(input_x())):
		return false
	change_state(&"wall_slide")
	return true


func try_dash() -> bool:
	if not Input.is_action_just_pressed(&"dash") or not can(GameState.SpiritColor.ORANGE) \
			or air_dashes_left <= 0:
		return false
	change_state(&"dash")
	return true


func try_slide() -> bool:
	if not Input.is_action_just_pressed(&"slide") or not can(GameState.SpiritColor.RED) \
			or not is_on_floor() or input_x() == 0.0:
		return false
	facing = int(input_x())
	change_state(&"slide")
	return true


func try_climb() -> bool:
	if not Input.is_action_pressed(&"grab") or not can(GameState.SpiritColor.PURPLE) \
			or not on_vine():
		return false
	change_state(&"climb")
	return true


func try_spirit() -> bool:
	if not Input.is_action_just_pressed(&"spirit") or not can(GameState.SpiritColor.BLUE) \
			or not spirit_ready:
		return false
	change_state(&"spirit_phase")
	return true


func try_push() -> bool:
	if not Input.is_action_pressed(&"grab") or not is_on_floor():
		return false
	for side: int in [facing, -facing]:
		var block := adjacent_block(side)
		if block:
			push_block = block
			push_side = side
			change_state(&"push")
			return true
	return false


## Grab a ledge when moving into one in midair: a wall at chest height with its top edge
## within reach of the hands and room to stand on top.
func try_ledge_grab() -> bool:
	if not can(GameState.SpiritColor.PURPLE) or ledge_regrab_timer > EPSILON \
			or velocity.y < -tuning.ledge_grab_max_rise_speed or input_x() == 0.0:
		return false
	var side := int(input_x())
	var size := tuning.stand_size
	var half := size.x / 2.0
	var chest := _ray(global_position + Vector2(0.0, -size.y * 0.6),
			global_position + Vector2(side * (half + tuning.wall_check_distance + 1.0), -size.y * 0.6))
	if chest.is_empty():
		return false
	var wall_x: float = chest.position.x
	# Probe down just inside the wall face, from above the head to below it.
	var probe_x := wall_x + side * 2.0
	var head_y := global_position.y - size.y
	var probe_top := Vector2(probe_x, head_y - tuning.ledge_reach_above)
	if _is_solid_point(probe_top):
		return false # The wall goes higher than the hands can reach.
	var ledge := _ray(probe_top, Vector2(probe_x, head_y + tuning.ledge_reach_below))
	if ledge.is_empty():
		return false
	var ledge_y: float = ledge.position.y
	var top := Vector2(wall_x + side * (half + 2.0), ledge_y)
	if not can_fit_at(top, Shape.STAND):
		return false
	ledge_hang_position = Vector2(wall_x - side * half, ledge_y + LEDGE_HANG_DROP)
	ledge_top_position = top
	facing = side
	change_state(&"ledge_grab")
	return true


# --- Queries -----------------------------------------------------------------------------

## The side of an adjacent wall: 1 right, -1 left, 0 none. Checks the facing side first.
func wall_side() -> int:
	for side: int in [facing, -facing]:
		if is_wall_at(side):
			return side
	return 0


func is_wall_at(side: int) -> bool:
	return test_move(global_transform, Vector2(side * tuning.wall_check_distance, 0.0))


func on_vine() -> bool:
	return _overlaps(global_position + Vector2(0.0, -VINE_SENSOR_HEIGHT), VINE_SENSOR_SIZE, VINE_LAYER)


## The hazard box: the collision box shrunk by the hurtbox inset at the sides and feet, and
## reaching up to the top of the drawn head (standing), so whatever the head touches counts.
func touching_hazard() -> bool:
	var size := shape_size(shape)
	var inset := tuning.hurtbox_inset
	var top := size.y + (tuning.hurtbox_head_reach if shape == Shape.STAND else -inset)
	var box := Vector2(size.x - inset * 2.0, top - inset)
	return _overlaps(global_position + Vector2(0.0, -inset - box.y / 2.0), box, HAZARD_LAYER)


func adjacent_block(side: int) -> PushBlock:
	var hit := move_and_collide(Vector2(side * tuning.wall_check_distance, 0.0), true)
	if hit and hit.get_collider() is PushBlock:
		return hit.get_collider()
	return null


## Would the hero fit here with this shape? Hazards count as blocked when asked.
func can_fit_at(feet: Vector2, test_shape: Shape, include_hazards := false) -> bool:
	# One px smaller and lifted half a px, so resting on the floor doesn't count as blocked.
	var size := shape_size(test_shape)
	var mask := collision_mask | (HAZARD_LAYER if include_hazards else 0)
	return not _overlaps(feet + Vector2(0.0, -size.y / 2.0 - 0.5), size - Vector2.ONE, mask)


func can_fit(test_shape: Shape) -> bool:
	return can_fit_at(global_position, test_shape)


func shape_size(of_shape: Shape) -> Vector2:
	match of_shape:
		Shape.CROUCH:
			return tuning.crouch_size
		Shape.SLIDE:
			return tuning.slide_size
	return tuning.stand_size


## Where the camera looks: the spirit during Spirit Phase, otherwise the hero.
func camera_focus() -> Vector2:
	return spirit.global_position if is_instance_valid(spirit) else global_position


## Does a box of `size` centered at `center` overlap anything on `mask`?
func _overlaps(center: Vector2, size: Vector2, mask: int) -> bool:
	_query_rect.size = size
	_query.transform = Transform2D(0.0, center)
	_query.collision_mask = mask
	_query.collide_with_areas = true
	return not get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty()


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)


func _is_solid_point(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


# --- Body --------------------------------------------------------------------------------

func set_shape(new_shape: Shape) -> void:
	shape = new_shape
	var size := shape_size(new_shape)
	(body_shape.shape as RectangleShape2D).size = size
	body_shape.position = Vector2(0.0, -size.y / 2.0)


## Air states call this: stand up if there's room, otherwise stay low.
func stand_up_if_room() -> void:
	if shape != Shape.STAND and can_fit(Shape.STAND):
		set_shape(Shape.STAND)


## Play an animation facing the current direction. `restart` replays it from frame 0.
func play(anim: StringName, restart := false) -> void:
	sprite.flip_h = facing < 0
	if restart or sprite.animation != anim:
		sprite.stop()
		sprite.play(anim)


func die() -> void:
	if state_name != &"dead":
		change_state(&"dead")


## Put the hero at `at`, ready to play: after a death, or when entering the game. `quiet`
## skips the respawn sound.
func respawn(at: Vector2, quiet := false) -> void:
	global_position = at
	velocity = Vector2.ZERO
	facing = 1
	_lock_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	set_shape(Shape.STAND)
	refill()
	frozen = false
	input_locked = false
	if not quiet:
		Sfx.play(&"respawn", -6.0)
	change_state(&"idle")


func _update_colors() -> void:
	var material := sprite.material as ShaderMaterial
	for color: int in GameState.SpiritColor.values():
		material.set_shader_parameter(PART_PARAMS[color], GameState.has_color(color))


## The body is the HUD: a part dims once its ability is used, and glows again when refilled.
func _update_spent_parts() -> void:
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter(&"torso_spent", air_dashes_left <= 0)
	material.set_shader_parameter(&"back_leg_spent", not has_air_jump)
	material.set_shader_parameter(&"head_spent", not spirit_ready)
