class_name SheetAnim
extends RefCounted
## Plays animations from a sprite sheet laid out one animation per row (the creature sheets in
## art/creatures/): set the Sprite2D's hframes and vframes, then play(row, frames, fps).

var sprite: Sprite2D
var row := 0
var frames := 1
var fps := 8.0
var loop := true
## True once a non-looping animation has shown its last frame.
var finished := false

var _time := 0.0


func _init(target: Sprite2D) -> void:
	sprite = target


## Start an animation (does nothing if it's already playing, unless `restart`).
func play(new_row: int, frame_count: int, frames_per_second: float, looping := true, restart := false) -> void:
	if new_row == row and not restart and not finished:
		return
	row = new_row
	frames = frame_count
	fps = frames_per_second
	loop = looping
	finished = false
	_time = 0.0
	_show(0)


func update(delta: float) -> void:
	_time += delta
	var index := int(_time * fps)
	if index >= frames:
		if loop:
			index %= frames
		else:
			index = frames - 1
			finished = true
	_show(index)


func _show(index: int) -> void:
	sprite.frame = row * sprite.hframes + index
