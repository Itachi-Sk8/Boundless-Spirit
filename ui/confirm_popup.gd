class_name ConfirmPopup
extends Control
## A yes/no question on a parchment card, e.g. at a Spirit Room's door. Left/right (keys,
## D-pad, or stick) picks, Jump/Enter/A confirms, Esc/B (cancel) means No. Starts on Yes.

signal answered(yes: bool)

const PICKED := Color(0.22, 0.12, 0.05)
const UNPICKED := Color(0.55, 0.45, 0.35)

var _yes := true
var _listening := false

@onready var question_label: Label = %Question
@onready var yes_label: Label = %Yes
@onready var no_label: Label = %No


func _ready() -> void:
	hide()


## Show `question` and wait for the answer: true for Yes.
func ask(question: String) -> bool:
	question_label.text = question
	_yes = true
	_refresh()
	show()
	# Ignore the frame it opens on, so the press that triggered it doesn't answer it.
	await get_tree().process_frame
	_listening = true
	var yes: bool = await answered
	return yes


func _process(_delta: float) -> void:
	if not _listening:
		return
	if _pressed([&"ui_left", &"move_left"]) and not _yes:
		_yes = true
		_refresh()
		Sfx.play(&"ui_confirm", -10.0)
	elif _pressed([&"ui_right", &"move_right"]) and _yes:
		_yes = false
		_refresh()
		Sfx.play(&"ui_confirm", -10.0)
	elif _pressed([&"ui_cancel", &"pause"]):
		_finish(false)
	elif _pressed([&"ui_accept", &"jump"]):
		_finish(_yes)


func _finish(yes: bool) -> void:
	_listening = false
	hide()
	Sfx.play(&"ui_confirm")
	answered.emit(yes)


func _pressed(actions: Array[StringName]) -> bool:
	for action in actions:
		if Input.is_action_just_pressed(action):
			return true
	return false


func _refresh() -> void:
	yes_label.text = "> Yes <" if _yes else "Yes"
	no_label.text = "> No <" if not _yes else "No"
	yes_label.add_theme_color_override(&"font_color", PICKED if _yes else UNPICKED)
	no_label.add_theme_color_override(&"font_color", PICKED if not _yes else UNPICKED)
