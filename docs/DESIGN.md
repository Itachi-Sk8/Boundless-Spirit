# Boundless Spirit Design Doc

Oct 8, 2026 · @Ben

Boundless Spirit is a hard, movement-first 2D platformer in the spirit of Celeste and Super Meat Boy, set in one connected forest. A spirit that has lost its color wins back six colors, one per body part, by clearing one-run Spirit Rooms. Each color is a new movement ability that opens more of the map. Target: about 2 hours for a first playthrough, Windows first, built in Godot with Claude writing most of the code.

## At a glance

Boundless Spirit is a precision platformer first and a Metroidvania second: every choice below serves tight, demanding movement.

| Topic | Decision |
| --- | --- |
| Genre | 2D precision platformer with Metroidvania exploration |
| Inspirations | Celeste and Super Meat Boy for movement and challenge; Zelda dungeons for a hard room that ends in a reward |
| Length | About 2 hours for a first playthrough, plus 30–45 minutes of optional content |
| Difficulty | Hard on purpose, kept fair by instant respawns and forgiving controls |
| Combat | None. Creatures are avoided or taken out indirectly |
| Progression | Six colors, unlocked in a fixed order, each a new movement ability |
| Platforms | Windows first, Mac and Linux later; keyboard and gamepad |
| Engine | Godot 4, GDScript |
| Team | @Ben on design and level building; Claude on code and template rooms |
| Release | itch.io for friends first, Steam later |

**Design pillars**

- **Movement is the game.** Every room exists to test a move. No combat, stats, or inventory.
- **Color is earned.** Each color comes from clearing a Spirit Room, and the world visibly changes when you get it.
- **Hard but fair.** Deaths are instant and cheap, and every death should feel like the player's own mistake.
- **The forest opens up.** Each new ability reveals paths the player has already walked past.

## Story and premise

The hero's spirit is not bound to its body, so its colors have slipped away into the forest. Winning them back is the whole journey. The details stay open on purpose: none of the systems below depend on them.

- **The hero:** Unnamed for now. A small figure whose six body parts each carry one color. At the start, all six are grey.
- **The setup:** The hero wakes in the Hollow, a grey clearing at the foot of a great tree in the middle of the forest. The forest lost its color along with the hero.
- **The journey:** Each color waits at the end of a Spirit Room. Taking it back restores that body part, grants an ability, and brings color back to the region around it.
- **The finale:** The last color, blue, gives Spirit Phase: the spirit leaves the body for a moment, the "boundless spirit" of the title. It opens the great tree, and the climb to the Heart at its crown ends the game.

**Story beats to write later**

- Why the colors left: a choice, a curse, or an accident
- What each color remembers, told in a short moment when the player takes it back
- The ending, plus an alternate ending for players who find every collectible

## The six colors

Colors return in a fixed order, so every playthrough follows the same path, and each new ability opens the way to the next region. Dash comes first because most later challenges build on it.

| Order | Color | Body part | Ability | What it does | Opens the way to |
| --- | --- | --- | --- | --- | --- |
| 1 | Orange | Torso | Dash | A quick burst in any of 8 directions; one dash in the air, refilled on landing | Sunlit Meadow, across a wide gap west of the Hollow |
| 2 | Yellow | Back leg | Double jump | A second jump in midair, refilled on landing | The Canopy, up high ledges in the Meadow |
| 3 | Green | Back arm | Wall jump | Slide slowly down walls and kick off them; climbing needs two facing walls | The Briar, across a deep chasm in Ember Grove |
| 4 | Red | Front leg | Slide | A low, fast slide under 1-tile gaps; jumping out of it gives a long jump | Underroot Caverns, through low root tunnels in the Briar |
| 5 | Purple | Front arm | Climb | Grab ledges and pull up; cling to and climb vine-covered surfaces | Misty Falls, up vine cliffs along the river in Ember Grove |
| 6 | Blue | Head | Spirit Phase | The spirit leaves the body for a moment and passes through spirit barriers | The Heart, through the barrier sealing the great tree |

