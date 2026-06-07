#!/usr/bin/env python3
"""Render an SVG mockup of the Casio AE1200-style watch face (390x390).

Mirrors source/CasioWorldTimeView.mc. Mockup only -- the device is the
source of truth.
"""
import datetime
import math
import os

W = H = 390
CX = CY = 195

# Palette
CASE = "#070707"
CASE_HI = "#3a3a3a"
BTN = "#2b2b2b"
BTN_HI = "#5a5a5a"
CASE_TX = "#c9ccc4"
PANEL = "#9aa58d"
PANEL_EDGE = "#3c4438"
INK = "#191c16"
GHOST = "#828d76"
NIGHT = "#717b62"
DIM = "#5d6655"
GLINT = "#c2cbb4"

MAP_COLS = 56
MAP_ROWS = 20
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

SEG = {
    "0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg",
    "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc",
    "8": "abcdefg", "9": "abcdfg", " ": "",
}

# Representative 3-letter world-time city codes by integer UTC offset.
CITY = {
    -11: "MDY", -10: "HNL", -9: "ANC", -8: "LAX", -7: "DEN", -6: "CHI",
    -5: "NYC", -4: "CCS", -3: "RIO", -2: "FEN", -1: "AZO", 0: "LON",
    1: "PAR", 2: "CAI", 3: "MOW", 4: "DXB", 5: "KHI", 6: "DAC",
    7: "BKK", 8: "HKG", 9: "TYO", 10: "SYD", 11: "NOU", 12: "AKL",
}

P = []


def slantx(x, py, ytop, h, k):
    return x + (ytop + h - py) * k


def hpoly(lx, ty, L, t, ytop, h, k):
    pts = [(lx, ty + t / 2), (lx + t / 2, ty), (lx + L - t / 2, ty),
           (lx + L, ty + t / 2), (lx + L - t / 2, ty + t), (lx + t / 2, ty + t)]
    return " ".join(f"{slantx(x,y,ytop,h,k):.1f},{y:.1f}" for x, y in pts)


def vpoly(lx, ty, L, t, ytop, h, k):
    pts = [(lx + t / 2, ty), (lx + t, ty + t / 2), (lx + t, ty + L - t / 2),
           (lx + t / 2, ty + L), (lx, ty + L - t / 2), (lx, ty + t / 2)]
    return " ".join(f"{slantx(x,y,ytop,h,k):.1f},{y:.1f}" for x, y in pts)


def seg7(x, y, w, h, t, ch, on=INK, off=GHOST, k=0.10):
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
    for name in "abcdefg":
        if name not in onset:
            P.append(f'<polygon points="{geo[name]}" fill="{off}"/>')
    for name in onset:
        P.append(f'<polygon points="{geo[name]}" fill="{on}"/>')


