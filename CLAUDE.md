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
2. Movement test room: starting moves, death/respawn, camera, all six abilities behind debug
   switches; record level-building numbers in `docs/DESIGN.md`.
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

- `project.godot`: 480×270 viewport, 1920×1080 window, `viewport` stretch with integer scale,
  nearest filtering, 2D transform and vertex snapping, 60 physics ticks, Compatibility
  renderer. Keep these; they're what make the pixels crisp.
- `player/player.tscn`: CharacterBody2D (`player.gd`) with an AnimatedSprite2D `Sprite` using
  `player/hero_frames.tres` and the `hero_palette` shader, plus a 10×26 `Body` collision box.
  The player only falls and stands for now.
- `player/player_tuning.gd` + `player/tuning.tres`: every movement number, starting from the
  prototype's values converted to per-second.
- `player/hero_frames.tres`: 20 animations from `art/hero/*.png`: idle, walk, run, jump, land,
  crouch_idle, crouch_walk, push, pull, push_idle, dash, air_spin, wall_slide, wall_land, slide,
  ledge_climb, climb_side, climb_back, death, roll. Frame rates are the prototype's (10 where
  it had none) and still need tuning, especially dash (5 fps is far too slow for a 0.15 s dash).
- `shaders/hero_palette.gdshader`: greys each locked body part. Each part has its own hue, so a
  pixel's hue picks its part: red <15° or ≥330°, orange <40°, yellow <75°, green <150°,
  blue <250°, purple otherwise. Pixels below 0.25 saturation (dust and effect colors) pass
  through. One bool uniform per color, all false by default.
- `rooms/_template/room_template.tscn`: the main scene for now. Grey background, a floor
  whose top is at y = 224, a `Spawn` marker, and the player. It grows into the real room
  template (tile layers, camera bounds, spawn points, exits) in later milestones.

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
- **Screenshots without playing:** `godot --path . --write-movie out.png --fixed-fps 60
  --quit-after 30` writes 480×270 PNG frames of the main scene.
- Feel can't be checked automatically; after movement changes, ask @Ben for a playtest and take
  feel notes literally ("the jump floats at the top").

## Workflow

- Small steps: one feature, one playtest, one commit, so any change can be rolled back.
- Commit and push only when asked.
- Licenses for Asset Packs 1–5 and the Legacy-Fantasy pack must be confirmed before any paid
  release (see `docs/DESIGN.md`).