- **Before any color**, the grey hero can run, jump, crouch, and push or pull blocks. The first Spirit Room is beaten with only these.
- **Each color belongs to a region.** The orange color waits in Ember Grove's Spirit Room, yellow in Sunlit Meadow's, and so on down the table.
- **Nothing goes stale.** Every ability stays in use to the end, and later rooms combine them.
- **The sprite already has the six colors.** The character art uses one distinct color per body part (blue head, orange torso, green back arm, purple front arm, yellow back leg, red front leg), and the GameMaker project already has a grey version of the idle animation.

## Movement and feel

Movement should feel instant and exact: full speed within a few frames, no sliding to a stop, and jump height set by how long the button is held. All numbers below are starting points for playtesting.

**Starting moves (no color)**

- **Run:** One top speed, reached almost instantly. The prototype had walk and run speeds on Shift; with five ability buttons coming, one speed keeps the controls manageable.
- **Jump:** Tap for a short hop, hold for a full jump.
- **Crouch:** Duck under head-height hazards. Holding down while standing still peeks the camera down.
- **Push and pull:** Hold Grab beside a block to move it.

**Ability rules**

- **Dash:** About 5 tiles in 0.15 s, in 8 directions, with a tiny freeze at the start so it reads clearly. Some speed carries out of it. Glowing embers in later regions refill it midair.
- **Double jump:** A smaller second jump, refilled on landing or by bounce flowers.
- **Wall jump:** Holding toward a wall slows the fall to a slide. A wall jump kicks away and briefly ignores input back toward the wall, so going up takes two facing walls.
- **Slide:** Press Slide while running for a fast, 0.4 s slide low enough for 1-tile gaps. Jumping out keeps the slide's speed for a long jump. Under a low ceiling the hero stays low until there is room to stand.
- **Climb:** Moving into a ledge in midair grabs it, and Up or Jump pulls up. On vines, hold Grab to cling and climb in any direction, with no stamina limit. Jumping off vines works like a wall jump.
- **Spirit Phase:** Press Spirit and the body hangs in place while the player steers a glowing spirit for up to 1.5 s. The spirit flies through spirit barriers. On release, the body jumps to the spirit's spot; if that spot is inside a wall or hazard, the hero stays put instead. Refilled on landing.

**Forgiveness that keeps hard fair**

- **Coyote time:** A jump still works for 0.1 s after running off a ledge.
- **Jump buffer:** A jump pressed up to 0.1 s before landing fires on landing.
- **Corner correction:** Clipping a ceiling corner by a few pixels nudges the hero around it instead of killing the jump.
- **Small hitboxes:** Hazards hurt only from a box smaller than their art, and the hero's box is slightly smaller than the sprite.

**Starting numbers from the prototype**

The GameMaker prototype's values are a good base. They carry over converted from per-frame to per-second, at 60 frames per second.

| Value | Prototype (per frame) | Godot starting value |
| --- | --- | --- |
| Run speed | 3.5 px | 210 px/s |
| Gravity | 0.275 px | 990 px/s² |
| Max fall speed | 8 px | 480 px/s |
| Jump speed, held up to 18 frames | 3.15 px | 189 px/s for up to 0.3 s |
| Double jump speed, held up to 10 frames | 2.85 px | 171 px/s for up to 0.17 s |
| Coyote time | 5 frames | 6 frames (0.1 s) |
| Jump buffer | 2 frames | 6 frames (0.1 s) |

With these values a full jump rises about 73 px (roughly 4.5 tiles), and a double jump adds about 42 px (roughly 2.5 tiles). After tuning, Claude will measure jump height, jump distance, and dash reach in a test room and record them here. Those numbers become the rules for building gaps and ledges.

