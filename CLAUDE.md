# Boundless Spirit

A hard, movement-first 2D platformer (Celeste, Super Meat Boy) set in one connected forest.
A grey spirit wins back six colors, one per body part, by clearing one-run Spirit Rooms; each
color is a new movement ability that opens more of the map. About 2 hours, Windows first,
Godot 4.7 + GDScript. @Ben designs and builds levels; Claude writes most of the code.

The full design is in `docs/DESIGN.md`. Read the relevant section before starting a feature,
and update it when a decision changes (for example, record measured jump and dash reach there).

## Design in brief

- **Pillars:** movement is the game (no combat, stats, or inventory); color is earned; hard but
  fair (instant, cheap deaths); the forest opens up as abilities return.
- **Starting moves:** run (one speed), variable-height jump, crouch, push/pull blocks.
- **Colors, in fixed order:** 1 orange torso = Dash, 2 yellow back leg = Double jump,
  3 green back arm = Wall jump, 4 red front leg = Slide, 5 purple front arm = Climb,
  6 blue head = Spirit Phase.
- **Forgiveness everywhere:** coyote time 0.1 s, jump buffer 0.1 s, corner correction, hitboxes
  smaller than the art.
- **Death:** back in control in under 0.5 s. Main map respawns at the room entry or last
  checkpoint stone; Spirit Rooms always restart from their start. Rooms reset on death.
- **World:** the Hollow (grey hub) plus six regions and the Heart; 8–12 rooms per region.
  Each region regains its color when its Spirit Room is cleared.
- **No HUD during play:** the hero's body parts glow when their ability is ready.

## Build order

1. **Setup** (done): Godot project, folder layout, pixel-perfect settings, hero animations,
   grey hero standing in an empty room.
2. **Movement test room** (done; feel approved by @Ben at v1.0.3, may be retuned as levels
   arrive): starting moves, death/respawn, camera, all six abilities behind debug switches;
   level-building numbers are in `docs/DESIGN.md` and get re-measured after tuning.
3. Vertical slice: the Hollow + Ember Grove, room changes, checkpoints, autosave, first Spirit
   Room, orange unlock.
4. Content tools. 5. Regions 2–6. 6. The Heart and endings. 7. Optional content and polish.
8. Release.

## Project layout

```
res://
  game/      always-loaded scripts (autoloads): game state, saving, room changes, audio
  player/    player scene, one script per movement state, tuning file
  rooms/     _template/ plus one folder per region
  entities/  hazards, creatures, push blocks, spirit barriers, and other objects
  ui/        title, pause, map, results card
  shaders/   palette swap, world color, spirit glow
  art/       sprites, tilesets, backgrounds
  audio/     music, sound effects
  tests/     headless movement tests and measurements
docs/              design doc
gamemaker-legacy/  the old GameMaker prototype and raw asset packs (reference only)
```

- `gamemaker-legacy/` has a `.gdignore`, so Godot never imports it. Copy art out of
  `gamemaker-legacy/Assets/` into `art/` when it's needed; don't reference it directly.
- Prototype code worth reading: `gamemaker-legacy/objects/obj_Player/` (coyote time, jump
  buffer, variable jump, double jump) and the camera and transition objects. Rewrite in
  GDScript; don't port line by line. Don't carry over the transition's unbalanced parentheses
  or the camera's unused smoothing.

## What exists now

- `project.godot`: 480×270 viewport, window sized at startup to the largest whole-number scale that fits the screen (3× = 1440×810 on 1080p, 4× = 1920×1080 on 1440p; `game/settings.gd`), `viewport` stretch with integer scale,
  nearest filtering, 2D transform and vertex snapping, 60 physics ticks, Compatibility
  renderer. Keep these; they're what make the pixels crisp.
- Autoloads: `GameState` (`game/game_state.gd`: colors, deaths; saving comes later) and
  `Settings` (`game/settings.gd`: F11 fullscreen for now).
- Input map in `project.godot`, matching the design doc's controls table: `move_*`, `jump`,
  `dash`, `slide`, `grab`, `spirit`, `map`, `pause`, plus `toggle_fullscreen`.
- Physics layers: 1 world, 2 player, 3 hazards, 4 spirit_barriers, 5 push_blocks, 6 vines.
  The player collides with 1, 4, 5; the spirit with 1 and 5, so it passes barriers.
- **Player** (`player/player.tscn`, `player.gd`): CharacterBody2D with a `Sprite` and a `Body`
  box that changes size for standing, crouching (18 px, too tall for 1-tile gaps), and sliding
  (12 px). `player.gd` holds what states share: input, timers, charges, `try_*()` moves that
  switch state, and overlap queries. States live in `player/states/`, one script each:
  idle, run, crouch, jump, fall, dash, wall_slide, slide, ledge_grab, climb, spirit_phase,
  push, dead. Each ability's `try_*()` checks its color with `can()`.
- **Tuning** (`player/player_tuning.gd` + `player/tuning.tres`): every movement number and
  hitbox. The camera's numbers are exports on `game/game_camera.gd`.
- **Animations** (`player/hero_frames.tres`): built from `art/hero/*.png`. Some sheets are
  split: `jump`/`fall` (frames 0-2 / 3-5), `dash`/`dash_end`, `ledge_hang`/`ledge_climb`.
  Frame rates are still placeholders.
