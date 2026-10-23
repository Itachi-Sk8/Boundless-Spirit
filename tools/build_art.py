"""Builds the game's art from the asset packs in gamemaker-legacy/Assets.

Run from the repo root:   python tools/build_art.py
Everything it writes goes under art/. Rerun it after changing anything here; the outputs
are committed so the game runs without it. Standard library only.

What it makes:
- art/tilesets/forest.png + forest.tres: the forest terrain (grass and rock, all 16 edge
  combinations, built from the pack's 9-slice blocks), plank one-way platforms, and thorns.
- art/props/: trees, bushes, mushrooms, flowers, stones, the leaf platform.
- art/backgrounds/: the sky and two seamless strips of distant forest for parallax.
- art/ui/: the parchment and wood panels and the clock, skull, and trophy icons.
- art/entities/: rune glyphs (for the Spirit Room archway), checkpoint stone (carved, and
  uncarved for the per-region runes), gate, boulder.
- art/creatures/ and art/objects/: see tools/art_objects.py.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import blank, crop, flip_x, load, paste, recolor, save, trim  # noqa: E402
from art_objects import build_creatures, build_objects  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOREST = os.path.join(ROOT, "gamemaker-legacy", "Assets", "Legacy-Fantasy - High Forest 2.3")
TILE = 16

# Edge bits for terrain tiles: set when that neighbor is empty.
UP, DOWN, LEFT, RIGHT = 1, 2, 4, 8

# The pack's terrain blocks are 5×5 9-slices. The tiles are cut so the ground the hero stands
# on lands on the 16 px grid: for grass that's the dark soil under the grass (16 px into the
# block), with the grass blades above it drawn as a separate "grass top" tile in the cell
# above, behind the hero; for rock it's the top of the boulders (3 px into the cut). These are
# the source rows (y) of the top, middle, and bottom slices, and the x of the left column.
GRASS = {"x": 0, "top": 16, "mid": 40, "mid_alt": 48, "bottom": 56}
ROCK = {"x": 0, "top": 91, "mid": 120, "mid_alt": 104, "bottom": 136}
# The grass blades above the soil: these pack rows go at the bottom of a grass top tile.
GRASS_BLADES = (8, 16)

# Atlas layout of forest.png (column, row).
ATLAS_COLUMNS = 16
GRASS_ROW, ROCK_ROW, VARIANT_ROW, MISC_ROW = 0, 1, 2, 3
# Grass tops (blades over the soil, drawn in the empty cell above): by edge mask for the grass
# row, and in the same column as the top-surface variants for those.
GRASS_TOP_ROW, GRASS_TOP_VARIANT_ROW = 4, 5
ATLAS_ROWS = 6
PLANK_LEFT, PLANK_MID, PLANK_RIGHT, PLANK_SINGLE = (0, MISC_ROW), (1, MISC_ROW), (2, MISC_ROW), (3, MISC_ROW)
THORNS = {"up": (4, MISC_ROW), "down": (5, MISC_ROW), "right": (6, MISC_ROW), "left": (7, MISC_ROW)}


def out_path(*parts):
    path = os.path.join(ROOT, "art", *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def forest(*parts):
    return load(os.path.join(FOREST, *parts))


# --- Terrain -------------------------------------------------------------------------------

def terrain_tile(sheet, block, mask, mid_col=16, mid_row=None):
    """Compose one 16×16 tile from the 9-slice by quadrants: each 8×8 quarter comes from the
    edge, corner, or middle piece that matches the two sides it touches."""
    mid_row = block["mid"] if mid_row is None else mid_row
    cols = {"L": block["x"], "M": block["x"] + mid_col, "R": block["x"] + 64}
    rows = {"T": block["top"], "M": mid_row, "B": block["bottom"]}
    tile = blank(TILE, TILE)
    for qy in (0, 1):
        for qx in (0, 1):
            row = ("T" if mask & UP else "M") if qy == 0 else ("B" if mask & DOWN else "M")
            col = ("L" if mask & LEFT else "M") if qx == 0 else ("R" if mask & RIGHT else "M")
            sx, sy = cols[col] + qx * 8, rows[row] + qy * 8
            for y in range(8):
                tile[qy * 8 + y][qx * 8:qx * 8 + 8] = sheet[sy + y][sx:sx + 8]
    return tile


def grass_top(sheet, mask, mid_col=16):
    """The grass blades over a top-edge grass tile, at the bottom of a 16×16 tile meant for the
    empty cell above it. Its sides follow the tile's left and right edges."""
    cols = {"L": GRASS["x"], "M": GRASS["x"] + mid_col, "R": GRASS["x"] + 64}
    y0, y1 = GRASS_BLADES
    tile = blank(TILE, TILE)
    for qx in (0, 1):
        col = ("L" if mask & LEFT else "M") if qx == 0 else ("R" if mask & RIGHT else "M")
        sx = cols[col] + qx * 8
        for y in range(y0, y1):
            tile[TILE - (y1 - y)][qx * 8:qx * 8 + 8] = sheet[y][sx:sx + 8]
    return tile


