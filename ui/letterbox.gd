class_name Letterbox
extends CanvasLayer
## The room-change transition carried over from the prototype: black bars close from the top
## and bottom, the room changes behind them, then they open again.

## Seconds for the bars to close, and to open.
@export var close_time := 0.2
@export var open_time := 0.25

var _amount := 0.0

@onready var top: ColorRect = $Top
@onready var bottom: ColorRect = $Bottom


func _ready() -> void:
	_set_amount(0.0)


func close() -> void:
	await _animate(1.0, close_time)


func open() -> void:
	await _animate(0.0, open_time)


func is_closed() -> bool:
	return _amount >= 1.0


func _animate(target: float, time: float) -> void:
	# The prototype eased each step by a tenth of the remaining distance: an exponential ease out.
	var tween := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_amount, _amount, target, time)
	await tween.finished


func _set_amount(amount: float) -> void:
	_amount = amount
	var screen := get_viewport().get_visible_rect().size
	var bar := ceilf(screen.y / 2.0 * amount)
	top.position = Vector2.ZERO
	top.size = Vector2(screen.x, bar)
	bottom.position = Vector2(0.0, screen.y - bar)
	bottom.size = Vector2(screen.x, bar)
