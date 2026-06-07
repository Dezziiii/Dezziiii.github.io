#!/usr/bin/env python3
"""SVG mockup of the Casio AE1200-style watch face (390x390), modelling the
physical watch: resin case, strap lugs, metal pushers, recessed LCD and
printed bezel text. Mirrors source/CasioWorldTimeView.mc. Mockup only.
"""
import datetime
import math
import os

W = H = 390
CX = CY = 195

# ---- Materials ----
RESIN     = "#0d0e11"   # black resin body
RESIN_HI  = "#2c3036"   # moulded edge highlight
RESIN_HI2 = "#454b53"   # brightest bevel
RESIN_SH  = "#040405"   # resin shadow
STRAP     = "#101217"
STRAP_HI  = "#23262d"
STRAP_SH  = "#040506"
METAL     = "#70757b"   # pusher metal
METAL_HI  = "#aeb4ba"
METAL_SH  = "#34373c"
PRINT     = "#c7cabf"   # printed light text
PRINT_DIM = "#7e8378"
# ---- LCD ----
FRAME     = "#2b3127"   # recessed LCD frame
PANEL     = "#9aa58d"   # olive-grey positive LCD
PANEL_SH  = "#7f8a72"
INK       = "#181b15"
GHOST     = "#828d76"
NIGHT     = "#727c63"
GLINT     = "#bcc5ae"
DIM       = "#5d6655"

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
SEG = {"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg",
       "5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg", " ": ""}
CITY = {-11: "MDY", -10: "HNL", -9: "ANC", -8: "LAX", -7: "DEN", -6: "CHI",
        -5: "NYC", -4: "CCS", -3: "RIO", -2: "FEN", -1: "AZO", 0: "LON",
        1: "PAR", 2: "CAI", 3: "MOW", 4: "DXB", 5: "KHI", 6: "DAC",
        7: "BKK", 8: "HKG", 9: "TYO", 10: "SYD", 11: "NOU", 12: "AKL"}

P = []


def rect(x, y, w, h, fill="none", rx=0, stroke=None, sw=1):
    if fill is None:
        fill = "none"
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    P.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" fill="{fill}"{s}/>')


def circle(cx, cy, r, fill="none", stroke=None, sw=1):
    if fill is None:
        fill = "none"
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    P.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}"{s}/>')


def line(x1, y1, x2, y2, stroke, sw=1):
    P.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{stroke}" stroke-width="{sw}"/>')


def poly(pts, fill):
    s = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    P.append(f'<polygon points="{s}" fill="{fill}"/>')


def text(x, y, s, size, fill=INK, anchor="middle", weight="normal", spacing=0, mono=False):
    fam = 'font-family="Courier New,monospace"' if mono else ""
    P.append(f'<text x="{x:.1f}" y="{y:.1f}" fill="{fill}" font-size="{size}" '
             f'text-anchor="{anchor}" font-weight="{weight}" letter-spacing="{spacing}" {fam}>{s}</text>')


# ---- 7-segment ----
def slantx(x, py, ytop, h, k):
    return x + (ytop + h - py) * k


def hpoly(lx, ty, L, t, ytop, h, k):
    pts = [(lx, ty + t / 2), (lx + t / 2, ty), (lx + L - t / 2, ty),
           (lx + L, ty + t / 2), (lx + L - t / 2, ty + t), (lx + t / 2, ty + t)]
    return [(slantx(x, y, ytop, h, k), y) for x, y in pts]


def vpoly(lx, ty, L, t, ytop, h, k):
    pts = [(lx + t / 2, ty), (lx + t, ty + t / 2), (lx + t, ty + L - t / 2),
           (lx + t / 2, ty + L), (lx, ty + L - t / 2), (lx, ty + t / 2)]
    return [(slantx(x, y, ytop, h, k), y) for x, y in pts]


def seg7(x, y, w, h, t, ch, on=INK, off=GHOST, k=0.10):
    half = h / 2.0
    geo = {"a": hpoly(x, y, w, t, y, h, k), "g": hpoly(x, y + half - t / 2, w, t, y, h, k),
           "d": hpoly(x, y + h - t, w, t, y, h, k), "f": vpoly(x, y, half + t / 2, t, y, h, k),
           "b": vpoly(x + w - t, y, half + t / 2, t, y, h, k),
           "e": vpoly(x, y + half - t / 2, half + t / 2, t, y, h, k),
           "c": vpoly(x + w - t, y + half - t / 2, half + t / 2, t, y, h, k)}
    onset = SEG.get(ch, "")
    for name in "abcdefg":
        if name not in onset:
            poly(geo[name], off)
    for name in onset:
        poly(geo[name], on)


