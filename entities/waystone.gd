@tool
class_name Waystone
extends Area2D
## A tall runed stone for travel. Each kind carries its own rune (GLYPHS), unlike any
## checkpoint stone's:
## - Region: one beside each region's Spirit Gate. It's a checkpoint, and once the region's
##   color has returned it glows in that color: Interact then opens the travel menu, to the
##   Hollow or any other glowing region stone.
## - Ring: the Hollow's ring, one stone per region with that region's rune, dark until its
##   color returns, then glowing; Interact opens the same menu.
## - Hollow: the stone at the ring's center, always awake. Travel to the Hollow arrives here.
## Origin at the bottom center, on the ground; travel arrives at the origin. The stone is drawn
## grey with the ground; the rune, its glow, and the motes keep their color.

enum Kind { REGION, RING, HOLLOW }

## The region stones' rune per color (GameState.SpiritColor), from art/entities/runes.png.
const GLYPHS: Array[int] = [12, 11, 14, 13, 18, 22]
const HOLLOW_GLYPH := 23
const HOLLOW_LIGHT := Color(0.9, 0.94, 1.0)
## A region stone touched as a checkpoint before its color returns.
const CHECKPOINT_LIGHT := CheckpointStone.LIGHT
## The glow behind an awake rune: its center (from the origin) and radius.
const GLOW_CENTER := Vector2(1, -41)
const GLOW_RADIUS := 13.0

@export var kind := Kind.REGION:
	set(value):
		kind = value
		_paint()
## The color that wakes it and that it glows (GameState.SpiritColor: 0 orange, 1 yellow,
## 2 green, 3 red, 4 purple, 5 blue). Unused by the Hollow stone.
@export_range(0, 5) var color := 0:
	set(value):
		color = value
		_paint()

## Touched as a checkpoint (region stones).
var lit := false

@onready var stone: Sprite2D = $Stone
@onready var rune: Rune = $Rune
@onready var motes: CPUParticles2D = $Motes
@onready var hint: Label = $Hint
@onready var shape_node: CollisionShape2D = $Shape


func _ready() -> void:
	add_to_group(&"full_color")
	_paint()
	if Engine.is_editor_hint():
		return
	stone.material = WorldColor.material(WorldColor.Layer.GROUND)
	hint.hide()
	hint.text = SpiritGate._key_name(&"interact")
	body_entered.connect(_on_body_entered)
	GameState.colors_changed.connect(_paint)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var hero := _hero_here()
	var usable := hero != null and is_awake() and Main.instance.can_travel()
	hint.visible = usable
	if usable and Input.is_action_just_pressed(&"interact"):
		Main.instance.open_travel(self)


## Awake: glowing and usable for travel. The Hollow stone always is; the others once their
## color has returned (in the editor, always, to show the color).
func is_awake() -> bool:
	return kind == Kind.HOLLOW or Engine.is_editor_hint() or GameState.has_color(color as GameState.SpiritColor)


func shown_glyph() -> int:
	return HOLLOW_GLYPH if kind == Kind.HOLLOW else GLYPHS[color]


func glow_color() -> Color:
	return HOLLOW_LIGHT if kind == Kind.HOLLOW else ColorOrb.TINTS[color]


func _hero_here() -> Player:
	if Main.instance == null:
		return null
	var rect := Touch.shape_rect(shape_node)
	for body in get_overlapping_bodies():
		if Touch.hero_in(body, rect):
			return body
	return null


func _on_body_entered(body: Node2D) -> void:
	if kind != Kind.REGION or lit or not Touch.hero_in(body, Touch.shape_rect(shape_node)) \
			or Main.instance == null:
		return
	if Main.instance.checkpoint_reached(global_position):
		lit = true
		_paint()
		Sfx.play(&"checkpoint")


func _paint() -> void:
	if not is_node_ready():
		return
	rune.glyph = shown_glyph()
	var awake := is_awake()
	rune.color = glow_color() if awake else CHECKPOINT_LIGHT
	rune.brightness = 1.0 if awake else (0.9 if lit else 0.0)
	motes.emitting = awake and not Engine.is_editor_hint()
	motes.color = Color(glow_color(), 0.8)
	queue_redraw()


# The glow behind an awake rune (the stone is drawn behind this).
func _draw() -> void:
	if not is_node_ready() or not is_awake():
		return
	var glow := glow_color()
	draw_circle(GLOW_CENTER, GLOW_RADIUS, Color(glow, 0.12))
	draw_circle(GLOW_CENTER, GLOW_RADIUS * 0.65, Color(glow, 0.18))
