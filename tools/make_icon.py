#!/usr/bin/env python3
"""Generate the launcher icon PNG using only the Python standard library.

Produces a 40x40 icon resembling the Casio AE1200 world-time face:
a light LCD tile with a dark frame and a small dot-matrix world map.
"""
import struct
import zlib
import os

W = H = 40

# Palette (R, G, B)
BEZEL = (20, 20, 22)
LCD = (150, 165, 140)          # greenish-grey LCD
DARK = (28, 30, 26)            # dark "segments" / map dots

# Tiny dot-matrix world map (rows of land cells), 18 wide x 7 tall.
MAP_W, MAP_H = 18, 7
MAP = [
    "  ##    ###   ####",
    " ####  ## ## ######",
    " ###    ###   ####",
    "  ##   ####   ## ##",
    "  #    ###     ###",
    "  #     ##      ##",
    "  #     #      ##",
]


def px(x, y):
    """Return the RGB color for pixel (x, y)."""
    # Outer rounded bezel.
    bx, by = W / 2.0, H / 2.0
    # Frame: 3px border.
    if x < 3 or y < 3 or x >= W - 3 or y >= H - 3:
        return BEZEL
    # LCD field.
    color = LCD
    # Draw the world map band in the upper-middle of the tile.
    map_x0, map_y0 = 7, 9
    cell = 1  # 1px cells with 1px spacing
    for row in range(MAP_H):
        line = MAP[row]
        for col in range(min(MAP_W, len(line))):
            if line[col] != " ":
                cx = map_x0 + col
                cy = map_y0 + row
                if x == cx and y == cy:
                    return DARK
    # Two big "time" bars near the bottom (suggesting digits).
    if 26 <= y <= 33:
        if 8 <= x <= 17 or 22 <= x <= 31:
            if (y - 26) % 4 != 3:  # leave a little gap to read as segments
                return DARK
    return color


# Build raw image (RGB) then zlib-compress with PNG filtering (filter 0 per row).
raw = bytearray()
for y in range(H):
    raw.append(0)  # filter type 0 (None) for this scanline
    for x in range(W):
        r, g, b = px(x, y)
        raw += bytes((r, g, b))

compressed = zlib.compress(bytes(raw), 9)


def chunk(tag, data):
    out = struct.pack(">I", len(data)) + tag + data
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return out + struct.pack(">I", crc)


png = b"\x89PNG\r\n\x1a\n"
ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)  # 8-bit, color type 2 (RGB)
png += chunk(b"IHDR", ihdr)
png += chunk(b"IDAT", compressed)
png += chunk(b"IEND", b"")

out_path = os.path.join(os.path.dirname(__file__), "..", "resources", "drawables", "launcher_icon.png")
out_path = os.path.normpath(out_path)
with open(out_path, "wb") as f:
    f.write(png)
print("wrote", out_path, len(png), "bytes")