def seg_number(text, x, y, w, h, t, gap, on=INK, off=GHOST):
    cx = x
    for ch in text:
        if ch == ":":
            r = max(2, t // 2)
            P.append(f'<circle cx="{cx+r:.1f}" cy="{y+h*0.34:.1f}" r="{r}" fill="{on}"/>')
            P.append(f'<circle cx="{cx+r:.1f}" cy="{y+h*0.66:.1f}" r="{r}" fill="{on}"/>')
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
utc = datetime.datetime.utcnow()
uh = utc.hour + utc.minute / 60.0
N = utc.timetuple().tm_yday
decl = math.radians(-23.44 * math.cos(math.radians(360.0 * (N + 10) / 365.0)))
lon_sun = 15.0 * (12.0 - uh)


def col_lon(col):
    return -180.0 + (col / (MAP_COLS - 1.0)) * 360.0


def row_lat(row):
    return 75.0 - (row / (MAP_ROWS - 1.0)) * 130.0


def is_day(lon, lat):
    Hh = math.radians(lon - lon_sun)
    la = math.radians(lat)
    return (math.sin(la) * math.sin(decl) + math.cos(la) * math.cos(decl) * math.cos(Hh)) > 0


P.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" font-family="Helvetica,Arial,sans-serif">')

# --- Case ---
P.append(f'<circle cx="{CX}" cy="{CY}" r="{CX}" fill="{CASE}"/>')
P.append(f'<circle cx="{CX}" cy="{CY}" r="{CX-2}" fill="none" stroke="{CASE_HI}" stroke-width="1.5"/>')

# Case pushers (4 Casio buttons).
for ang, w_, h_ in [(150, 18, 11), (210, 18, 11), (30, 18, 11), (330, 18, 11)]:
    bxc = CX + 183 * math.cos(math.radians(ang))
    byc = CY - 183 * math.sin(math.radians(ang))
    P.append(f'<rect x="{bxc-w_/2:.1f}" y="{byc-h_/2:.1f}" width="{w_}" height="{h_}" rx="3" '
             f'fill="{BTN}" stroke="{BTN_HI}" stroke-width="1"/>')

# Printed case text.
text(CX, 40, "CASIO", 19, CASE_TX, weight="bold", spacing=4)
text(CX, 58, "WORLD&#160;TIME", 9, CASE_TX, spacing=3)
text(120, 348, "LIGHT", 8, CASE_TX, spacing=1)
text(270, 348, "WR&#160;100M", 8, CASE_TX, spacing=1)
text(CX, 372, "AE-1200WH", 9, CASE_TX, spacing=2)

# --- LCD panel ---
px0, py0, pw, ph = 50, 74, 290, 248
P.append(f'<rect x="{px0-3}" y="{py0-3}" width="{pw+6}" height="{ph+6}" rx="18" fill="{PANEL_EDGE}"/>')
P.append(f'<rect x="{px0}" y="{py0}" width="{pw}" height="{ph}" rx="15" fill="{PANEL}"/>')
pxc = px0 + pw // 2


def window(x, y, w, h):
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" '
             f'fill="none" stroke="{INK}" stroke-width="1.5"/>')


