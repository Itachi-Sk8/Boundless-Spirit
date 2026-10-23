# Building a room

How to add a room to the forest in Godot, start to finish, without touching code. Everything
here is done in the editor; rooms are plain scene files under `rooms/`.

## 1. Find a spot

Open `rooms/_world_view.tscn`. It shows every room where the game puts it, labeled with its
id, its **World Origin** (top-left corner, in tiles), and its size in tiles. Spirit Rooms are
outlined in orange; two rooms that overlap are outlined in red. Press **Refresh** in its
Inspector after saving a room.

Rooms connect by position, with no exits to wire up:

- Walking off a room's edge enters whichever room is there, **but only where that room is
  open** (`.`) at that spot. Its solid ground (`#`, `%`) acts as a wall. So line up the
  openings on both sides of a shared edge.
- Falling out of the bottom with no room below is a pit: death.
- One screen is 30 × 17 tiles. A room can be any size, usually 1–4 screens.

Pick the new room's World Origin so its edge touches its neighbor's: a room 40 tiles wide at
origin (0, 0) is met on the right by a room at (40, 0).

## 2. Copy the template

In the FileSystem dock, right-click `rooms/_template/room_template.tscn` → **Duplicate**, name
it after the room (for example `briar_tunnels.tscn`), and move it into its region's folder
(`rooms/briar/`). **The file name is the room's id.** Any scene in `rooms/` is part of the
world, except in `test/` and names starting with `_`.

Open it, select the root node, and set in the Inspector:

- **World Origin:** the spot from step 1, in tiles. (The template starts at (0, 40), out of the
  way; two rooms left there will overlap.)
- **Region:** sets the backdrop tint and the name on the map.
- **Spirit Room:** only for Spirit Rooms (see below).

## 3. Shape the ground

Select **Terrain** and edit its **Layout** text. One character is one 16 px tile:

| Character | Tile |
| --- | --- |
| `#` | Grass ground |
| `%` | Rock |
| `=` | Wooden plank: jump up through it, land on top |
| `.` | Empty |

Edges and corners are picked automatically, and the room repaints as you type. **The text's
size is the room's size**, so keep every row the same length. Ground that runs off the edge
joins seamlessly with the next room.

Gap and ledge sizes come from the **Level-building numbers** in `docs/DESIGN.md` (Movement and
feel): a 4-tile ledge is a jump, 10 tiles is a comfortable gap, and so on. Each region should
ask a bit more than the one before.

### Room size

