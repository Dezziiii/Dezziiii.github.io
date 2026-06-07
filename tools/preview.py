#!/usr/bin/env python3
"""Render an SVG mockup of the Casio AE1200-style watch face (390x390).

Mirrors source/CasioWorldTimeView.mc: a black resin case with printed text,
a rounded rectangular grey-green LCD panel, true 7-segment digits, the
dot-matrix world map with a city cursor, a steps/HR window (top-left) and
an alarm window (top-right). Mockup only -- the device is the source of truth.
"""
import datetime
import os

W = H = 390
CX = CY = 195

# Palette
CASE = "#070707"        # black resin case
CASE_TX = "#c9ccc4"     # printed light-grey case text
PANEL = "#949f88"       # grey-green positive LCD
PANEL_EDGE = "#3c4438"  # LCD frame
INK = "#1b1e18"         # active "on" segments / dark ink
GHOST = "#86927b"       # faint "off" segments (classic LCD ghosting)
DIM = "#5d6655"

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

# 7-segment masks, bit order [a, b, c, d, e, f, g].
SEG = {
    "0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg",
    "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc",
    "8": "abcdefg", "9": "abcdfg", " ": "",
}

P = []


def slantx(x, py, ytop, h, k):
    return x + (ytop + h - py) * k


def hpoly(lx, ty, L, t, ytop, h, k):
    pts = [
        (lx,         ty + t / 2),
        (lx + t / 2, ty),
        (lx + L - t / 2, ty),
        (lx + L,     ty + t / 2),
        (lx + L - t / 2, ty + t),
        (lx + t / 2, ty + t),
    ]
    return " ".join(f"{slantx(x,y,ytop,h,k):.1f},{y:.1f}" for x, y in pts)


def vpoly(lx, ty, L, t, ytop, h, k):
    pts = [
        (lx + t / 2, ty),
        (lx + t,     ty + t / 2),
        (lx + t,     ty + L - t / 2),
        (lx + t / 2, ty + L),
        (lx,         ty + L - t / 2),
        (lx,         ty + t / 2),
    ]
    return " ".join(f"{slantx(x,y,ytop,h,k):.1f},{y:.1f}" for x, y in pts)


def seg7(x, y, w, h, t, ch, on=INK, off=GHOST, k=0.10):
    """Append polygons for one 7-segment digit at (x, y)."""
    half = h / 2.0
    geo = {
        "a": hpoly(x, y, w, t, y, h, k),
        "g": hpoly(x, y + half - t / 2, w, t, y, h, k),
        "d": hpoly(x, y + h - t, w, t, y, h, k),
        "f": vpoly(x, y, half + t / 2, t, y, h, k),
        "b": vpoly(x + w - t, y, half + t / 2, t, y, h, k),
        "e": vpoly(x, y + half - t / 2, half + t / 2, t, y, h, k),
        "c": vpoly(x + w - t, y + half - t / 2, half + t / 2, t, y, h, k),
    }
    onset = SEG.get(ch, "")
    # draw ghosts first, then lit segments on top
    for name in "abcdefg":
        if name not in onset:
            P.append(f'<polygon points="{geo[name]}" fill="{off}"/>')
    for name in onset:
        P.append(f'<polygon points="{geo[name]}" fill="{on}"/>')


def seg_number(text, x, y, w, h, t, gap, on=INK, off=GHOST, colon_after=None):
    """Draw a string of 7-seg digits/colon starting at top-left (x, y)."""
    cx = x
    for i, ch in enumerate(text):
        if ch == ":":
            r = max(2, t // 2)
            P.append(f'<circle cx="{cx+r:.1f}" cy="{y+h*0.32:.1f}" r="{r}" fill="{on}"/>')
            P.append(f'<circle cx="{cx+r:.1f}" cy="{y+h*0.68:.1f}" r="{r}" fill="{on}"/>')
            cx += t + gap
        else:
            seg7(cx, y, w, h, t, ch, on, off)
            cx += w + gap
    return cx


def text(x, y, s, size, fill=INK, anchor="middle", weight="normal", spacing=0, mono=False):
    fam = 'font-family="Courier New,monospace"' if mono else ""
    P.append(f'<text x="{x}" y="{y}" fill="{fill}" font-size="{size}" '
             f'text-anchor="{anchor}" font-weight="{weight}" '
             f'letter-spacing="{spacing}" {fam}>{s}</text>')


now = datetime.datetime.now()

P.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" font-family="Helvetica,Arial,sans-serif">')

# --- Black resin case (round watch) ---
P.append(f'<circle cx="{CX}" cy="{CY}" r="{CX}" fill="{CASE}"/>')

# Printed case text.
text(CX, 40, "CASIO", 19, CASE_TX, weight="bold", spacing=4)
text(CX, 58, "WORLD&#160;TIME", 9, CASE_TX, spacing=3)
text(105, 360, "ILLUMINATOR", 9, CASE_TX, spacing=1)
text(292, 360, "WR&#160;100M", 9, CASE_TX, spacing=1)
text(CX, 376, "AE-1200WH", 9, CASE_TX, spacing=2)

# --- LCD panel ---
px0, py0, pw, ph = 50, 74, 290, 248
P.append(f'<rect x="{px0-3}" y="{py0-3}" width="{pw+6}" height="{ph+6}" rx="18" '
         f'fill="{PANEL_EDGE}"/>')
P.append(f'<rect x="{px0}" y="{py0}" width="{pw}" height="{ph}" rx="15" fill="{PANEL}"/>')

pxc = px0 + pw // 2

# --- Top windows ---
def window(x, y, w, h):
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" '
             f'fill="none" stroke="{INK}" stroke-width="1.5"/>')