**Level-building numbers** (measured Oct 8, 2026 by the headless movement tests after the first playtest, with gravity raised 12.5% to 1115 px/s² for a snappier feel; rerun after any tuning change)

| Move | Reach | In tiles | Building rule |
| --- | --- | --- | --- |
| Full jump height | 71 px | 4.5 | A 4-tile ledge is a jump; 5 tiles needs help |
| Short hop (tap) | 15 px | 0.9 | |
| Running jump, widest gap | 185 px | 11.6 | 10 tiles is a comfortable plain jump; 11 is the limit |
| Dash | 80 px | 5.0 | In any of 8 directions |
| Dash straight up from the floor | 90 px | 5.6 | |
| Jump, then up dash at the top | 161 px | 10.1 | |
| Jump + double jump | 114 px | 7.1 | 6 tiles is comfortable; 7 is barely reachable |
| Slide | 115 px | 7.2 | Fits 1-tile gaps; crouching doesn't |
| Slide jump, widest gap | 260 px | 16.3 | Speed is kept through the jump |
| Ledge grab | Hands reach 6 tiles up | 6 | A 6-tile wall needs Climb |
| Spirit Phase | 270 px | 16.9 | Straight line, 1.5 s |
| Death to control | 21 frames | | 0.35 s |

- **Two facing walls, enforced:** after a wall jump, another wall jump off the same side needs a landing first; pressing jump on that wall uses the double jump instead. A switch in the tuning file turns this off.
- **Slide jump:** holding the direction keeps the slide's full speed until landing, so the long jump reaches about 4.5 tiles further than a running jump.

## Map at a glance

&#91;embedded content: world map · hub, six regions, finale, and the ability that opens each path\]

Ember Grove is open from the start; after that, each region needs the color earned in the one before. Every region also opens a shortcut back to the Hollow, so the trips between them stay short.

## Regions

The forest has a grey hub, six color regions, and a finale. Each region adds its own hazards, holds one Spirit Room, and regains its color when that room is cleared. All names are working names.

| Region | Color | Look | New hazards and creatures | Its Spirit Room tests | Way in |
| --- | --- | --- | --- | --- | --- |
| The Hollow (hub) | None | Grey clearing at the foot of the great tree | Pits, thorns, push blocks, crumbling ledges | No Spirit Room | The start |
| Ember Grove | Orange | Autumn woods, drifting leaves | Crumbling platforms, leaf platforms that sink when stood on | Run, jump, push and pull | Open from the Hollow (east) |
| Sunlit Meadow | Yellow | Tall grass and flowers in bright light | Bounce flowers, dash-refill embers, bees on patrol | Dash | Dash across a wide gap (west) |
| The Canopy | Green | Treetops, branches, rope bridges | Swaying branches, falling logs, wind gusts | Dash and double jump | Double jump up high ledges in the Meadow |
| The Briar | Red | Thorn thickets and berry bushes | Thorn walls, low tunnels, charging boars | Wall jump | Wall jump across a deep chasm in Ember Grove |
| Underroot Caverns | Purple | Caves under the roots, glowing mushrooms | Vine walls and nets, crawling snails, falling stalactites, dark rooms | Slide | Slide through low root tunnels in the Briar |
| Misty Falls | Blue | River, waterfalls, mist | River currents, waterfalls that push down, spirit barriers | Climb | Climb vine cliffs along the river in Ember Grove |
| The Heart | All six | The crown of the great tree | Everything, combined | The final climb, using every ability | Spirit Phase through the great tree's barrier |

- **Size:** 8–12 rooms per region; a room is 1–4 screens.
- **Reasons to return:** Every region hides side paths that need a later color. Going back with new abilities finds collectibles, bonus Spirit Rooms, and shortcuts.
- **Shortcuts, not fast travel:** Each region opens a one-way door or gate back toward the Hollow, so backtracking stays short.
- **Gates hint at their color:** Any obstacle that needs a color the player lacks shows a faint trace of that color.

## Spirit Rooms