def seg_number(s, x, y, w, h, t, gap, on=INK, off=GHOST):
    cx = x
    for ch in s:
        if ch == ":":
            r = max(2, t // 2)
            circle(cx + r, y + h * 0.34, r, on)
            circle(cx + r, y + h * 0.66, r, on)
            cx += t + gap
        else:
            seg7(cx, y, w, h, t, ch, on, off)
            cx += w + gap
    return cx


# ---- Hardware ----
def pusher(cx, cy, side):
    # resin guard nubs above/below the button
    gw = 16
    if side in ("l", "r"):
        rect(cx - 7, cy - 18, 14, 8, RESIN_HI, rx=3)
        rect(cx - 7, cy + 10, 14, 8, RESIN_HI, rx=3)
    # metal pusher dome
    circle(cx, cy, 10, METAL_SH)
    circle(cx, cy, 9, METAL)
    circle(cx - 2, cy - 2, 5.5, METAL_HI)
    circle(cx, cy, 9, None, stroke=METAL_SH, sw=1)


def strap(top):
    # Resin strap lug + band fading off the top/bottom edge.
    if top:
        y0, y1 = 0, 70
        wtop, wbot = 150, 188
    else:
        y0, y1 = 390, 320
        wtop, wbot = 150, 188
    pts = [(CX - wtop / 2, y0), (CX + wtop / 2, y0), (CX + wbot / 2, y1), (CX - wbot / 2, y1)]
    poly(pts, STRAP)
    # side highlights
    line(CX - wtop / 2 + 4, y0, CX - wbot / 2 + 4, y1, STRAP_HI, 2)
    line(CX + wtop / 2 - 4, y0, CX + wbot / 2 - 4, y1, STRAP_SH, 2)
    # keeper loop
    ky = 22 if top else 368
    rect(CX - wbot / 2 * (0.8), ky - 6, wbot * 0.8, 12, STRAP_HI, rx=2)
    rect(CX - wbot / 2 * (0.78), ky - 4, wbot * 0.78, 8, STRAP, rx=2)
    # band holes (bottom strap only)
    if not top:
        for i in range(3):
            circle(CX, 348 + i * 12, 2.4, RESIN_SH)


# ============================ DRAW ============================
now = datetime.datetime.now()
utc = datetime.datetime.utcnow()
uh = utc.hour + utc.minute / 60.0
N = utc.timetuple().tm_yday
decl = math.radians(-23.44 * math.cos(math.radians(360.0 * (N + 10) / 365.0)))
lon_sun = 15.0 * (12.0 - uh)


def col_lon(c):
    return -180.0 + (c / (MAP_COLS - 1.0)) * 360.0


def row_lat(r):
    return 75.0 - (r / (MAP_ROWS - 1.0)) * 130.0


def is_day(lon, lat):
    Hh = math.radians(lon - lon_sun)
    la = math.radians(lat)
    return (math.sin(la) * math.sin(decl) + math.cos(la) * math.cos(decl) * math.cos(Hh)) > 0


P.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" font-family="Arial,Helvetica,sans-serif">')

# Black resin body (whole round face).
circle(CX, CY, CX, RESIN)
# Straps top & bottom.
strap(True)
strap(False)
# Moulded bezel bevel rings around where the LCD sits.
P.append(f'<rect x="34" y="62" width="322" height="266" rx="46" fill="none" stroke="{RESIN_HI}" stroke-width="2"/>')
P.append(f'<rect x="40" y="68" width="310" height="254" rx="40" fill="none" stroke="{RESIN_SH}" stroke-width="2"/>')
# Top-left curvature highlight.
P.append(f'<path d="M60,120 A150,150 0 0 1 150,58" fill="none" stroke="{RESIN_HI2}" stroke-width="1.5" opacity="0.5"/>')

# Pushers (2 left, 2 right).
pusher(40, 120, "l")
pusher(40, 270, "l")
pusher(350, 120, "r")
pusher(350, 270, "r")

# Printed bezel text (flanking the straps).
text(96, 64, "CASIO", 17, PRINT, weight="bold", spacing=2)
text(300, 62, "ILLUMINATOR", 8.5, PRINT, spacing=1)
text(300, 72, "AE-1200WH", 8.5, PRINT_DIM, spacing=1)
text(95, 334, "WATER", 8, PRINT_DIM, spacing=1)
text(95, 343, "10 BAR RESIST", 8, PRINT_DIM, spacing=1)
text(300, 338, "MODULE 3198", 8, PRINT_DIM, spacing=1)
text(54, 150, "ADJUST", 7, PRINT_DIM, anchor="start", spacing=1)
text(54, 252, "REVERSE", 7, PRINT_DIM, anchor="start", spacing=1)
text(336, 150, "FORWARD", 7, PRINT_DIM, anchor="end", spacing=1)
text(336, 252, "LIGHT", 7, PRINT_DIM, anchor="end", spacing=1)

# ---- Recessed LCD ----
lx, ly, lw, lh = 46, 74, 298, 242
rect(lx - 4, ly - 4, lw + 8, lh + 8, FRAME, rx=24)          # dark recess frame
rect(lx, ly, lw, lh, PANEL, rx=20)                          # olive LCD
# inner top/left shadow + bottom/right light to look recessed
P.append(f'<rect x="{lx}" y="{ly}" width="{lw}" height="{lh}" rx="20" fill="none" stroke="{PANEL_SH}" stroke-width="1"/>')
pxc = lx + lw // 2

# Top-left data field: HR + steps (no box, LCD-native).
hx = lx + 26
circle(hx - 2, ly + 22, 2.4, INK)
circle(hx + 2, ly + 22, 2.4, INK)
poly([(hx - 4, ly + 23), (hx + 4, ly + 23), (hx, ly + 28)], INK)
seg_number("72", hx + 10, ly + 14, 12, 18, 3, 4)
text(lx + 12, ly + 44, "8423 STEP", 10, INK, anchor="start", mono=True)

# Top-right data field: alarm count.
ax = lx + lw - 26
text(ax + 8, ly + 16, "AL", 11, INK, anchor="end", mono=True, weight="bold")
bcx, bcy = ax - 30, ly + 22
bell = [(bcx - 6, bcy + 5), (bcx - 5, bcy + 1), (bcx - 3, bcy - 4), (bcx - 1, bcy - 6),
        (bcx + 1, bcy - 6), (bcx + 3, bcy - 4), (bcx + 5, bcy + 1), (bcx + 6, bcy + 5)]
poly(bell, INK)
rect(bcx - 7, bcy + 5, 14, 1.8, INK)
seg_number("2", ax - 14, ly + 12, 14, 22, 4, 4)
text(lx + lw - 12, ly + 44, "ALARM ON", 10, INK, anchor="end", mono=True)

# ---- World map (day/night) ----
mapW = 250
mx0 = pxc - mapW // 2
my0 = ly + 56
colSp = mapW / MAP_COLS
rowSp = 3.2
for row, c0, c1 in MAP:
    yy = my0 + row * rowSp + rowSp / 2
    lat = row_lat(row)
    for c in range(c0, c1 + 1):
        xx = mx0 + c * colSp + colSp / 2
        circle(xx, yy, 1.7, INK if is_day(col_lon(c), lat) else NIGHT)


def map_xy(lon, lat):
    col = (lon + 180.0) / 360.0 * (MAP_COLS - 1)
    row = (75.0 - lat) / 130.0 * (MAP_ROWS - 1)
    return (mx0 + col * colSp + colSp / 2, my0 + row * rowSp + rowSp / 2)


# Home-city cursor: blinking pointer above the map (iconic AE1200 element).
home_off = 0
home_lon = max(-180, min(180, home_off * 15))
hxp, _ = map_xy(home_lon, 0)
poly([(hxp - 4, my0 - 9), (hxp + 4, my0 - 9), (hxp, my0 - 3)], INK)
# Sun + moon.
sx_, sy_ = map_xy(((lon_sun + 180) % 360) - 180, math.degrees(decl))
circle(sx_, sy_, 3.0, INK)
for a in range(0, 360, 45):
    dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
    line(sx_ + dx * 4.5, sy_ + dy * 4.5, sx_ + dx * 6.5, sy_ + dy * 6.5, INK, 1.2)
mlon = (((lon_sun + 180) + 180) % 360) - 180
mx_, my_ = map_xy(mlon, -math.degrees(decl))
circle(mx_, my_, 3.4, INK)
circle(mx_ + 1.7, my_ - 1, 3, PANEL)

# ---- Info row: day | city | date ----
rowy = my0 + 78
text(lx + 16, rowy, now.strftime("%a").upper(), 13, INK, anchor="start", mono=True, weight="bold")
text(pxc, rowy, CITY.get(home_off, "GMT"), 13, INK, mono=True, weight="bold")
text(lx + lw - 16, rowy, now.strftime("%-m-%-d"), 13, INK, anchor="end", mono=True, weight="bold")

# ---- Big 7-segment time + seconds ----
dw, dh, dt, dg = 37, 58, 8, 7
timestr = now.strftime("%H:%M")
tw = 4 * dw + 3 * dg + (dt + dg)
sw, sh, st, sg = 19, 32, 5, 5
secw = 2 * sw + sg
gap_ts = 11
total = tw + gap_ts + secw
tx = pxc - total / 2
ty = rowy + 14
endx = seg_number(timestr, tx, ty, dw, dh, dt, dg)
seg_number(now.strftime("%S"), endx + gap_ts, ty + dh - sh, sw, sh, st, sg)

# ---- Status strip ----
sty = ty + dh + 14
bx = lx + 22
P.append(f'<polyline points="{bx},{sty-6} {bx+4},{sty-2} {bx-3},{sty+3} {bx},{sty+6} {bx},{sty-6} {bx+4},{sty+2} {bx-3},{sty-3}" '
         f'fill="none" stroke="{INK}" stroke-width="1.4"/>')
batx = lx + lw - 48
rect(batx, sty - 6, 22, 12, None, rx=2, stroke=INK, sw=1.6)
rect(batx + 22, sty - 3, 2.6, 6, INK)
rect(batx + 2, sty - 4, 18 * 0.78, 8, INK)
text(batx - 6, sty + 4, "78%", 11, INK, anchor="end", mono=True)

# ---- Glass glint ----
line(lx + 16, ly + 9, lx + 42, ly + 9, GLINT, 3)
line(lx + 16, ly + 14, lx + 30, ly + 14, GLINT, 2)

P.append('</svg>')

out = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "preview.svg"))
with open(out, "w") as f:
    f.write("\n".join(P))
print("wrote", out)
