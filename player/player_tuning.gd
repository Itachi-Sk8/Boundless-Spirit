class_name PlayerTuning
extends Resource
## Every movement number lives here. Edit res://player/tuning.tres in the Inspector.
## Starting values are the GameMaker prototype's, converted from per-frame to per-second
## at 60 fps (docs/DESIGN.md, "Movement and feel"). Distances are in px; a tile is 16 px.

@export_group("Run")
## Top speed, in px/s.
@export var run_speed := 210.0
## Speeding up on the ground, in px/s². 4200 reaches top speed in 3 frames.
@export var ground_accel := 4200.0
## Slowing down on the ground, in px/s². High so the hero never slides to a stop.
@export var ground_decel := 6300.0
## Speeding up in the air, in px/s².
@export var air_accel := 3150.0
## Slowing down in the air when no direction is held, in px/s².
@export var air_decel := 2100.0
## Slowing down in the air while faster than run speed and still holding that direction
## (after a slide or dash), in px/s². 0 keeps the slide's full speed for the long jump.
@export var air_over_speed_decel := 0.0

@export_group("Crouch")
## Crouch-walk speed, in px/s.
@export var crouch_speed := 75.0
## Crouching still this long peeks the camera down, in seconds.
@export var peek_delay := 0.3

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
## Clipping a ceiling corner by up to this many px nudges the hero around it.
@export var corner_correction := 4

@export_group("Dash (orange)")
## How far a dash travels, in px.
@export var dash_distance := 80.0
## How long a dash lasts, in seconds.
@export var dash_time := 0.15
## Pause at the start of a dash so it reads clearly, in seconds.
@export var dash_freeze_time := 0.05
## Speed kept when a dash ends, in px/s.
@export var dash_end_speed := 210.0
## Upward dashes keep this share of the end speed vertically.
@export var dash_up_end_factor := 0.75
## Dashes available in the air before landing.
@export var air_dashes := 1

@export_group("Wall jump (green)")
## Fastest fall while sliding down a wall, in px/s.
@export var wall_slide_speed := 60.0
## Sideways speed of a wall jump, in px/s.
@export var wall_jump_speed_x := 210.0
## After a wall jump, input back toward that wall is ignored for this long, in seconds.
@export var wall_jump_lock_time := 0.15
## How close a wall must be to slide on or jump off it, in px.
@export var wall_check_distance := 2.0
## When on, two wall jumps in a row off the same side need a landing in between,
## so going up takes two facing walls. A jump on the same wall uses the double jump instead.
@export var wall_jump_needs_opposite_wall := true

@export_group("Slide (red)")
## Slide speed, in px/s.
@export var slide_speed := 300.0
## How long a slide lasts, in seconds.
@export var slide_time := 0.4
## Speed while stuck low under a ceiling after a slide, in px/s.
@export var slide_crawl_speed := 60.0

@export_group("Climb (purple)")
## Climbing speed on vines, in px/s.
@export var climb_speed := 70.0
## How long pulling up onto a ledge takes, in seconds.
@export var ledge_climb_time := 0.25
## Small hop when climbing off the top of vines, in px/s.
@export var climb_exit_hop := 150.0
## A ledge can be grabbed while rising no faster than this, in px/s, so jumps past walls
## aren't cut short.
@export var ledge_grab_max_rise_speed := 60.0
## The hands reach a ledge top up to this far above the head, in px.
@export var ledge_reach_above := 4.0
## ...and down to this far below the top of the head, in px.
@export var ledge_reach_below := 10.0
## After dropping from a ledge, it can't be grabbed again for this long, in seconds.
@export var ledge_regrab_delay := 0.2

@export_group("Spirit Phase (blue)")
## Spirit flying speed, in px/s.
@export var spirit_speed := 180.0
## Longest the spirit can stay out, in seconds.
@export var spirit_time := 1.5

@export_group("Push and pull")
## Speed while pushing or pulling a block, in px/s.
@export var push_speed := 60.0

@export_group("Death")
## Time from death to respawn, in seconds. Keep under 0.5.
@export var death_time := 0.35

@export_group("Hitboxes")
## Standing collision box, in px. The sprite's body is about 19×30.
@export var stand_size := Vector2(10, 26)
## Crouching box. Taller than one tile so crouching can't pass 1-tile gaps.
@export var crouch_size := Vector2(10, 18)
## Sliding box. Under one tile so a slide fits 1-tile gaps.
@export var slide_size := Vector2(10, 12)
## The hazard box is the collision box shrunk by this much on every side, in px.
@export var hurtbox_inset := 2.0