A Spirit Room is one continuous challenge that must be cleared in a single run: any death sends the player back to its start, and the prize at the end is a color.

**Rules**

- **Six on the main path,** one per color region, plus hidden bonus rooms (see Difficulty and optional content).
- **The entrance** is a stone archway that glows faintly in the color waiting inside.
- **No checkpoints.** Death restarts the room instantly from the start.
- **Length:** 45–90 seconds for a clean run. The room scrolls like any other.
- **Leaving is allowed** through the entrance or the pause menu; the room resets.
- **No collectibles inside,** so a clean run is the only goal.
- **A results card** at the end shows the time and deaths for that room and saves the best time.

**How to build one**

1. **Teach outside, test inside.** Every trick a Spirit Room uses first appears, safely, somewhere in the region around it.
2. **Test the newest ability hardest.** Each room centers on the color earned just before it, mixed with everything older.
3. **Build 3–5 sections that escalate,** with a safe ledge between them to breathe. The ledge is a rest, not a checkpoint.
4. **No blind jumps.** The camera shows the next landing before the player has to commit.
5. **Aim for 15–40 attempts** for a first clear, then adjust after playtesting.

**The reward**

- The color floats at the end of the room; touching it ends the run.
- The color flows into its body part, the ability's button prompt appears, and the region outside floods with color.
- The exit leads out a different way than the entrance, often as a shortcut toward the Hollow.

## Death, checkpoints, and saving

Dying is instant and cheap everywhere; only the respawn point differs between the main map and Spirit Rooms.

| Rule | Main map | Spirit Room |
| --- | --- | --- |
| Respawn point | Where the player entered the room, or the last checkpoint stone in a long room | The room's start, always |
| Death to control again | Under 0.5 s | Under 0.5 s |
| What is lost | Nothing | The current run |

- **Checkpoint stones** (working name) mark respawn points inside long main-map rooms. Passing one is enough to set it.
- **Rooms reset on death.** Pushed blocks, crumbled platforms, and moved creatures go back to their start, so a puzzle can never be left unsolvable.
- **Permanent changes save at once:** opened shortcuts, broken walls, colors, and collectibles.
- **Autosave** happens on entering each room, on each color, and on each collectible, with three save slots.
- **Death counts** are kept for the whole game and per Spirit Room, shown in the pause menu and at the ending.

## Hazards and creatures

There is no combat, so the katana, punch, and shooting animations in the asset packs stay unused. Danger comes from the forest itself, and creatures are only ever beaten indirectly.

**Hazards (one touch is death):** thorns, pits, rolling or falling logs, falling stalactites, and river rapids.

**Objects to move on and use:** crumbling platforms, sinking leaf platforms, swaying branches, one-way platforms, bounce flowers, push and pull blocks, pressure plates, breakable walls, dash-refill embers, wind gusts, waterfall currents, vines, and spirit barriers.

**Creatures** (art from the forest pack, which includes walk, attack, and defeat animations)

| Creature | Region | Behavior | Indirect takedown |
| --- | --- | --- | --- |
| Bee | Sunlit Meadow | Flies a fixed patrol loop and dives when the hero lines up with it; touching it is death | Dodge the dive so it hits thorns or water |
| Boar | The Briar | Walks a patrol and charges on sight; touching it is death | Dodge so it charges into thorns, off a ledge, or through a breakable wall, which also opens a path |
| Snail | Underroot Caverns | Crawls along floors, walls, and ceilings and hides in its shell when the hero comes near; harmless | Not an enemy: its hidden shell is a solid block to stand on or push |

Other indirect takedowns: push a rock off a ledge onto a creature, or let a crumbling bridge collapse under one. Taking out a creature should usually solve a puzzle or open a path, not just clear the way.

## Difficulty and optional content

The game is hard on purpose and ships with no assist mode. Fairness comes from instant respawns, honest hitboxes, and teaching each trick before testing it.

**Difficulty curve**

