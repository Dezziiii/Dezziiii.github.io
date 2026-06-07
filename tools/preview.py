#!/usr/bin/env python3
"""SVG mockup of the Casio AE1200-style watch face (390x390).

Models the physical watch (resin case, strap, metal pushers, recessed LCD,
bezel print) and lays out the LCD to match the real AE1200: a top row of
[square heart-rate dial] [alarm] [small dash display], a world map beneath,
and the big time + date at the bottom. Mirrors CasioWorldTimeView.mc.
"""
import datetime
import math
import os

W = H = 390
CX = CY = 195

# Materials
RESIN, RESIN_HI, RESIN_HI2, RESIN_SH = "#0d0e11", "#2c3036", "#454b53", "#040405"
STRAP, STRAP_HI, STRAP_SH = "#101217", "#23262d", "#040506"
METAL, METAL_HI, METAL_SH = "#70757b", "#aeb4ba", "#34373c"
PRINT, PRINT_DIM = "#c7cabf", "#7e8378"
# LCD
FRAME, PANEL, PANEL_SH = "#2b3127", "#9aa58d", "#7f8a72"
INK, GHOST, NIGHT, GLINT, DIM = "#181b15", "#828d76", "#727c63", "#bcc5ae", "#5d6655"

MAP_COLS, MAP_ROWS = 56, 20
MAP = [
    [0, 22, 24], [1, 8, 16], [1, 22, 25], [1, 28, 31], [1, 34, 52],
    [2, 6, 20], [2, 23, 25], [2, 27, 33], [2, 34, 54],
    [3, 5, 21], [3, 26, 26], [3, 28, 34], [3, 35, 55],
    [4, 5, 21], [4, 27, 55], [5, 6, 20], [5, 27, 55],
    [6, 7, 19], [6, 27, 54], [7, 9, 16], [7, 26, 54],
    [8, 10, 15], [8, 27, 37], [8, 41, 52], [9, 12, 16], [9, 28, 38], [9, 42, 52],
    [10, 16, 20], [10, 29, 39], [10, 48, 53], [11, 16, 22], [11, 30, 38], [11, 48, 55],
    [12, 16, 24], [12, 31, 38], [12, 49, 55], [13, 17, 25], [13, 31, 37], [13, 50, 55],
    [14, 18, 24], [14, 32, 37], [14, 49, 55], [15, 18, 23], [15, 33, 36], [15, 50, 55],
    [16, 18, 22], [16, 52, 54], [17, 18, 21], [18, 18, 20], [19, 18, 19],
]
SEG = {"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg",
       "5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg",
       " ": "", "-": "g"}
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


def pusher(cx, cy):
    rect(cx - 7, cy - 18, 14, 8, RESIN_HI, rx=3)
    rect(cx - 7, cy + 10, 14, 8, RESIN_HI, rx=3)
    circle(cx, cy, 10, METAL_SH)
    circle(cx, cy, 9, METAL)
    circle(cx - 2, cy - 2, 5.5, METAL_HI)


def strap(top):
    if top:
        y0, y1, wt, wb = 0, 52, 150, 176
    else:
        y0, y1, wt, wb = H, H - 52, 150, 176
    poly([(CX - wt / 2, y0), (CX + wt / 2, y0), (CX + wb / 2, y1), (CX - wb / 2, y1)], STRAP)
    line(CX - wt / 2 + 4, y0, CX - wb / 2 + 4, y1, STRAP_HI, 2)
    line(CX + wt / 2 - 4, y0, CX + wb / 2 - 4, y1, STRAP_SH, 2)
    ky = 20 if top else H - 20
    kw = wb * 0.82
    rect(CX - kw / 2, ky - 6, kw, 12, STRAP_HI, rx=2)
    rect(CX - kw / 2 + 2, ky - 4, kw - 4, 8, STRAP, rx=2)
    if not top:
        for i in range(3):
            circle(CX, H - 40 - i * 11, 2.2, STRAP_SH)