def thorns_up():
    """Brambles: a woody vine along the base with pale thorns pointing up, 11 px tall."""
    tile = blank(TILE, TILE)
    outline, wood, light, tip = (46, 30, 24, 255), (98, 64, 44, 255), (132, 92, 62, 255), (222, 206, 168, 255)
    for x in range(TILE):
        wave = 12 + (1 if (x // 4) % 2 else 0)
        for y in range(wave, TILE):
            tile[y][x] = outline if y in (wave, TILE - 1) else (light if y == wave + 1 else wood)
    for cx in (2.5, 7.5, 12.5):
        for y in range(5, 13):
            half = (y - 5) / 7.0 * 2.2
            for x in range(TILE):
                d = abs(x - cx)
                if d <= half + 0.5:
                    tile[y][x] = outline if d > half - 0.5 else (tip if y < 8 else light)
    return tile


def rotate_tile(tile, direction):
    """Rotate an up-pointing tile to point down, right, or left (base on the opposite edge)."""
    n = len(tile)
    if direction == "up":
        return tile
    if direction == "down":
        return [list(reversed(row)) for row in reversed(tile)]
    if direction == "right":  # base on the left edge
        return [[tile[n - 1 - x][y] for x in range(n)] for y in range(n)]
    return [[tile[x][n - 1 - y] for x in range(n)] for y in range(n)]  # left: base on the right


def build_tileset():
    sheet = forest("Assets", "Tiles.png")
    atlas = blank(ATLAS_COLUMNS * TILE, ATLAS_ROWS * TILE)

    def put(tile, col, row):
        paste(atlas, tile, col * TILE, row * TILE)

    for mask in range(16):
        put(terrain_tile(sheet, GRASS, mask), mask, GRASS_ROW)
        put(terrain_tile(sheet, ROCK, mask), mask, ROCK_ROW)
        if mask & UP:
            put(grass_top(sheet, mask), mask, GRASS_TOP_ROW)
    # Variants for the two most common tiles (solid inside, and top surface), so large areas
    # don't repeat one tile. Godot picks among same-shaped tiles by probability.
    variants = []
    col = 0
    for terrain, block in ((0, GRASS), (1, ROCK)):
        for mask in (0, UP):
            for mid_col, mid_row in ((32, block["mid_alt"]), (48, block["mid"])):
                put(terrain_tile(sheet, block, mask, mid_col, mid_row), col, VARIANT_ROW)
                if block is GRASS and mask == UP:
                    put(grass_top(sheet, mask, mid_col), col, GRASS_TOP_VARIANT_ROW)
                variants.append((col, terrain, mask))
                col += 1
    # Planks: the pack's log bridge top, cut into ends and middle.
    planks = crop(sheet, 80, 96, 144, 112)
    put(crop(planks, 0, 0, 16, 16), *PLANK_LEFT)
    put(crop(planks, 16, 0, 32, 16), *PLANK_MID)
    put(crop(planks, 48, 0, 64, 16), *PLANK_RIGHT)
    single = blank(TILE, TILE)
    paste(single, crop(planks, 0, 0, 8, 16), 0, 0)
    paste(single, crop(planks, 56, 0, 64, 16), 8, 0)
    put(single, *PLANK_SINGLE)
    up = thorns_up()
    for direction, cell in THORNS.items():
        put(rotate_tile(up, direction), *cell)
    save(out_path("tilesets", "forest.png"), atlas)
    write_tileset_resource(variants)


def write_tileset_resource(variants):
    """forest.tres: one atlas, a terrain set (match sides) for grass and rock so terrain can be
    painted in the editor, and collision matching the test tileset's physics layers."""
    full = "PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)"
    lines = []

    def tile(col, row, *props):
        lines.append(f"{col}:{row}/0 = 0")
        for prop in props:
            lines.append(f"{col}:{row}/0/{prop}")

    def terrain_props(terrain, mask):
        props = ["terrain_set = 0", f"terrain = {terrain}", f"physics_layer_0/polygon_0/points = {full}"]
        for bit, side in ((UP, "top_side"), (DOWN, "bottom_side"), (LEFT, "left_side"), (RIGHT, "right_side")):
            if not mask & bit:
                props.append(f"terrains_peering_bit/{side} = {terrain}")
        return props

    for mask in range(16):
        tile(mask, GRASS_ROW, *terrain_props(0, mask))
        tile(mask, ROCK_ROW, *terrain_props(1, mask))
    for col, terrain, mask in variants:
        tile(col, VARIANT_ROW, *terrain_props(terrain, mask), "probability = 0.35")
        if terrain == 0 and mask == UP:
            tile(col, GRASS_TOP_VARIANT_ROW)
    # Grass tops: art only (TerrainLayout puts them above top-edge grass).
    for mask in range(16):
        if mask & UP:
            tile(mask, GRASS_TOP_ROW)
    plank = ["physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, -3, -8, -3)",
             "physics_layer_0/polygon_0/one_way = true"]
    for cell in (PLANK_LEFT, PLANK_MID, PLANK_RIGHT, PLANK_SINGLE):
        tile(*cell, *plank)
    # Thorns hurt only from a box smaller than the art (doc: "hard but fair").
    hurt = {
        "up": "-6, -1, 6, -1, 6, 8, -6, 8",
        "down": "-6, -8, 6, -8, 6, 1, -6, 1",
        "right": "-8, -6, 1, -6, 1, 6, -8, 6",
        "left": "-1, -6, 8, -6, 8, 6, -1, 6",
    }
    for direction, cell in THORNS.items():
        tile(*cell, f"physics_layer_1/polygon_0/points = PackedVector2Array({hurt[direction]})")

    text = "\n".join([
        # A fixed uid, so scenes saved in the editor keep finding the tileset after a rebuild.
        '[gd_resource type="TileSet" format=3 uid="uid://caqmra0ad1sno"]',
        "",
        '[ext_resource type="Texture2D" path="res://art/tilesets/forest.png" id="1_forest"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_forest"]',
        'texture = ExtResource("1_forest")',
        "texture_region_size = Vector2i(16, 16)",
        *lines,
        "",
        "[resource]",
        "terrain_set_0/mode = 2",
        'terrain_set_0/terrain_0/name = "Grass"',
        "terrain_set_0/terrain_0/color = Color(0.42, 0.6, 0.2, 1)",
        'terrain_set_0/terrain_1/name = "Rock"',
        "terrain_set_0/terrain_1/color = Color(0.5, 0.42, 0.32, 1)",
        "physics_layer_0/collision_layer = 1",
        "physics_layer_0/collision_mask = 0",
        "physics_layer_1/collision_layer = 4",
        "physics_layer_1/collision_mask = 0",
        "physics_layer_2/collision_layer = 8",
        "physics_layer_2/collision_mask = 0",
        "physics_layer_3/collision_layer = 32",
        "physics_layer_3/collision_mask = 0",
        'sources/0 = SubResource("TileSetAtlasSource_forest")',
        "",
    ])
    with open(out_path("tilesets", "forest.tres"), "w", newline="\n") as f:
        f.write(text)


# --- Props ---------------------------------------------------------------------------------

TREE_CUTS = {  # (x0, y0, x1, y1) in every tree sheet; the sheets share one layout
    "big": (0, 0, 107, 368),
    "medium": (2, 391, 110, 704),
    "small": (4, 720, 92, 928),
}


def build_props():
    for color in ("green", "red", "golden", "yellow", "dark"):
        sheet = forest("Trees", f"{color.capitalize()}-Tree.png")
        for size, box in TREE_CUTS.items():
            save(out_path("props", f"tree_{color}_{size}.png"), trim(crop(sheet, *box)))
    green = forest("Trees", "Green-Tree.png")
    save(out_path("props", "tree_dead.png"), trim(crop(green, 309, 720, 364, 928)))
    tiles = forest("Assets", "Tiles.png")
    cuts = {
        "mushroom_big": (256, 240, 288, 272),
        "mushroom_big_b": (288, 240, 320, 272),
        "mushroom_small": (240, 240, 256, 256),
        "mushroom_small_b": (240, 256, 256, 272),
        "mushroom_small_c": (320, 248, 336, 272),
        "flowers_blue": (240, 272, 272, 304),
        "lavender": (272, 272, 288, 304),
        "cattail": (256, 288, 272, 304),
        "fern": (320, 352, 352, 384),
    }
    for name, box in cuts.items():
        save(out_path("props", f"{name}.png"), trim(crop(tiles, *box)))
    for i, y in enumerate((0, 48, 96, 144, 192)):
        save(out_path("props", f"bush_{i}.png"), trim(crop(tiles, 272, y, 400, y + 48)))
    # The lily pad's leaf, without its stem, is the sinking leaf platform.
    leaf = [[p if p[1] > p[2] else (0, 0, 0, 0) for p in row] for row in crop(tiles, 272, 304, 304, 324)]
    save(out_path("props", "leaf_platform.png"), trim(leaf))
    # The great tree in the Hollow: the pack's trunk with a sealed, softly lit doorway, stacked
    # tall enough to run off the top of the screen.
    # Bottom to top: the doorway's lower half and arched top, then the trunk above, its seam
    # of light running up the tree.
    trees = forest("Assets", "Tree-Assets.png")
    door_low = crop(trees, 0, 144, 64, 208)
    door_arch = crop(trees, 0, 80, 64, 128)
    bark = crop(trees, 0, 160, 64, 192)
    pieces = [bark] * 9 + [door_arch, door_low]
    trunk = blank(64, sum(len(piece) for piece in pieces))
    y = 0
    for piece in pieces:
        paste(trunk, piece, 0, y)
        y += len(piece)
    save(out_path("props", "great_tree.png"), trunk)
    rocks = forest("Assets", "Props-Rocks.png")
    stones = {
        "stone_tall": (0, 160, 52, 256),
        "stone_tall_b": (64, 176, 116, 256),
        "stone_round": (112, 192, 156, 256),
        "stone_wide": (160, 208, 224, 256),
    }
    for name, box in stones.items():
        save(out_path("props", f"{name}.png"), trim(crop(rocks, *box)))


# --- Backgrounds ---------------------------------------------------------------------------

# The pack's background sheet holds two hills of distant trees, each split into three
# segments with 16 px gaps (x ranges). Joined in order, each is one 319 px wide hill.
FAR_HILL = [(352, 448), (464, 560), (576, 703)]  # light, farther away
MID_HILL = [(0, 96), (112, 208), (224, 351)]  # dark, nearer


def tree_hill(segments):
    sheet = forest("Trees", "Background.png")
    parts = [crop(sheet, x0, 0, x1, len(sheet)) for x0, x1 in segments]
    hill = blank(sum(len(p[0]) for p in parts), len(sheet))
    x = 0
    for part in parts:
        paste(hill, part, x, 0)
        x += len(part[0])
    return hill


def forest_strip(width, segments, seed, step=(150, 230), lift=40):
    """A seamless strip of overlapping tree hills, some flipped and raised a little.
    Hills near the right edge wrap around, so the strip tiles horizontally."""
    rng = random.Random(seed)
    hill = tree_hill(segments)
    strip = blank(width, len(hill) + lift)
    x = 0
    while x < width:
        shape = flip_x(hill) if rng.random() < 0.5 else hill
        y = rng.randint(0, lift)
        for offset in (-width, 0, width):
            paste(strip, shape, x + offset - len(hill[0]) // 2, y)
        x += rng.randint(*step)
    # Hills sit at different heights; fill under them so the strip's bottom is solid.
    base = next(p for p in hill[-1] if p[3])
    for y in range(len(hill), len(strip)):
        for x in range(width):
            if strip[y][x][3] == 0:
                strip[y][x] = base
    return strip


def build_backgrounds():
    save(out_path("backgrounds", "sky.png"), forest("Background", "Background.png"))
    save(out_path("backgrounds", "forest_far.png"), forest_strip(960, FAR_HILL, 7))
    save(out_path("backgrounds", "forest_mid.png"), forest_strip(960, MID_HILL, 11))


# --- UI ------------------------------------------------------------------------------------

def build_ui():
    hud = forest("HUD", "Base-01.png")
    save(out_path("ui", "panel_parchment.png"), crop(hud, 0, 0, 64, 64))
    save(out_path("ui", "panel_wood.png"), crop(hud, 16, 224, 64, 288))
    for name, box in {"icon_skull": (0, 256, 16, 272), "icon_clock": (0, 272, 16, 288),
                      "icon_trophy": (48, 192, 64, 208)}.items():
        save(out_path("ui", f"{name}.png"), crop(hud, *box))


# --- Entities ------------------------------------------------------------------------------

def rune(index, glowing):
    """One 16×16 rune glyph: carved dark, or the blue glowing set."""
    rocks = forest("Assets", "Props-Rocks.png")
    x0 = (144 if glowing else 0) + 16 * index
    return crop(rocks, x0, 256, x0 + 16, 272)


def glow_runes(glyphs, color):
    """Recolor rune glyphs to `color` and add a soft one-pixel halo around them."""
    height, width = len(glyphs), len(glyphs[0])
    out = blank(width, height)
    for y in range(height):
        for x in range(width):
            if glyphs[y][x][3]:
                for dy in (-2, -1, 0, 1, 2):
                    for dx in (-2, -1, 0, 1, 2):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < height and 0 <= nx < width and out[ny][nx][3] < 70:
                            out[ny][nx] = color + (70 if abs(dx) + abs(dy) <= 2 else 35,)
    for y in range(height):
        for x in range(width):
            if glyphs[y][x][3]:
                out[y][x] = tuple(min(255, c + 60) for c in color) + (255,)
    return out


def build_entities():
    # Rune glyphs for carved, glowing lettering (the Spirit Room archway): every glyph of the
    # pack's rune set in white on a 16×16 grid, 8 per row, so the game can color each one.
    rocks = forest("Assets", "Props-Rocks.png")
    runes = blank(8 * TILE, 3 * TILE)
    for row in range(3):
        for col in range(8):
            x0, y0 = 144 + col * TILE, 256 + row * TILE
            glyph = recolor(crop(rocks, x0, y0, x0 + TILE, y0 + TILE), lambda p: (255, 255, 255, p[3]))
            paste(runes, glyph, col * TILE, row * TILE)
    save(out_path("entities", "runes.png"), runes)
    # Checkpoint stone: the round standing stone with a rune that lights when touched.
    rocks = forest("Assets", "Props-Rocks.png")
    stone = trim(crop(rocks, 112, 192, 156, 256))
    sw, sh = len(stone[0]), len(stone)
    # The same stone uncarved: the game draws each region's rune on it (CheckpointStone).
    save(out_path("entities", "checkpoint_stone.png"), stone)
    off = [row[:] for row in stone]
    rx, ry = sw // 2 - 8, sh // 3 - 8
    paste(off, recolor(rune(2, False), lambda p: (44, 34, 28, 220)), rx, ry)
    save(out_path("entities", "checkpoint_off.png"), off)
    lit = blank(sw, sh)
    paste(lit, glow_runes(rune(2, True), (200, 236, 245)), rx, ry)
    save(out_path("entities", "checkpoint_glow.png"), lit)
    # Push block: a small boulder from the rock sheet, sitting on the bottom of a 16×16 cell.
    boulder = trim(crop(rocks, 161, 1, 176, 15))
    block = blank(16, 16)
    paste(block, boulder, (16 - len(boulder[0])) // 2, 16 - len(boulder))
    save(out_path("entities", "stone_block.png"), block)
    # Shortcut gate: three wooden posts with cross bars, 16×48.
    gate = blank(16, 48)
    outline, wood, light = (46, 30, 24, 255), (110, 74, 46, 255), (146, 102, 66, 255)
    for x0 in (0, 6, 11):
        for y in range(2, 48):
            for x in range(x0, min(16, x0 + 5)):
                edge = x in (x0, x0 + 4) or y == 2
                gate[y][x] = outline if edge else (light if x == x0 + 1 else wood)
        for x in range(x0 + 1, min(16, x0 + 4)):
            gate[1][x] = outline
    for y0 in (10, 34):
        for y in range(y0, y0 + 4):
            for x in range(16):
                gate[y][x] = outline if y in (y0, y0 + 3) else light
    save(out_path("entities", "gate.png"), gate)


if __name__ == "__main__":
    build_tileset()
    build_props()
    build_backgrounds()
    build_ui()
    build_entities()
    build_creatures()
    build_objects()
    print("art built")