# Top-left: HR + steps
lwx, lwy, lww, lwh = 62, 88, 92, 50
window(lwx, lwy, lww, lwh)
hr_demo, steps_demo = 72, 8423
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
bcx, bcy = rwx + 18, rwy + 18
bell = f"{bcx-7},{bcy+6} {bcx-6},{bcy+2} {bcx-4},{bcy-4} {bcx-2},{bcy-7} {bcx},{bcy-8} {bcx+2},{bcy-7} {bcx+4},{bcy-4} {bcx+6},{bcy+2} {bcx+7},{bcy+6}"
P.append(f'<polygon points="{bell}" fill="{INK}"/>')
P.append(f'<rect x="{bcx-8}" y="{bcy+6}" width="16" height="2" fill="{INK}"/>')
P.append(f'<circle cx="{bcx}" cy="{bcy+10}" r="2" fill="{INK}"/>')
seg_number(str(alarm_count), bcx + 18, rwy + 7, 16, 24, 4, 4)
text(rwx + rww // 2, rwy + rwh - 6, "ALARM&#160;ON", 10, INK, spacing=1, mono=True)

# --- World map with day/night shading ---
mapW = 252
mx0 = pxc - mapW // 2
my0 = 144
colSp = mapW / MAP_COLS
rowSp = 3.3
for row, c0, c1 in MAP:
    yy = my0 + row * rowSp + rowSp / 2
    lat = row_lat(row)
    for c in range(c0, c1 + 1):
        xx = mx0 + c * colSp + colSp / 2
        col = INK if is_day(col_lon(c), lat) else NIGHT
        P.append(f'<circle cx="{xx:.1f}" cy="{yy:.1f}" r="1.7" fill="{col}"/>')


def map_xy(lon, lat):
    col = (lon + 180.0) / 360.0 * (MAP_COLS - 1)
    row = (75.0 - lat) / 130.0 * (MAP_ROWS - 1)
    return (mx0 + col * colSp + colSp / 2, my0 + row * rowSp + rowSp / 2)


# Sun marker (day side) + rays.
sx_, sy_ = map_xy(((lon_sun + 180) % 360) - 180, math.degrees(decl))
P.append(f'<circle cx="{sx_:.1f}" cy="{sy_:.1f}" r="3.2" fill="{INK}"/>')
for a in range(0, 360, 45):
    dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
    P.append(f'<line x1="{sx_+dx*5:.1f}" y1="{sy_+dy*5:.1f}" x2="{sx_+dx*7:.1f}" y2="{sy_+dy*7:.1f}" stroke="{INK}" stroke-width="1.3"/>')
# Moon marker (night side) -- crescent.
mlon = (((lon_sun + 180) + 180) % 360) - 180
mx_, my_ = map_xy(mlon, -math.degrees(decl))
P.append(f'<circle cx="{mx_:.1f}" cy="{my_:.1f}" r="3.4" fill="{INK}"/>')
P.append(f'<circle cx="{mx_+1.7:.1f}" cy="{my_-1:.1f}" r="3" fill="{PANEL}"/>')

# --- Info row: day | city | date ---
rowy = 224
text(px0 + 18, rowy, now.strftime("%a").upper(), 13, INK, anchor="start", mono=True, weight="bold")
text(pxc, rowy, CITY.get(0, "GMT"), 13, INK, mono=True, weight="bold")
text(px0 + pw - 18, rowy, now.strftime("%-m-%-d"), 13, INK, anchor="end", mono=True, weight="bold")

# --- Big 7-segment time + small seconds ---
dw, dh, dt, dg = 38, 60, 8, 7
timestr = now.strftime("%H:%M")
tw = 4 * dw + 3 * dg + (dt + dg)
sw, sh, st, sg = 20, 34, 5, 5
secstr = now.strftime("%S")
secw = 2 * sw + sg
gap_ts = 12
total = tw + gap_ts + secw
tx = pxc - total / 2
ty = 240
endx = seg_number(timestr, tx, ty, dw, dh, dt, dg)
seg_number(secstr, endx + gap_ts, ty + dh - sh, sw, sh, st, sg)

# --- Status strip: Bluetooth (left) + battery (right) ---
sty = 312
# Bluetooth glyph
bx = px0 + 20
P.append(f'<polyline points="{bx},{sty-5} {bx+5},{sty} {bx},{sty+5} {bx},{sty-9} {bx+5},{sty-4} {bx-3},{sty+1} '
         f'M{bx-3},{sty-4} {bx+5},{sty+1} {bx},{sty+5}" fill="none" stroke="{INK}" stroke-width="1.4"/>')
# Battery
batx = px0 + pw - 46
P.append(f'<rect x="{batx}" y="{sty-6}" width="22" height="11" rx="2" fill="none" stroke="{INK}" stroke-width="1.4"/>')
P.append(f'<rect x="{batx+22}" y="{sty-3}" width="2.5" height="5" fill="{INK}"/>')
P.append(f'<rect x="{batx+2}" y="{sty-4}" width="{18*0.78:.0f}" height="7" fill="{INK}"/>')
text(batx - 6, sty + 4, "78%", 11, INK, anchor="end", mono=True)

# --- Glass glint streak on the panel ---
P.append(f'<line x1="{px0+14}" y1="{py0+7}" x2="{px0+38}" y2="{py0+7}" stroke="{GLINT}" stroke-width="3"/>')
P.append(f'<line x1="{px0+14}" y1="{py0+12}" x2="{px0+28}" y2="{py0+12}" stroke="{GLINT}" stroke-width="2"/>')

P.append('</svg>')

out = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "preview.svg"))
with open(out, "w") as f:
    f.write("\n".join(P))
print("wrote", out)