- **Main map:** moderate. Rooms teach and combine moves, and a death costs a few seconds.
- **Spirit Rooms:** hard. The one-run rule is where the real challenge lives.
- **Bonus Spirit Rooms:** very hard, for players who want more.
- **A sawtooth shape:** each region starts gentler than the Spirit Room before it, then builds to its own.

**Fairness rules**

- Hazards move in fixed patterns, never at random.
- Hazards look clearly dangerous, and safe ground looks safe.
- Nothing kills the player from off screen.
- The forgiveness tricks in Movement and feel apply everywhere.

**Room for an assist mode later.** Every tuning number lives in one settings file, so options like a slower game speed or an extra dash could be added later without rewriting the game.

**Optional content (about 30–45 extra minutes)**

- **Wisps** (working name): about 30 hidden collectibles, 3–5 per region, most behind paths that need a later color.
- **Bonus Spirit Rooms:** about 4 hidden rooms, harder than any on the main path, each ending in wisps.
- **The reward:** collecting every wisp unlocks an alternate ending.
- **For competing with friends:** best times per Spirit Room and an optional on-screen speedrun timer.

## Camera, controls, and UI

The screen stays clean: a scrolling camera, no HUD during play, and the hero's body showing which abilities are ready.

**Camera**

- The game draws at 480×270 (the prototype's view size) and scales up by whole numbers, 4× on a 1080p screen, so pixels stay crisp.
- Rooms scroll like Super Meat Boy's. The camera follows smoothly, stays inside the room, and looks ahead in the direction of movement.
- A small vertical dead zone keeps jumps from shaking the view.
- Moving between rooms uses the prototype's letterbox slide transition.

**Default controls** (all remappable; a button shows up in prompts only once its ability is unlocked)

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move and aim | WASD or arrow keys | Left stick or D-pad |
| Jump | Space | A |
| Dash | J | X |
| Slide | K | B |
| Grab (push, pull, climb) | L | Right trigger |
| Spirit Phase | I | Y |
| Map | Tab | View / Back |
| Pause | Esc | Menu / Start |

**UI**

- **The body is the HUD.** A body part glows in its color when its ability is ready and dims once used, the way Madeline's hair changes color in Celeste. This covers dash, double jump, and Spirit Phase.
- **Pause menu:** resume, map, settings, leave Spirit Room, quit.
- **Map:** visited rooms drawn as simple blocks, with Spirit Rooms and checkpoints marked.
- **Title screen:** three save slots.
- **Settings:** music and sound volume, control remapping, fullscreen and window size, screen shake on or off, speedrun timer on or off.

## Art and audio

The art already exists for nearly everything; the main new visual work is the grey-to-color effect, done with shaders rather than redrawn sprites.

**Art spec**

- Pixel art on 16×16 tiles, at the 480×270 base resolution.
- The hero's animations sit in 48×48 frames, with a body about 19×30 px.
- Tiles, trees, props, backgrounds, and creatures come from the Legacy-Fantasy High Forest pack. The hero comes from Asset Packs 1–5. Both are already in the repo.

**Grey to color**

- **The hero:** one palette-swap shader turns each body part grey until its color is earned. Each part keeps its own small set of shades across every animation, so no grey copies of the sprites are needed. Dash and Slide add a few effect colors that need mapping too.
- **The world:** it starts desaturated, and a full-screen shader sets each region's color strength. Clearing a region's Spirit Room animates its color back in.
- **The hub:** the great tree in the Hollow gains a band of each color as it returns.
- **Spirit Phase:** no new art. The spirit is the hero's own sprite drawn glowing and blue.
- **Worth testing early:** bringing color back by hue across the whole world, so every orange in the forest returns with orange. It could look striking, but it depends on how the art's colors fall.

**Audio** (free packs as placeholders; check each license)

- **Music:** one calm track per region and a tense track for Spirit Rooms. A region's track gains an instrument layer when its color returns.
- **Sound effects to source first:** jump, double jump, dash, slide, wall jump, land, death, respawn, checkpoint, and color unlock.
- **Sources:** itch.io and OpenGameArt packs for music; sfxr-style generators for quick retro effects.

## Technical plan in Godot

The game is built in Godot 4.7 with GDScript; 4.7.2, released August 18, 2026, is the current stable version. The setup keeps everything in plain text files and small scripts, so Claude can read and change all of it.

**Project settings**

- Base viewport 480×270, window 1920×1080, stretch mode set to viewport with integer scaling.
- Nearest-neighbor texture filtering, with 2D positions snapped to whole pixels.
- Physics at 60 ticks per second, matching the prototype's numbers.

**Folder layout**

```
res://
  game/      always-loaded scripts: game state, saving, room changes, audio
  player/    player scene, one script per movement state, tuning file
  rooms/     _template/ plus one folder per region
  entities/  hazards, creatures, push blocks, spirit barriers, and other objects
  ui/        title, pause, map, results card
  shaders/   palette swap, world color, spirit glow
  art/       sprites, tilesets, backgrounds
  audio/     music, sound effects
```

**Key pieces**

- **Player:** a CharacterBody2D with hand-written movement, run by a state machine with one small script per state: idle, run, jump, fall, dash, wall slide, slide, climb, ledge grab, Spirit Phase, push, and dead. Each ability checks whether its color is unlocked.
- **Tuning file:** every movement number lives in one resource file, editable in Godot's Inspector without touching code.
- **Game state:** one always-loaded script tracks colors, wisps, deaths, play time, and opened shortcuts, and saves them to a JSON file.
- **Rooms:** each room is its own scene copied from a template, with tile layers, camera bounds, spawn points, and exits that name the room and spawn point they lead to.
- **Checks:** Claude can run Godot without a window to catch script errors and run automated tests of movement rules. How it feels still needs a human playtest.

**Working with Claude**

- **Repo:** keep the existing GitHub repo, move the GameMaker project into a `gamemaker-legacy/` folder, and put the Godot project at the root. Claude needs push access to the repo for this.
- **CLAUDE.md:** a file at the repo root summarizing this doc, the folder layout, and code conventions, so every session starts with context.
- **Small steps:** one feature, one playtest, one commit, so any change can be rolled back.
- **Describe feel concretely:** "the jump floats at the top" or "the dash goes a tile too far" is enough to act on.
- **Effort:** high for the player controller, new systems, and stubborn bugs; medium for importing art, adding a hazard, or small tweaks.

## Assets to carry over

Every ability in this doc already has animations in the repo, so the move to Godot needs no new character art. The GameMaker code is rewritten in GDScript rather than ported line by line.

| Asset | Source in the repo | Used for |
| --- | --- | --- |
| Idle, walk, run, jump, land | Asset Packs 1–5 (V1, V3) | Starting moves |
| Crouch idle and walk, push, pull, push idle | Asset Packs 1–5 (V2, V3) | Starting moves |
| Dash | Asset Packs 1–5 (V5) | Orange: Dash |
| Air spin | Asset Packs 1–5 (V2) | Yellow: Double jump |
| Wall slide, wall land | Asset Packs 1–5 (V1) | Green: Wall jump |
| Slide | Asset Packs 1–5 (V5) | Red: Slide |
| Ledge grab and climb, side climb, back climb | Asset Packs 1–5 (V2, V4) | Purple: Climb |
| Death | Asset Packs 1–5 (V3) | Death |
| Roll | Asset Packs 1–5 (V2) | Optional landing roll after a long fall |
| Tiles, trees, rocks, props, backgrounds | Legacy-Fantasy High Forest | The world |
| Boar, bee, snail | Legacy-Fantasy High Forest | Creatures |

**Leave behind:** the samurai pack, every sword, katana, punch, and shooting animation, the city skyline backgrounds, the grey idle copy (the shader replaces it), and the forest pack's own hero.

**Prototype code to keep as reference:** coyote time, jump buffering, variable jump height, the double jump values, camera clamping, and the letterbox transition. Two small prototype bugs stay behind: the transition's step code has unbalanced parentheses, and the camera calculates its smoothing but never uses it.

**Licenses to confirm before selling on Steam**

- **Asset Packs 1–5:** the repo doesn't record where these came from. Since the hero is built on them, this is the most important one to track down.
- **Legacy-Fantasy High Forest:** a free pack by Anokolisa on itch.io. The author says it can be used in commercial games, but the full terms are a separate document that may require a credit. [source](https://anokolisa.itch.io/sidescroller-pixelart-sprites-asset-pack-forest-16x16)

## Scope and build order

A 2-hour main path works out to roughly 75 rooms. That's a lot for a hobby project, so the vertical slice comes early and doubles as a check on the estimate.

| Part | First-play time | Rooms |
| --- | --- | --- |
| The Hollow | About 8 min | 6–8 |
| Six regions, exploring | About 12 min each, 72 min total | 8–12 each, about 60 total |
| Six Spirit Rooms, with retries | About 5 min each, 30 min total | 6 |
| The Heart | About 10 min | 4–6 |
| **Main path** | **About 2 hours** | **About 75** |
| Optional content | 30–45 min more | About 4 bonus rooms plus side paths |

**Build order.** Movement comes before levels, because jump height and dash reach set the size of every gap.

1. **Setup.** Godot project, folder layout, CLAUDE.md, pixel-perfect settings, hero animations imported. Done when the grey hero stands in an empty room at the right scale.
2. **Movement test room.** Starting moves, death and instant respawn, the camera, and all six abilities behind debug switches in a plain grey room. Done when the movement feels right to you and the level-building numbers are recorded.
3. **Vertical slice.** The Hollow and Ember Grove with real art, room changes, checkpoints, autosave, the first Spirit Room, and the orange unlock with its color effects. Done when a friend plays it start to finish; their time checks the 2-hour estimate.
4. **Content tools.** Room template, region color shader, map screen, the full hazard and creature set, pause and settings menus. Done when you can build a new room from the template without Claude.
5. **Regions 2–6.** One region at a time, each with its rooms, Spirit Room, color unlock, and music, playtested before the next.
6. **The Heart and endings.** The final climb, the ending, the alternate ending, and credits.
7. **Optional content and polish.** Wisps, bonus Spirit Rooms, a sound pass, particles and screen shake, control remapping.
8. **Release.** A friends build on itch.io first. Steam charges a $100 fee per game, paid back once the game earns $1,000 there. [source](https://partner.steamgames.com/doc/gettingstarted/appfee)

## Open questions

None of these block the first two milestones; each has a working answer in the doc until it's decided.

- [ ] The hero's name, and the full story, including why the colors left
- [ ] Final names for the regions, the checkpoint stones, and the wisps
- [ ] One run speed (current plan), or bring back the prototype's run button?
- [ ] Spirit Phase: steer a spirit (current plan), or a simpler phase-through dash?
- [ ] Color returns by region (current plan), or by hue across the whole world?
- [ ] Where Asset Packs 1–5 came from, and their license
- [ ] The Legacy-Fantasy pack's full terms, including any credit requirement
- [ ] What the alternate ending shows
- [ ] Music: free packs for good, or a composer later?

## Sources

- [Godot release announcements](https://godotengine.org/blog/release/): Godot 4.7.2, August 18, 2026
- [Steamworks: Steam Direct product submission fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
- [Anokolisa: Legacy-Fantasy High Forest asset pack page](https://anokolisa.itch.io/sidescroller-pixelart-sprites-asset-pack-forest-16x16)
- [Boundless Spirit GameMaker prototype on GitHub](https://github.com/Itachi-Sk8/Boundless-Spirit): prototype code, values, and art