def heart(cx, cy, color=INK):
    circle(cx - 2, cy - 1, 2.2, color)
    circle(cx + 2, cy - 1, 2.2, color)
    poly([(cx - 4, cy), (cx + 4, cy), (cx, cy + 5)], color)


def bell(cx, cy, color=INK):
    poly([(cx - 6, cy + 5), (cx - 5, cy + 1), (cx - 3, cy - 4), (cx - 1, cy - 6),
          (cx + 1, cy - 6), (cx + 3, cy - 4), (cx + 5, cy + 1), (cx + 6, cy + 5)], color)
    rect(cx - 7, cy + 5, 14, 1.8, color)
    circle(cx, cy + 8, 1.3, color)


# ============================ DRAW ============================
now = datetime.datetime.now()
utc = datetime.datetime.utcnow()
uh = utc.hour + utc.minute / 60.0
N = utc.timetuple().tm_yday
decl = math.radians(-23.44 * math.cos(math.radians(360.0 * (N + 10) / 365.0)))
lon_sun = 15.0 * (12.0 - uh)
home_off = 0


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

circle(CX, CY, CX, RESIN)
strap(True)
strap(False)
rect(34, 60, 322, 270, "none", rx=46, stroke=RESIN_HI, sw=2)
rect(40, 66, 310, 258, "none", rx=40, stroke=RESIN_SH, sw=2)
pusher(40, 120)
pusher(40, 270)
pusher(350, 120)
pusher(350, 270)

# Bezel print
text(CX, 52, "WORLD TIME", 12, PRINT, weight="bold", spacing=2)
text(312, 52, "CASIO", 12, PRINT, weight="bold", spacing=1)
text(CX, 336, "ILLUMINATOR", 12, PRINT, spacing=2)

# Recessed LCD
lx, ly, lw, lh = 46, 72, 298, 246
rect(lx - 4, ly - 4, lw + 8, lh + 8, FRAME, rx=24)
rect(lx, ly, lw, lh, PANEL, rx=20)
rect(lx, ly, lw, lh, "none", rx=20, stroke=PANEL_SH, sw=1)
pxc = lx + lw // 2

# ---- Row 1: square HR dial | alarm | dash display ----
r1y = 84
r1h = 66

# Square heart-rate dial with a sweeping needle.
sqs = 66
sqx = lx + 8
rect(sqx, r1y, sqs, sqs, "none", stroke=INK, sw=1.6)
dcx, dcy, dr = sqx + sqs / 2, r1y + 30, 20
circle(dcx, dcy, dr, "none", stroke=GHOST, sw=1.5)
for a in range(0, 360, 30):
    rr = math.radians(a)
    line(dcx + (dr - 3) * math.cos(rr), dcy + (dr - 3) * math.sin(rr),
         dcx + dr * math.cos(rr), dcy + dr * math.sin(rr), GHOST, 1)
# needle: map HR 40..200 bpm onto a 270-degree sweep (gap at the bottom).
hr_demo = 72
frac = max(0.0, min(1.0, (hr_demo - 40) / 160.0))
nang = math.radians(135 + frac * 270)
line(dcx, dcy, dcx + (dr - 3) * math.cos(nang), dcy + (dr - 3) * math.sin(nang), INK, 2)
circle(dcx, dcy, 2.6, INK)
# bottom: heart + bpm
heart(dcx - 13, r1y + sqs - 9, INK)
text(dcx + 4, r1y + sqs - 5, str(hr_demo), 13, INK, anchor="start", mono=True, weight="bold")

# Alarm (directly right of the square).
alx = sqx + sqs + 8
alw = 64
text(alx + alw / 2, r1y + 12, "ALARM", 9, INK, spacing=1)
bell(alx + 14, r1y + 34, INK)
seg_number("2", alx + 30, r1y + 22, 16, 24, 4, 4)
text(alx + alw / 2, r1y + sqs - 6, "ALM-SET", 8.5, INK, spacing=1)

