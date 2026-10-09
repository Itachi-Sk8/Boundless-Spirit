"""Minimal PNG reading and writing with the standard library only (no Pillow needed).

Images are lists of rows of (r, g, b, a) tuples.
"""
import struct
import zlib


def load(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, palette, trns = 8, b"", None, None
    while pos < len(data):
        length, = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"PLTE":
            palette = [tuple(chunk[i:i + 3]) for i in range(0, len(chunk), 3)]
        elif kind == b"tRNS":
            trns = chunk
    assert depth == 8 and interlace == 0, (path, depth, interlace)
    bpp = {6: 4, 2: 3, 3: 1, 0: 1, 4: 2}[color]
    raw = zlib.decompress(idat)
    stride = width * bpp
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(height):
        kind, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    image = []
    for row in rows:
        out = []
        for x in range(width):
            px = row[x * bpp:(x + 1) * bpp]
            if color == 6:
                out.append(tuple(px))
            elif color == 2:
                out.append(tuple(px) + (255,))
            elif color == 3:
                k = px[0]
                out.append(palette[k] + ((trns[k] if trns and k < len(trns) else 255),))
            elif color == 0:
                out.append((px[0], px[0], px[0], 255))
            else:
                out.append((px[0], px[0], px[0], px[1]))
        image.append(out)
    return image


def save(path, image):
    height, width = len(image), len(image[0])
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in image)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def blank(width, height):
    return [[(0, 0, 0, 0)] * width for _ in range(height)]


def crop(image, x0, y0, x1, y1):
    return [row[x0:x1] for row in image[y0:y1]]


def trim(image):
    """Crop away fully transparent borders."""
    ys = [y for y, row in enumerate(image) if any(p[3] for p in row)]
    xs = [x for x in range(len(image[0])) if any(row[x][3] for row in image)]
    if not ys:
        return image
    return crop(image, xs[0], ys[0], xs[-1] + 1, ys[-1] + 1)


def paste(dest, src, x0, y0):
    """Alpha-over `src` onto `dest` at (x0, y0), clipped to `dest`."""
    for y, row in enumerate(src):
        dy = y0 + y
        if not 0 <= dy < len(dest):
            continue
        for x, p in enumerate(row):
            dx = x0 + x
            if p[3] == 0 or not 0 <= dx < len(dest[0]):
                continue
            if p[3] == 255:
                dest[dy][dx] = p
            else:
                q = dest[dy][dx]
                a = p[3] / 255.0
                out_a = a + q[3] / 255.0 * (1 - a)
                if out_a == 0:
                    continue
                mix = [int((p[i] * a + q[i] * q[3] / 255.0 * (1 - a)) / out_a) for i in range(3)]
                dest[dy][dx] = (mix[0], mix[1], mix[2], int(out_a * 255))


def flip_x(image):
    return [list(reversed(row)) for row in image]


def recolor(image, func):
    return [[func(p) if p[3] else p for p in row] for row in image]