With the room open, a **yellow outline** shows the room's area and its size in tiles. The rooms
around it are drawn faintly with their names; wherever this room overlaps one, both turn
**red**. (The purple rectangle at the top-left is Godot's one-screen guide, not the room.)

To change the size, select the room's root node and open **Room Size** in the Inspector:

- **Add rows on top** / **Remove rows on top**, and the same for the **bottom**, **left**, and
  **right**. **Resize Step** is how many rows or columns each click adds or takes away.
- Adding on the top or left moves everything in the room along with the ground and moves the
  room's **World Origin** the other way, so nothing shifts in the world.
- Removing rows or columns deletes the ground in them. Every click is one step: **Ctrl+Z**
  undoes it.
- A room with a text Layout gains or loses rows and columns of `.` in its Layout. A room painted
  by hand gets a **Size Tiles** value instead (zero means "as big as the painted tiles").
- **Push Neighbours** (on by default) moves every room beyond the edge you're moving by the
  same amount, so the rooms next door stay touching and nothing overlaps: add 5 columns on the
  left and every room west of this one moves 5 tiles west. It changes their World Origin in
  their own files (Godot asks to reload any that are open, so save those first). Spirit Rooms
  never move. Ctrl+Z moves them back. Turn it off to resize without touching other rooms.
- After saving another room, press **Refresh neighbours** to see its new outline. It only
  redraws: it never moves rooms, so a red overlap it shows is real.

## 4. Spawn points

Under **Spawns**, keep **Start** (where new games and Spirit Room restarts begin) and add a
Marker2D beside each way in. After a death the hero comes back at the spawn nearest to where
it entered (or the last checkpoint stone).

## 5. Add hazards, objects, and creatures

Drag scenes from `entities/` into the room: hazards under **Hazards**, everything else under
**Entities**. Turn on grid snap (16 px) to line things up with the tiles. Every one of them is
in the gallery: in the game press F3, then F10, and 0 for all colors.

**Hazards** (one touch is death)

| Scene | What it does | Inspector settings | Origin |
| --- | --- | --- | --- |
| `thorns` | A row of thorns; grass under it turns to plain dirt (no grassy top), even as you move it | `length` (tiles), `adjust_px` (a few px longer or shorter), `direction`, `tint` | Top-left of the first tile |
| `water` | Deep water (rapids) | `size_tiles`, `flow_speed`, `flow_direction` | Top-left |
| `stalactite` | Shakes and drops when the hero passes beneath | `trigger_depth`, `trigger_half_width`, `regrow_time` | Top center, where it hangs |
| `falling_log` | The same, as a log lodged overhead | as above | Top center |
| `rolling_logs` | Releases logs that roll along the ground and smash on walls | `direction`, `speed`, `interval`, `first_delay` | On the ground where they appear |

**Objects**

| Scene | What it does | Inspector settings | Origin |
| --- | --- | --- | --- |
| `one_way_platform` | Planks: up through, land on top | `width_tiles` | Top-left |
| `crumble_platform` | Shakes, falls, comes back | `width_tiles`, `shake_time`, `return_time` | Top-left |
| `sinking_leaf` | Lily pad that sinks while stood on, floats back up | `sink_speed`, `rise_speed`, `max_sink` | Center of its top edge |
| `swaying_branch` | Platform that sways in a fixed rhythm (editor shows the swing) | `width_tiles`, `sway_distance`, `period`, `dip`, `phase` | Top-left at rest |
| `bounce_flower` | Throws the hero high, refills dash and double jump | `launch_speed`, `refills` | Bottom center |
| `push_block` / `stone_block` | Push and pull with Grab | `texture` | Bottom center |
| `pressure_plate` | Pressed by the hero, a block, or a snail's shell; switches its `targets` | `targets` (drag doors in), `latch` | Bottom center |
| `plate_door` | Stone door a plate opens | `size_tiles`, `opens_toward`, `inverted` | Top-left |
| `breakable_wall` | Shatters on a dash or a charging boar | `size_tiles`, `flag` (stays broken if set) | Top-left |
| `wind_gust` | Carries the hero sideways, lifts, or presses down; can blow in a rhythm | `size_tiles`, `direction`, `strength`, `on_time`, `off_time`, `phase` | Top-left |
| `waterfall` | Presses the hero down; jumps in it are short | `size_tiles`, `strength` | Top-left |
| `vines` | Climbable with purple (hold Grab) | `length` | Top-left of the top tile |
| `spirit_barrier` | Solid, but the spirit flies through (blue) | `size_tiles`, `tint` | Top-left |
| `dash_ember` | Refills the dash in midair | `relight_time` | Center |
| `checkpoint_stone` | Respawn point in a long room (ignored in Spirit Rooms); carries its region's rune automatically | `glyph` (another rune, 0–23; -1 = the region's) | Bottom center |
| `waystone` | Tall runed stone for travel. **Region** (one beside each Spirit Gate): a checkpoint that glows in its `color` once that color returns, then Interact opens the travel menu. **Ring**: one of the Hollow's six. **Hollow**: the Hollow's center stone, where travel home arrives | `kind`, `color` (0 orange … 5 blue) | Bottom center |
| `shortcut_gate` | Opens from one side only, for good | `flag`, `opens_from` | Bottom center |
| `color_gate` | Rock wall that falls when its color returns (shows a faint trace of it) | `color`, `size_tiles` | Top-left |
| `message_trigger` | Shows a line of text the first time it's walked through | `text`, `seconds`, `size` | Center |

