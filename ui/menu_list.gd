class_name MenuList
extends VBoxContainer
## A list of menu rows driven by keys or a gamepad, in the same style as the yes/no popup:
## up/down picks a row, Jump/Enter activates it, left/right changes its value, and Esc/B (or
## the pause button) backs out. Rows are buttons, on/off toggles, 0-100% sliders, or choices.
## Only reacts while `active` and visible; it works while the game is paused.

signal cancelled

const PICKED := Color(0.22, 0.12, 0.05)
const UNPICKED := Color(0.55, 0.45, 0.35)

enum Kind { BUTTON, TOGGLE, SLIDER, CHOICE }

## Reacts to input only while true. Turning it on ignores the frame it happens on, so the press
## that opened the menu doesn't also pick a row.
var active := false:
	set(value):
		active = value
		_skip_frame = value
		_refresh()

var _rows: Array[Dictionary] = []
var _labels: Array[Label] = []
var _index := 0
var _skip_frame := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func clear_rows() -> void:
	_rows.clear()
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_index = 0


func add_button(text: String, action: Callable) -> void:
	_add({"kind": Kind.BUTTON, "text": text, "action": action})


## `getter` returns a bool; `setter` takes one.
func add_toggle(text: String, getter: Callable, setter: Callable) -> void:
	_add({"kind": Kind.TOGGLE, "text": text, "get": getter, "set": setter})


## `getter` returns 0 to 1; `setter` takes it. Left/right step by `step`.
func add_slider(text: String, getter: Callable, setter: Callable, step := 0.1) -> void:
	_add({"kind": Kind.SLIDER, "text": text, "get": getter, "set": setter, "step": step})


## `getter` returns the picked option's index; `setter` takes one.
func add_choice(text: String, options: PackedStringArray, getter: Callable, setter: Callable) -> void:
	_add({"kind": Kind.CHOICE, "text": text, "options": options, "get": getter, "set": setter})


## Which row is picked (0 is the top).
func picked() -> int:
	return _index


func pick(index: int) -> void:
	_index = clampi(index, 0, maxi(0, _rows.size() - 1))
	_refresh()


func _add(row: Dictionary) -> void:
	_rows.append(row)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_labels.append(label)
	_refresh()


func _process(_delta: float) -> void:
	if not active or not is_visible_in_tree() or _rows.is_empty():
		return
	if _skip_frame:
		_skip_frame = false
		return
	var row := _rows[_index]
	if _pressed([&"ui_up", &"move_up"]):
		_move(-1)
	elif _pressed([&"ui_down", &"move_down"]):
		_move(1)
	elif _pressed([&"ui_left", &"move_left"]):
		_change(row, -1)
	elif _pressed([&"ui_right", &"move_right"]):
		_change(row, 1)
	elif _pressed([&"ui_cancel", &"pause"]):
		Sfx.play(&"ui_confirm", -10.0)
		cancelled.emit()
	elif _pressed([&"ui_accept", &"jump"]):
		match row["kind"]:
			Kind.BUTTON:
				Sfx.play(&"ui_confirm")
				(row["action"] as Callable).call()
			Kind.TOGGLE, Kind.CHOICE:
				_change(row, 1)


func _move(step: int) -> void:
	_index = wrapi(_index + step, 0, _rows.size())
	Sfx.play(&"ui_confirm", -10.0)
	_refresh()


func _change(row: Dictionary, step: int) -> void:
	match row["kind"]:
		Kind.TOGGLE:
			row["set"].call(not row["get"].call())
		Kind.SLIDER:
			var value: float = row["get"].call()
			row["set"].call(clampf(snappedf(value + step * row["step"], row["step"]), 0.0, 1.0))
		Kind.CHOICE:
			var count: int = (row["options"] as PackedStringArray).size()
			row["set"].call(wrapi(row["get"].call() + step, 0, count))
		_:
			return
	Sfx.play(&"ui_confirm", -10.0)
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var row := _rows[i]
		var text: String = row["text"]
		match row["kind"]:
			Kind.TOGGLE:
				text += ":  " + ("On" if row["get"].call() else "Off")
			Kind.SLIDER:
				text += ":  %d%%" % roundi(row["get"].call() * 100.0)
			Kind.CHOICE:
				text += ":  " + (row["options"] as PackedStringArray)[row["get"].call()]
		var here := i == _index
		_labels[i].text = "> %s <" % text if here else text
		_labels[i].add_theme_color_override(&"font_color", PICKED if here else UNPICKED)


func _pressed(actions: Array[StringName]) -> bool:
	for action in actions:
		if Input.is_action_just_pressed(action):
			return true
	return false