- **Shaders:** `hero_palette.gdshader` greys locked body parts by hue (red <15° or ≥330°,
  orange <40°, yellow <75°, green <150°, blue <250°, purple otherwise; below 0.25 saturation
  passes through) and dims a part whose ability is spent (`torso_spent`, `back_leg_spent`,
  `head_spent`): the body is the HUD. `spirit_glow.gdshader` draws the spirit.
- **Rooms:** `rooms/room.gd` (`Room`) expects `Tiles`, `Spawn`, `Player`, `Camera` children;
  takes camera and pit bounds from the painted tiles; on death it calls `reset_to_start()` on
  the `room_reset` group and respawns the hero. `rooms/_template/room_template.tscn` is a
  one-screen room with that structure.
- **Movement test room** (`rooms/test/movement_test.tscn`, the main scene): built at load from
  the text layout in `movement_test.gd`, so changing a gap is a text edit. Stations left to
  right: heights, crouch, gaps, push block, dash, ember, double jump, wall-jump shaft, slide
  tunnel and long jump, ledge and vines, spirit barrier. The debug overlay
  (`ui/debug_overlay.tscn`) shows state and charges; keys 1-6 toggle colors, 0 all, R respawn,
  F3 hide.
- **Tiles:** `art/tilesets/test_tiles.tres` is the grey test set: two solid shades, one-way
  platform, spikes in four directions (hitboxes smaller than the art), spirit barrier, vines.
- **Entities:** `push_block` (moved only while holding Grab) and `dash_ember` (refills the dash
  in midair, relights after 2 s).

## Conventions

**GDScript**
- Static typing everywhere: typed vars, parameters, and return types (`-> void`). Use `:=`
  when the type is obvious.
- Tabs for indentation, two blank lines between functions, `##` doc comments on classes and
  exported members.
- Files and folders `snake_case`; `class_name` in `PascalCase`; constants `UPPER_SNAKE`;
  signals named in the past tense (`died`, `color_unlocked`); `StringName` literals (`&"idle"`)
  for animation and action names.
- No movement numbers in code. Every tunable value goes in `PlayerTuning` (or a matching
  tuning resource for other systems), so an assist mode can change them later.
- Player movement is a state machine with one small script per state (idle, run, jump, fall,
  dash, wall slide, slide, climb, ledge grab, Spirit Phase, push, dead). Each ability checks
  whether its color is unlocked.
- Hand-written movement on CharacterBody2D with `move_and_slide()`; no RigidBody for the hero.

**Scenes and resources**
- Keep scenes and resources as text (`.tscn`, `.tres`) so they can be read and diffed.
- Commit `.import` and `.uid` files; never commit `.godot/`.
- Nodes `PascalCase` (`Sprite`, `Body`, `Spawn`).

**Art**
- 16×16 tiles. Hero frames are 48×48 with the feet at y = 40 of the frame, so the `Sprite`
  sits at (0, -16) and the player node's origin is at its feet. Keep that rule for every
  character: origin at the feet.
- All hero sheets face right; flip with `flip_h` for left. `wall_slide` and `wall_land` are
  drawn with the wall on the hero's right.
- No grey copies of sprites; the palette shader handles grey. Leave behind the samurai pack,
  weapon and punch animations, city backgrounds, and the forest pack's own hero.
- Palette-sensitive art: any new hero color must keep its body part's hue band, or the shader
  will assign it to the wrong part.

## Running and checking

- **Play:** open `project.godot` in Godot 4.7.x and press F5, or run `godot --path .` from the
  repo root.
- **Script and scene errors without a window:** `godot --headless --path . --import` reimports
  and reports errors, and `godot --headless --path . --quit-after 60` runs the main scene briefly.
- **Movement tests:** `godot --headless --path . --fixed-fps 60 res://tests/run_tests.tscn`
  runs every movement rule and prints the level-building numbers; the exit code is the number
  of failures. Run it after any change to the player or tuning, and update the numbers table
  in `docs/DESIGN.md` when they move.
- **Screenshots without playing:** `godot --path . --write-movie out.png --fixed-fps 60
  --quit-after 30` writes 480×270 PNG frames of the main scene.
- Feel can't be checked automatically; after movement changes, ask @Ben for a playtest and take
  feel notes literally ("the jump floats at the top").

**Godot gotchas found the hard way**
- An Area2D never reports tile collision layers (both count as static to the physics engine).
  Check hazards and vines with direct shape queries, as `Player._overlaps()` does.
- `godot -s script.gd` compiles the script before autoloads exist, so anything touching
  `GameState` fails. Run test code as a scene instead.
- `Input.action_press()` made inside a physics frame counts as "just pressed" only on the next
  frame. The test harness presses buttons between frames (it steps on `process_frame`) so
  pressed and just-pressed begin together, like real input.
- Timers count down in floating point: compare against `Player.EPSILON`, not 0, or a 0.15 s
  timer sometimes lasts 10 frames instead of 9.

## Workflow

- **Version:** bump the patch number of `application/config/version` in `project.godot`
  (1.0.1 → 1.0.2) after every requested change, so @Ben can tell builds apart in the debug
  overlay. 1.0.1 was the first playtest's gravity change.
- Small steps: one feature, one playtest, one commit, so any change can be rolled back.
- Commit and push only when asked.
- Licenses for Asset Packs 1–5 and the Legacy-Fantasy pack must be confirmed before any paid
  release (see `docs/DESIGN.md`).
