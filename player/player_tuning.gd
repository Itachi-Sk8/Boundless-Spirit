class_name PlayerTuning
extends Resource
## Every movement number lives here. Edit res://player/tuning.tres in the Inspector.
## Starting values are the GameMaker prototype's, converted from per-frame to per-second
## at 60 fps (docs/DESIGN.md, "Movement and feel").

@export_group("Run")
## Top speed, in px/s.
@export var run_speed := 210.0

@export_group("Gravity")
## Downward acceleration, in px/s².
@export var gravity := 990.0
## Fastest the hero can fall, in px/s.
@export var max_fall_speed := 480.0

@export_group("Jump")
## Upward speed while the jump button is held, in px/s.
@export var jump_speed := 189.0
## How long holding jump keeps the upward speed, in seconds.
@export var jump_hold_time := 0.3
## Upward speed of the double jump, in px/s.
@export var double_jump_speed := 171.0
## How long holding keeps the double jump's upward speed, in seconds.
@export var double_jump_hold_time := 0.17

@export_group("Forgiveness")
## A jump still works this long after running off a ledge, in seconds.
@export var coyote_time := 0.1
## A jump pressed this long before landing fires on landing, in seconds.
@export var jump_buffer_time := 0.1