**Creatures** (touching the bee or boar is death; the snail is harmless)

| Scene | What it does | Inspector settings |
| --- | --- | --- |
| `bee` | Flies its loop; dives when the hero passes beneath; dies diving into thorns or water | `patrol` (points relative to its start; the editor draws them), `speed`, `dive_range` |
| `boar` | Walks, turns at walls and ledges, charges on sight; smashes breakable walls; dazed by walls; dies in thorns, water, or pits | `facing`, `walks`, `sight_range`, `charge_speed` |
| `snail` | Crawls over floors, walls, and ceilings; hides when the hero is near, and its shell is a push block | `surface`, `clockwise`, `hide_distance` |

Everything goes back to its start when the hero dies.

## 6. Decorate

Drag PNGs from `art/props/` into **Props** (behind the ground: trees, big rocks) or **Decor**
(in front: bushes, mushrooms, stones). Tips go in **Signs** as Labels. Keep decoration from
hiding hazards, and make sure safe ground looks safe.

## 7. Try it

- Press **F6** with the room open: the game starts in it.
- **Tab** shows the map; your room appears once visited.
- Back in `rooms/_world_view.tscn`, press **Refresh** and check for red outlines. Overlapping
  rooms also print a warning when the game starts.
- Ask Claude to run the tests, or run them yourself (see `CLAUDE.md`, "Running and checking").
  The full-slice playthrough only covers the slice's rooms.

## Spirit Rooms

1. Build the room as above and tick **Spirit Room** on its root. It has no checkpoints, the
   run is timed, and every death restarts it at **Start**.
2. A Spirit Room stands apart from the world, so make it any size: its **World Origin** is
   ignored, nothing joins its edges (they're walls, and falling out is a death), and it isn't
   on the map or in the World View. Open its own scene to see it.
3. Put a `color_orb` at the end and set its `color` (0 orange, 1 yellow, 2 green, 3 red,
   4 purple, 5 blue).
4. In the room outside, place a `spirit_gate` (from `entities/`) on the ground, origin at the
   bottom center of its doorway. Leave **Mode** on Entrance, set **Target Room** to the Spirit
   Room's id and **Target Spawn** to `Start`. The player stands in the doorway and presses
   Interact (C, or the right bumper).
5. Inside, place another `spirit_gate` near the orb and set **Mode** to Exit. It stays dark until
   the color is taken, then takes the hero back to the gate they came in through. The pause
   menu's **Leave Spirit Room** goes to the same place at any time.

**Changing the gate's look**

- **The stone** is one image: `art/gate/spirit_gate.png` (128×128 px). It's yours to repaint,
  and the art build script never touches `art/gate/`. If you redraw it at another size, set the
  gate's **Opening** (the doorway's rectangle in the image, in px from its top-left corner) so
  the portal and the trigger follow. **Stone Tint** recolors it without repainting.
- **The runes** are separate: right-click the gate → **Editable Children**, then move a Rune
  under `Runes`, change its **Glyph** (0–23, from `art/gate/runes.png`, 8 per row), or tick
  **Own Color** to give it its own color. Draw new glyphs in `art/gate/runes.png` (16×16 each),
  or point the gate's **Glyph Sheet** at another sheet.
- **The colors:** **Rune Color**, **Portal Color**, **Portal Speed**, and **Motes Color** in the
  gate's Inspector. **Portal Overhang** sets how far the glow reaches under the stone past the
  doorway's sides and top (the glow fades at its edges, so this makes it fill the doorway).
  The portal's size follows the doorway, so set it here rather than resizing the Portal node.

## Good to know

- Room files are the source of truth. If Godot says a file changed on disk (Claude edited it),
  choose **Reload**.
- After Claude changes `project.godot`, use **Project → Reload Current Project**.
- Don't scale things with the Scale handles: pixel art gets uneven pixels, and collision grows
  with it. Use each object's size settings (`length`, `size_tiles`, `width_tiles`) instead.