# Top-left: HR + steps
lwx, lwy, lww, lwh = 62, 88, 92, 50
window(lwx, lwy, lww, lwh)
hr_demo, steps_demo = 72, 8423
# small heart
hx = lwx + 16
P.append(f'<circle cx="{hx-2}" cy="{lwy+14}" r="2.2" fill="{INK}"/>')
P.append(f'<circle cx="{hx+2}" cy="{lwy+14}" r="2.2" fill="{INK}"/>')
P.append(f'<polygon points="{hx-4},{lwy+15} {hx+4},{lwy+15} {hx},{lwy+20}" fill="{INK}"/>')
seg_number(str(hr_demo), hx + 10, lwy + 7, 12, 18, 3, 4)
text(lwx + lww // 2, lwy + lwh - 6, f"{steps_demo}&#160;STEPS", 10, INK, spacing=1, mono=True)

# Top-right: alarms
rwx, rwy, rww, rwh = 236, 88, 92, 50
window(rwx, rwy, rww, rwh)
alarm_count = 2
# bell
bcx, bcy = rwx + 18, rwy + 18
bell = f"{bcx-7},{bcy+6} {bcx-6},{bcy+2} {bcx-4},{bcy-4} {bcx-2},{bcy-7} {bcx},{bcy-8} {bcx+2},{bcy-7} {bcx+4},{bcy-4} {bcx+6},{bcy+2} {bcx+7},{bcy+6}"
P.append(f'<polygon points="{bell}" fill="{INK}"/>')
P.append(f'<rect x="{bcx-8}" y="{bcy+6}" width="16" height="2" fill="{INK}"/>')
P.append(f'<circle cx="{bcx}" cy="{bcy+10}" r="2" fill="{INK}"/>')
seg_number(str(alarm_count), bcx + 18, rwy + 7, 16, 24, 4, 4)
text(rwx + rww // 2, rwy + rwh - 6, "ALARM&#160;ON", 10, INK, spacing=1, mono=True)

# --- World map ---
mapW = 252
mx0 = pxc - mapW // 2
my0 = 144
colSp = mapW / MAP_COLS
rowSp = 3.3
for row, c0, c1 in MAP:
    yy = my0 + row * rowSp + rowSp / 2
    for c in range(c0, c1 + 1):
        xx = mx0 + c * colSp + colSp / 2
        P.append(f'<circle cx="{xx:.1f}" cy="{yy:.1f}" r="1.7" fill="{INK}"/>')
# city cursor (blinking box over Europe-ish)
curx = mx0 + 30 * colSp
cury = my0 + 4 * rowSp
P.append(f'<rect x="{curx-4:.1f}" y="{cury-4:.1f}" width="9" height="9" '
         f'fill="none" stroke="{INK}" stroke-width="1.5"/>')

# --- Info row above time: day-of-week | city | date ---
rowy = 222
text(px0 + 18, rowy, now.strftime("%a").upper(), 13, INK, anchor="start", mono=True, weight="bold")
text(pxc, rowy, "UTC+0", 12, DIM, mono=True)
text(px0 + pw - 18, rowy, now.strftime("%-m-%-d"), 13, INK, anchor="end", mono=True, weight="bold")

# --- Big 7-segment time + small seconds ---
dw, dh, dt, dg = 38, 62, 8, 7
timestr = now.strftime("%H:%M")
# measure width: 4 digits + 1 colon
tw = 4 * dw + 3 * dg + (dt + dg)
sw, sh, st, sg = 20, 34, 5, 5
secstr = now.strftime("%S")
secw = 2 * sw + sg
gap_ts = 12
total = tw + gap_ts + secw
tx = pxc - total / 2
ty = 238
endx = seg_number(timestr, tx, ty, dw, dh, dt, dg)
seg_number(secstr, endx + gap_ts, ty + dh - sh, sw, sh, st, sg)

P.append('</svg>')

out = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "preview.svg"))
with open(out, "w") as f:
    f.write("\n".join(P))
print("wrote", out)
