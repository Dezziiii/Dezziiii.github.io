#!/usr/bin/env python3
"""Render an SVG mockup of the Casio World Time watch face (390x390).

This mirrors the layout and the dot-matrix world-map data used by
source/CasioWorldTimeView.mc so the design can be previewed without the
Connect IQ simulator. It is a mockup only -- the device is the source of
truth.
"""
import datetime
import os

W = H = 390
CX = CY = 195

BG = "#99A38C"
INK = "#1B1D18"
DIM = "#6C7563"
BEZEL = "#0a0a0a"

MAP_COLS = 56
MAP = [
    [0, 22, 24],
    [1, 8, 16], [1, 22, 25], [1, 28, 31], [1, 34, 52],
    [2, 6, 20], [2, 23, 25], [2, 27, 33], [2, 34, 54],
    [3, 5, 21], [3, 26, 26], [3, 28, 34], [3, 35, 55],
    [4, 5, 21], [4, 27, 55],
    [5, 6, 20], [5, 27, 55],
    [6, 7, 19], [6, 27, 54],
    [7, 9, 16], [7, 26, 54],
    [8, 10, 15], [8, 27, 37], [8, 41, 52],
    [9, 12, 16], [9, 28, 38], [9, 42, 52],
    [10, 16, 20], [10, 29, 39], [10, 48, 53],
    [11, 16, 22], [11, 30, 38], [11, 48, 55],
    [12, 16, 24], [12, 31, 38], [12, 49, 55],
    [13, 17, 25], [13, 31, 37], [13, 50, 55],
    [14, 18, 24], [14, 32, 37], [14, 49, 55],
    [15, 18, 23], [15, 33, 36], [15, 50, 55],
    [16, 18, 22], [16, 52, 54],
    [17, 18, 21],
    [18, 18, 20],
    [19, 18, 19],
]

now = datetime.datetime.now()
parts = []
parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Helvetica,Arial,sans-serif">')

# Bezel + LCD field (round screen).
parts.append(f'<circle cx="{CX}" cy="{CY}" r="{CX}" fill="{BEZEL}"/>')
parts.append(f'<circle cx="{CX}" cy="{CY}" r="{CX-6}" fill="{BG}"/>')

# Top label.
parts.append(f'<text x="{CX}" y="78" fill="{INK}" font-size="14" font-weight="bold" '
             f'text-anchor="middle" letter-spacing="2">WORLD TIME</text>')


def frame(x, y, w, h):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" '
                 f'fill="none" stroke="{INK}" stroke-width="2"/>')


# Compass box (top-left).
bx, by, bw, bh = 56, 60, 92, 74
frame(bx, by, bw, bh)
ccx, ccy, ring = bx + bw // 2, by + 34, 20
parts.append(f'<circle cx="{ccx}" cy="{ccy}" r="{ring}" fill="none" stroke="{DIM}" stroke-width="2"/>')
for dx, dy in [(0, -ring), (0, ring), (-ring, 0), (ring, 0)]:
    parts.append(f'<line x1="{ccx+dx*0.85:.0f}" y1="{ccy+dy*0.85:.0f}" '
                 f'x2="{ccx+dx*1.15:.0f}" y2="{ccy+dy*1.15:.0f}" stroke="{INK}" stroke-width="2"/>')
parts.append(f'<polygon points="{ccx},{ccy-17} {ccx-6},{ccy+2} {ccx+6},{ccy+2}" fill="{INK}"/>')
parts.append(f'<polygon points="{ccx},{ccy+17} {ccx-6},{ccy-2} {ccx+6},{ccy-2}" fill="{DIM}"/>')
parts.append(f'<circle cx="{ccx}" cy="{ccy}" r="2" fill="{BG}"/>')
parts.append(f'<text x="{ccx}" y="{ccy-ring-11}" fill="{INK}" font-size="13" text-anchor="middle">N</text>')
parts.append(f'<text x="{ccx}" y="{by+bh-6}" fill="{INK}" font-size="11" '
             f'text-anchor="middle" letter-spacing="1">COMPASS</text>')

# Alarm box (top-right).
abw, abh = 92, 74
abx, aby = W - 56 - abw, 60
frame(abx, aby, abw, abh)
alarm_count = 2  # demo value
parts.append(f'<text x="{abx+abw//2}" y="{aby+17}" fill="{INK}" font-size="12" '
             f'text-anchor="middle" letter-spacing="2">ALARM</text>')
# bell
bcx, bcy = abx + 28, aby + 46
bell = f"{bcx-7},{bcy+6} {bcx-6},{bcy+2} {bcx-4},{bcy-4} {bcx-2},{bcy-7} {bcx},{bcy-8} {bcx+2},{bcy-7} {bcx+4},{bcy-4} {bcx+6},{bcy+2} {bcx+7},{bcy+6}"
parts.append(f'<polygon points="{bell}" fill="{INK}"/>')
parts.append(f'<rect x="{bcx-8}" y="{bcy+6}" width="16" height="2" fill="{INK}"/>')
parts.append(f'<circle cx="{bcx}" cy="{bcy+10}" r="2" fill="{INK}"/>')
parts.append(f'<text x="{abx+56}" y="{aby+52}" fill="{INK}" font-size="30" font-weight="bold" '
             f'text-anchor="middle">{alarm_count}</text>')
parts.append(f'<text x="{abx+abw//2}" y="{aby+bh-6}" fill="{INK}" font-size="11" '
             f'text-anchor="middle" letter-spacing="1">ACTIVE</text>')

# World map dots.
mapW = 308
x0 = CX - mapW // 2
y0 = 138
colSp = mapW / MAP_COLS
rowSp = 4.0
for row, c0, c1 in MAP:
    y = y0 + row * rowSp + rowSp / 2
    for c in range(c0, c1 + 1):
        x = x0 + c * colSp + colSp / 2
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="2" fill="{INK}"/>')

# Date line.
date_txt = now.strftime("%a  %-d %b %Y").upper()
parts.append(f'<text x="{CX}" y="234" fill="{INK}" font-size="13" text-anchor="middle" '
             f'letter-spacing="1">{date_txt}</text>')

# Big time + seconds.
parts.append(f'<text x="{CX-18}" y="298" fill="{INK}" font-size="74" font-weight="bold" '
             f'text-anchor="middle" font-family="Courier New,monospace">{now.strftime("%H:%M")}</text>')
parts.append(f'<text x="{CX+108}" y="298" fill="{INK}" font-size="34" font-weight="bold" '
             f'text-anchor="middle" font-family="Courier New,monospace">{now.strftime("%S")}</text>')

# Day-of-week strip.
labels = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
today = (now.weekday() + 1) % 7  # python Mon=0 -> Sun index 0
spacing = 36
startX = CX - 3 * spacing
for i, lab in enumerate(labels):
    x = startX + i * spacing
    color = INK if i == today else DIM
    weight = "bold" if i == today else "normal"
    parts.append(f'<text x="{x}" y="338" fill="{color}" font-size="14" font-weight="{weight}" '
                 f'text-anchor="middle">{lab}</text>')
    if i == today:
        parts.append(f'<line x1="{x-11}" y1="344" x2="{x+11}" y2="344" stroke="{INK}" stroke-width="2"/>')

parts.append('</svg>')

out = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "preview.svg"))
with open(out, "w") as f:
    f.write("\n".join(parts))
print("wrote", out)