# Dash display: stopwatch-style chrono (right).
dxx = alx + alw + 8
dxw = lx + lw - 8 - dxx
text(dxx + 4, r1y + 12, "STW", 8.5, INK, anchor="start", spacing=1)
text(dxx + dxw - 2, r1y + 12, "1/100", 8.5, INK, anchor="end", spacing=1)
# main chrono MIN:SEC in small segments
endc = seg_number("00:00", dxx + 6, r1y + 22, 12, 18, 3, 3)
# small centiseconds + the dash row
seg_number("00", endc + 4, r1y + 28, 7, 11, 2, 2)
text(dxx + dxw - 2, r1y + 40, "SPLIT", 8.5, INK, anchor="end", spacing=1)
for i in range(3):
    seg7(dxx + 6 + i * 12, r1y + sqs - 12, 10, 4, 4, "-", INK, GHOST)

# ---- Row 2: world map (centered, below the row) ----
mapW = 214
mx0 = pxc - mapW // 2
my0 = r1y + r1h + 6
colSp = mapW / MAP_COLS
rowSp = 2.8
for row, c0, c1 in MAP:
    yy = my0 + row * rowSp + rowSp / 2
    lat = row_lat(row)
    for c in range(c0, c1 + 1):
        xx = mx0 + c * colSp + colSp / 2
        circle(xx, yy, 1.6, INK if is_day(col_lon(c), lat) else NIGHT)


def map_xy(lon, lat):
    col = (lon + 180.0) / 360.0 * (MAP_COLS - 1)
    row = (75.0 - lat) / 130.0 * (MAP_ROWS - 1)
    return (mx0 + col * colSp + colSp / 2, my0 + row * rowSp + rowSp / 2)


hxp, _ = map_xy(max(-180, min(180, home_off * 15)), 0)
poly([(hxp - 4, my0 - 8), (hxp + 4, my0 - 8), (hxp, my0 - 2)], INK)
sx_, sy_ = map_xy(((lon_sun + 180) % 360) - 180, math.degrees(decl))
circle(sx_, sy_, 2.6, INK)
for a in range(0, 360, 45):
    dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
    line(sx_ + dx * 4, sy_ + dy * 4, sx_ + dx * 5.6, sy_ + dy * 5.6, INK, 1.1)
mlon = (((lon_sun + 180) + 180) % 360) - 180
mx_, my_ = map_xy(mlon, -math.degrees(decl))
circle(mx_, my_, 3.0, INK)
circle(mx_ + 1.6, my_ - 1, 2.6, PANEL)

# ---- Row 3: big time + seconds, with PM, and the date ----
ty = my0 + 20 * rowSp + 8
dw, dh, dt, dg = 34, 54, 7, 6
timestr = now.strftime("%I:%M").lstrip("0")
if len(timestr) == 4:
    timestr = " " + timestr
tw = 4 * dw + 3 * dg + (dt + dg)
sw, sh, st, sg = 18, 30, 5, 4
secw = 2 * sw + sg
gap_ts = 10
total = tw + gap_ts + secw
tx = pxc - total / 2 + 6
# AM/PM
text(tx - 8, ty + 12, now.strftime("%p"), 11, INK, anchor="end", weight="bold")
endx = seg_number(timestr, tx, ty, dw, dh, dt, dg)
seg_number(now.strftime("%S"), endx + gap_ts, ty + dh - sh, sw, sh, st, sg)
# Date row beneath the time.
dty = ty + dh + 12
text(tx + 4, dty, now.strftime("%a").upper(), 12, INK, anchor="start", mono=True, weight="bold")
text(pxc + 8, dty, CITY.get(home_off, "GMT"), 12, INK, mono=True, weight="bold")
text(lx + lw - 12, dty, now.strftime("%-m-%-d"), 12, INK, anchor="end", mono=True, weight="bold")

# Glint
line(lx + 16, ly + 9, lx + 42, ly + 9, GLINT, 3)
line(lx + 16, ly + 14, lx + 30, ly + 14, GLINT, 2)

P.append('</svg>')
out = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "preview.svg"))
with open(out, "w") as f:
    f.write("\n".join(P))
print("wrote", out)
