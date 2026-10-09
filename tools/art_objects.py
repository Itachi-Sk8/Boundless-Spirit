"""Art for the hazards, objects, and creatures, used by build_art.py.

- art/creatures/: the forest pack's boar, bee, and snail, each joined into one sheet with one
  animation per row (see the sheet notes below).
- art/objects/: small pixel-art sprites drawn here from a few colors: logs, stalactite, bounce
  flower, pressure plate, vines, spirit barrier, water and waterfall, wall cracks, branch.
"""
import math
import os

from pngio import blank, crop, load, paste, save

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOBS = os.path.join(ROOT, "gamemaker-legacy", "Assets", "Legacy-Fantasy - High Forest 2.3", "Mob")

CLEAR = (0, 0, 0, 0)
OUTLINE = (40, 26, 18, 255)
BARK_DARK = (74, 48, 30, 255)
BARK = (106, 70, 42, 255)
BARK_LIGHT = (146, 100, 60, 255)
WOOD = (200, 156, 100, 255)
RING = (150, 106, 64, 255)
LEAF_DARK = (36, 70, 28, 255)
LEAF = (78, 136, 46, 255)
LEAF_LIGHT = (128, 186, 70, 255)


def out(*parts):
    path = os.path.join(ROOT, "art", *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def put(img, x, y, color):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = color


def line(img, x0, y0, x1, y1, color):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        put(img, x0, y0, color)
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def ellipse(img, cx, cy, rx, ry, fill, edge, x_off=0):
    """A filled ellipse with a one-pixel outline."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1.0:
                inner = ((x + 0.5 - cx) / max(rx - 1, 0.5)) ** 2 + ((y + 0.5 - cy) / max(ry - 1, 0.5)) ** 2
                put(img, x + x_off, y, fill if inner <= 1.0 else edge)


# --- Creatures -----------------------------------------------------------------------------

def sheet(rows, frame_w, frame_h):
    """Join animation strips into one sheet, one strip per row, padded to the widest."""
    columns = max(len(strip[0]) // frame_w for strip in rows)
    img = blank(columns * frame_w, len(rows) * frame_h)
    for i, strip in enumerate(rows):
        paste(img, strip, 0, i * frame_h)
    return img


def build_creatures():
    mob = lambda *p: load(os.path.join(MOBS, *p))  # noqa: E731
    # Boar, 48×32 frames, facing left. Rows: idle (4), walk (6), run (6), hit (4).
    save(out("creatures", "boar.png"), sheet([
        mob("Boar", "Idle", "Idle-Sheet.png"), mob("Boar", "Walk", "Walk-Base-Sheet.png"),
        mob("Boar", "Run", "Run-Sheet.png"), mob("Boar", "Hit-Vanish", "Hit-Sheet.png"),
    ], 48, 32))
    # Bee, 64×64 frames, facing left. Rows: fly (4), attack (4), hit (4).
    save(out("creatures", "bee.png"), sheet([
        mob("Small Bee", "Fly", "Fly-Sheet.png"), mob("Small Bee", "Attack", "Attack-Sheet.png"),
        mob("Small Bee", "Hit", "Hit-Sheet.png"),
    ], 64, 64))
    # Snail, 48×32 frames, facing left. Rows: walk (8), hide (8), dead (8).
    save(out("creatures", "snail.png"), sheet([
        mob("Snail", "walk-Sheet.png"), mob("Snail", "Hide-Sheet.png"), mob("Snail", "Dead-Sheet.png"),
    ], 48, 32))


# --- Objects ---------------------------------------------------------------------------------

def log_side():
    """A log lying on its side, 48×16: bark with grain, the cut end on the left."""
    img = blank(48, 16)
    for x in range(48):
        for y in range(2, 14):
            if y in (2, 13):
                color = OUTLINE
            elif y == 3:
                color = BARK_LIGHT
            elif y <= 5:
                color = BARK
            elif y <= 10:
                color = BARK if (x * 7 + y * 13) % 19 else BARK_DARK
            else:
                color = BARK_DARK
            put(img, x, y, color)
    for y in range(3, 13):  # the cut end
        for x in range(0, 4):
            put(img, x, y, WOOD)
        put(img, 2, y, RING if 5 <= y <= 10 else WOOD)
    for y in range(4, 12):
        put(img, 0, y, OUTLINE)
        put(img, 47, y, OUTLINE)
    for x, y in ((0, 2), (0, 3), (0, 12), (0, 13), (47, 2), (47, 3), (47, 12), (47, 13)):
        put(img, x, y, CLEAR)
    for x, y in ((1, 3), (1, 12), (46, 3), (46, 12)):
        put(img, x, y, OUTLINE)
    return img


def log_end():
    """A log seen end-on, 24×24, for rolling: rings and a crack so the roll shows."""
    img = blank(24, 24)
    c = 12.0
    for y in range(24):
        for x in range(24):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if d > 11.5:
                continue
            if d > 10.5:
                color = OUTLINE
            elif d > 9.0:
                color = BARK_DARK if (x + y) % 3 else BARK
            elif 6.0 < d <= 6.9 or 3.0 < d <= 3.8:
                color = RING
            else:
                color = WOOD
            put(img, x, y, color)
    line(img, 12, 12, 19, 9, BARK_DARK)
    put(img, 12, 12, RING)
    return img


def stalactite():
    """A rock spike hanging from the ceiling, 16×32, flat side up."""
    img = blank(16, 32)
    light, mid, dark, edge = (156, 146, 134, 255), (124, 115, 106, 255), (92, 85, 79, 255), (48, 42, 38, 255)
    for y in range(31):
        half = 6.5 * (1.0 - y / 31.0)
        for x in range(16):
            offset = x + 0.5 - 8.0
            if abs(offset) > half:
                continue
            if abs(offset) > half - 1.0 or y == 0:
                color = edge
            elif offset < -half / 3:
                color = light
            elif offset > half / 3:
                color = dark
            else:
                color = mid
            put(img, x, y, color)
    for y in (4, 5, 9, 10):
        put(img, 6, y, (190, 182, 170, 255))
    return img


def flower():
    """The bounce flower, three 16×16 frames: resting, squashed, springing up."""
    img = blank(48, 16)
    petal, petal_edge = (232, 112, 162, 255), (150, 50, 100, 255)
    pad, pad_dark = (250, 214, 90, 255), (210, 160, 50, 255)
    stem = (70, 130, 46, 255)
    frames = [  # (cup center y, cup half-width, cup half-height, stem top)
        (7.5, 7.0, 2.6, 9),
        (11.0, 8.0, 2.2, 12),
        (4.5, 6.0, 3.0, 6),
    ]
    for i, (cy, rx, ry, stem_top) in enumerate(frames):
        ox = i * 16
        for y in range(stem_top, 16):
            put(img, ox + 7, y, stem)
            put(img, ox + 8, y, LEAF_DARK)
        for x in range(4, 7):
            put(img, ox + x, 14, LEAF)
        for x in range(9, 12):
            put(img, ox + x, 13, LEAF)
        ellipse(img, 8.0, cy, rx, ry, petal, petal_edge, ox)
        for x in range(5, 11):
            put(img, ox + x, int(cy) - 1, pad)
            put(img, ox + x, int(cy), pad_dark if x in (5, 10) else pad)
    return img


def plate():
    """A pressure plate, two 16×8 frames: raised and pressed, with a rune line that lights."""
    img = blank(32, 8)
    stone, light, edge = (122, 116, 108, 255), (160, 152, 140, 255), (50, 44, 40, 255)
    for i, (top, glow) in enumerate(((4, (80, 110, 130, 255)), (6, (150, 225, 255, 255)))):
        ox = i * 16
        for y in range(top, 8):
            for x in range(1, 15):
                color = edge if y == top or x in (1, 14) else (light if y == top + 1 else stone)
                put(img, ox + x, y, color)
        for x in range(4, 12):
            put(img, ox + x, top + 1 if i else top + 2, glow)
    for x in range(0, 32):  # the base slot it sinks into
        put(img, x, 7, edge)
    return img


def vine():
    """Climbable vines, three 16×16 pieces stacked: top (leafy), middle (repeats), tip."""
    img = blank(16, 48)
    for y in range(48):
        if y >= 42:
            break
        wobble = round(2 * math.sin(y * 2 * math.pi / 16))
        put(img, 7 + wobble, y, LEAF_DARK)
        put(img, 8 - wobble, y, LEAF)
        put(img, 8 + wobble, y, LEAF)
    for y0 in (3, 19, 35):  # leaves on alternating sides
        for x, y in ((3, 0), (4, 0), (5, 0), (4, 1), (5, 1), (6, 1)):
            put(img, x, y0 + y, LEAF_LIGHT if y == 0 else LEAF)
        for x, y in ((10, 8), (11, 8), (12, 8), (9, 9), (10, 9), (11, 9)):
            put(img, x, y0 + y, LEAF_LIGHT if y == 8 else LEAF)
    for y in range(0, 4):  # a clump where it hangs from
        for x in range(2, 14):
            if (x + y) % 3:
                put(img, x, y, LEAF if y else LEAF_DARK)
    for x, y in ((7, 42), (8, 42), (8, 43), (7, 44)):  # the tip
        put(img, x, y, LEAF_LIGHT)
    return img


def barrier():
    """A spirit barrier tile, 16×16: translucent blue with drifting light lines (tiles)."""
    img = blank(16, 16)
    for y in range(16):
        for x in range(16):
            if (x + y) % 8 == 0:
                img[y][x] = (180, 230, 255, 200)
            elif (x + y) % 8 == 1:
                img[y][x] = (130, 200, 245, 150)
            else:
                img[y][x] = (80, 150, 230, 80)
    return img


def water():
    """Water, four 16×16 frames across; row 0 is the surface, row 1 the depths."""
    img = blank(64, 32)
    body, light, foam = (56, 120, 178, 215), (96, 164, 212, 225), (232, 244, 250, 255)
    for f in range(4):
        for x in range(16):
            gx = f * 16 + x
            top = 3 + round(1.5 * math.sin((x + f * 4) * 2 * math.pi / 16))
            for y in range(top, 16):
                put(img, gx, y, foam if y == top else (light if y == top + 1 else body))
            for y in range(16, 32):
                put(img, gx, y, light if (x * 3 + y * 5 - f * 4) % 17 == 0 else body)
    return img


def waterfall():
    """Falling water, four 16×16 frames across, streaks moving down."""
    img = blank(64, 16)
    for f in range(4):
        for x in range(16):
            for y in range(16):
                streak = (y - f * 4 + x * 5) % 8 < 2
                put(img, f * 16 + x, y, (196, 232, 250, 225) if streak else (92, 160, 212, 195))
    return img


def cracks():
    """Cracks drawn over a breakable wall's rock, 16×16: a pale lit edge under each dark crack,
    so the wall reads as breakable against the solid rock around it."""
    img = blank(16, 16)
    dark, lit = (24, 18, 14, 255), (214, 190, 150, 255)
    segments = (((3, 0), (6, 5)), ((6, 5), (5, 9)), ((5, 9), (9, 13)), ((9, 13), (8, 15)),
                ((6, 5), (11, 7)), ((11, 7), (15, 6)), ((5, 9), (1, 11)))
    for a, b in segments:
        line(img, a[0] + 1, a[1], b[0] + 1, b[1], lit)
    for a, b in segments:
        line(img, a[0], a[1], b[0], b[1], dark)
    return img


def branch():
    """A branch to stand on, three 16×16 pieces: base (knot), middle (repeats), leafy tip."""
    img = blank(48, 16)
    for x in range(44):
        for y in range(6):
            color = (BARK_LIGHT, BARK, BARK, BARK if (x * 5) % 11 else BARK_DARK, BARK_DARK, OUTLINE)[y]
            put(img, x, y, color)
    for x, y in ((5, 2), (6, 2), (5, 3), (6, 3)):  # a knot on the base piece
        put(img, x, y, BARK_DARK)
    for y in range(6):  # rounded tip
        put(img, 44, y, OUTLINE if 0 < y < 5 else CLEAR)
    for x in range(36, 48):  # leaves hanging off the tip
        for y in range(4, 12):
            if (x * 7 + y * 3) % 5 and abs(x - 42) + abs(y - 7) < 7:
                put(img, x, y, LEAF_LIGHT if y < 6 else (LEAF if (x + y) % 2 else LEAF_DARK))
    return img


def build_objects():
    for name, image in (
        ("log_side", log_side()), ("log_end", log_end()), ("stalactite", stalactite()),
        ("flower", flower()), ("plate", plate()), ("vine", vine()), ("barrier", barrier()),
        ("water", water()), ("waterfall", waterfall()), ("cracks", cracks()), ("branch", branch()),
    ):
        save(out("objects", name + ".png"), image)
