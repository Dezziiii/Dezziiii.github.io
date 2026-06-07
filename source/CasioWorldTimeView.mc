using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application;
using Toybox.ActivityMonitor;
using Toybox.Activity;

//
// Casio AE1200WH-1A ("World Time") inspired watch face for the
// Garmin Forerunner 165 / 165 Music.
//
//   black resin case + 4 pushers + printed text ("CASIO", "WORLD TIME"...)
//   a rounded rectangular grey-green positive-LCD panel, containing:
//     - top-left window : live heart rate + daily steps
//     - top-right window: active alarm count (bell)
//     - centre         : dot-matrix world map shaded for day/night, with
//                        sun + moon markers computed from the current UTC time
//     - info row       : day-of-week | home city code | date
//     - main           : large true 7-segment time + small seconds
//     - status strip   : Bluetooth + battery
//
// The time uses hand-drawn 7-segment digits with faint "ghost" off-segments
// for an authentic LCD look. The Forerunner 165 has no magnetometer (so no
// live compass) and Connect IQ exposes only the *count* of active alarms to a
// watch face -- both choices are reflected above.
//
class CasioWorldTimeView extends Ui.WatchFace {

    // Palette.
    private const C_CASE   = 0x000000;   // black resin case
    private const C_CASEHI = 0x3A3A3A;   // case rim highlight
    private const C_BTN    = 0x2B2B2B;   // pusher body
    private const C_BTNHI  = 0x5A5A5A;   // pusher highlight
    private const C_CASETX = 0xC9CCC4;   // printed light-grey case text
    private const C_PANEL  = 0x9AA58D;   // grey-green positive LCD
    private const C_EDGE   = 0x3C4438;   // LCD frame
    private const C_INK    = 0x191C16;   // active "on" segments
    private const C_GHOST  = 0x828D76;   // faint "off" segments
    private const C_NIGHT  = 0x717B62;   // map land on the night side
    private const C_GLINT  = 0xB8C1AA;   // glass highlight
    private const C_DIM    = 0x5D6655;

    // LCD panel rectangle.
    private const PX = 50;
    private const PY = 74;
    private const PW = 290;
    private const PH = 248;

    private var mW = 390;
    private var mH = 390;
    private var mCx = 195;

    private var mLowPower = false;
    private var mUse24Pref = false;
    private var mShowSeconds = true;

    // Seconds region cache for onPartialUpdate.
    private var mSecX = 0;
    private var mSecY = 0;
    private var mSecW = 20;
    private var mSecH = 34;
    private var mSecT = 5;
    private var mSecGap = 5;
    private var mSecClipX = 0;
    private var mSecClipY = 0;
    private var mSecClipW = 0;
    private var mSecClipH = 0;

    // Dot-matrix world map: [row, startCol, endCol] of "land", 56 cols x 20 rows.
    private const MAP_COLS = 56;
    private var mMap = [
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
        [19, 18, 19]
    ];

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        mW = dc.getWidth();
        mH = dc.getHeight();
        mCx = mW / 2;
    }

    function onShow() {
    }

    private function loadSettings() {
        mUse24Pref = readBool("Use24Hour", false);
        mShowSeconds = readBool("ShowSeconds", true);
    }

    private function readBool(key, def) {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        if (v == null) {
            return def;
        }
        return v;
    }

    // ------------------------------------------------------------------
    // Full redraw (wake + once per minute).
    // ------------------------------------------------------------------
    function onUpdate(dc) {
        loadSettings();

        var clock = Sys.getClockTime();
        var settings = Sys.getDeviceSettings();

        // Black resin case.
        dc.setColor(C_CASE, C_CASE);
        dc.clear();

        drawCase(dc);
        drawCaseText(dc);
        drawPanel(dc);
        drawGlint(dc);
        drawActivityWindow(dc);
        drawAlarmWindow(dc, settings);
        drawWorldMap(dc);
        drawInfoRow(dc, clock);
        drawTime(dc, clock, settings);
        drawStatus(dc, settings);
    }

    // Per-second seconds update.
    function onPartialUpdate(dc) {
        if (!mShowSeconds || mLowPower || mSecClipW <= 0) {
            return;
        }
        var clock = Sys.getClockTime();
        dc.setClip(mSecClipX, mSecClipY, mSecClipW, mSecClipH);
        dc.setColor(C_PANEL, C_PANEL);
        dc.clear();
        drawSegString(dc, clock.sec.format("%02d"), mSecX, mSecY,
            mSecW, mSecH, mSecT, mSecGap);
        dc.clearClip();
    }

    function onEnterSleep() {
        mLowPower = true;
        Ui.requestUpdate();
    }

    function onExitSleep() {
        mLowPower = false;
        Ui.requestUpdate();
    }

    // ------------------------------------------------------------------
    // Case (resin) printed text on the black surround.
    // ------------------------------------------------------------------
    private function drawCaseText(dc) {
        dc.setColor(C_CASETX, Gfx.COLOR_TRANSPARENT);
        dc.drawText(mCx, 30, Gfx.FONT_TINY, "CASIO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mCx, 52, Gfx.FONT_XTINY, "WORLD TIME",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(125, 344, Gfx.FONT_XTINY, "ILLUMINATOR",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(270, 344, Gfx.FONT_XTINY, "WR 100M",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mCx, 364, Gfx.FONT_XTINY, "AE-1200WH",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Resin case rim + the four Casio pushers.
    // ------------------------------------------------------------------
    private function drawCase(dc) {
        dc.setColor(C_CASEHI, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(mCx, mH / 2, mCx - 2);

        var angles = [150, 210, 30, 330];
        for (var i = 0; i < angles.size(); i++) {
            var a = Math.toRadians(angles[i]);
            var bxc = (mCx + 183 * Math.cos(a)).toNumber();
            var byc = (mH / 2 - 183 * Math.sin(a)).toNumber();
            dc.setColor(C_BTN, Gfx.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bxc - 9, byc - 6, 18, 12, 3);
            dc.setColor(C_BTNHI, Gfx.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(bxc - 9, byc - 6, 18, 12, 3);
        }
    }

    // ------------------------------------------------------------------
    // LCD panel.
    // ------------------------------------------------------------------
    private function drawPanel(dc) {
        dc.setColor(C_EDGE, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(PX - 3, PY - 3, PW + 6, PH + 6, 18);
        dc.setColor(C_PANEL, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(PX, PY, PW, PH, 15);
    }

    // A subtle glass reflection streak near the top-left of the panel.
    private function drawGlint(dc) {
        dc.setColor(C_GLINT, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(PX + 14, PY + 7, PX + 38, PY + 7);
        dc.setPenWidth(2);
        dc.drawLine(PX + 14, PY + 12, PX + 28, PY + 12);
    }

    private function drawWindowFrame(dc, x, y, w, h) {
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 4);
    }

    // ------------------------------------------------------------------
    // Top-left: live heart rate + daily steps.
    // ------------------------------------------------------------------
    private function drawActivityWindow(dc) {
        var x = 62; var y = 88; var w = 92; var h = 50;
        drawWindowFrame(dc, x, y, w, h);

        var hr = currentHeartRate();
        var hrStr = (hr != null) ? hr.format("%d") : "--";
        var hx = x + 16;
        drawHeart(dc, hx, y + 14, C_INK);
        if (hr != null) {
            drawSegString(dc, hrStr, hx + 10, y + 6, 12, 18, 3, 4);
        } else {
            dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
            dc.drawText(hx + 22, y + 14, Gfx.FONT_XTINY, "--",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }

        var steps = 0;
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            steps = info.steps;
        }
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + h - 9, Gfx.FONT_XTINY, steps.format("%d") + " STEPS",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Top-right: active alarm count.
    // ------------------------------------------------------------------
    private function drawAlarmWindow(dc, settings) {
        var x = 236; var y = 88; var w = 92; var h = 50;
        drawWindowFrame(dc, x, y, w, h);

        var count = 0;
        if (settings has :alarmCount && settings.alarmCount != null) {
            count = settings.alarmCount;
        }
        var active = (count > 0);

        var bcx = x + 18; var bcy = y + 18;
        drawBell(dc, bcx, bcy, active ? C_INK : C_DIM);

        if (active) {
            drawSegString(dc, count.format("%d"), bcx + 18, y + 6, 16, 24, 4, 4);
            dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
            dc.drawText(x + w / 2, y + h - 9, Gfx.FONT_XTINY, "ALARM ON",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(C_DIM, Gfx.COLOR_TRANSPARENT);
            dc.drawText(bcx + 30, y + 18, Gfx.FONT_SMALL, "OFF",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.drawText(x + w / 2, y + h - 9, Gfx.FONT_XTINY, "NO ALARM",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ------------------------------------------------------------------
    // World map (dot matrix) shaded for day/night, with sun + moon markers.
    // ------------------------------------------------------------------
    private const MAP_W = 252;
    private const MAP_X0 = 195 - 126;   // mCx - MAP_W/2
    private const MAP_Y0 = 144;
    private const MAP_ROWS = 20;

    private function drawWorldMap(dc) {
        var colSp = MAP_W.toFloat() / MAP_COLS;
        var rowSp = 3.3;

        // Sub-solar point from current UTC time.
        var u = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var uh = u.hour + u.min / 60.0;
        var n = (u.month - 1) * 30.4 + u.day;            // ~day of year
        var decl = Math.toRadians(-23.44 * Math.cos(Math.toRadians(360.0 * (n + 10) / 365.0)));
        var lonSun = 15.0 * (12.0 - uh);

        for (var i = 0; i < mMap.size(); i++) {
            var seg = mMap[i];
            var row = seg[0];
            var lat = 75.0 - (row / (MAP_ROWS - 1.0)) * 130.0;
            var y = (MAP_Y0 + row * rowSp + rowSp / 2).toNumber();
            for (var c = seg[1]; c <= seg[2]; c++) {
                var lon = -180.0 + (c / (MAP_COLS - 1.0)) * 360.0;
                dc.setColor(isDay(lon, lat, decl, lonSun) ? C_INK : C_NIGHT, Gfx.COLOR_TRANSPARENT);
                var x = (MAP_X0 + c * colSp + colSp / 2).toNumber();
                dc.fillCircle(x, y, 2);
            }
        }

        // Sun (day side) and moon (night side) markers.
        drawSun(dc, wrapLon(lonSun), Math.toDegrees(decl), colSp, rowSp);
        drawMoon(dc, wrapLon(lonSun + 180), -Math.toDegrees(decl), colSp, rowSp);
    }

    private function isDay(lon, lat, decl, lonSun) {
        var hh = Math.toRadians(lon - lonSun);
        var la = Math.toRadians(lat);
        return (Math.sin(la) * Math.sin(decl)
            + Math.cos(la) * Math.cos(decl) * Math.cos(hh)) > 0;
    }

    private function wrapLon(lon) {
        var l = lon;
        while (l > 180) { l -= 360; }
        while (l < -180) { l += 360; }
        return l;
    }

    private function mapPx(lon, colSp) {
        var col = (lon + 180.0) / 360.0 * (MAP_COLS - 1);
        return (MAP_X0 + col * colSp + colSp / 2).toNumber();
    }

    private function mapPy(lat, rowSp) {
        var row = (75.0 - lat) / 130.0 * (MAP_ROWS - 1);
        return (MAP_Y0 + row * rowSp + rowSp / 2).toNumber();
    }

    private function drawSun(dc, lon, lat, colSp, rowSp) {
        var x = mapPx(lon, colSp);
        var y = mapPy(lat, rowSp);
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 3);
        dc.setPenWidth(1);
        for (var a = 0; a < 360; a += 45) {
            var r = Math.toRadians(a);
            dc.drawLine((x + 5 * Math.cos(r)).toNumber(), (y + 5 * Math.sin(r)).toNumber(),
                        (x + 7 * Math.cos(r)).toNumber(), (y + 7 * Math.sin(r)).toNumber());
        }
    }

    private function drawMoon(dc, lon, lat, colSp, rowSp) {
        var x = mapPx(lon, colSp);
        var y = mapPy(lat, rowSp);
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 4);
        dc.setColor(C_PANEL, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(x + 2, y - 1, 3);
    }

    // ------------------------------------------------------------------
    // Info row above the time: day-of-week | zone | date.
    // ------------------------------------------------------------------
    private function drawInfoRow(dc, clock) {
        var infoM = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var infoS = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dow = stringUpper(infoM.day_of_week);
        var date = infoS.month.format("%d") + "-" + infoS.day.format("%d");

        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(PX + 18, 224, Gfx.FONT_XTINY, dow,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(PX + PW - 18, 224, Gfx.FONT_XTINY, date,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mCx, 224, Gfx.FONT_XTINY, cityCode(clock),
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // A representative 3-letter world-time city code for the home time zone.
    private function cityCode(clock) {
        var off = 0;
        if (clock has :timeZoneOffset && clock.timeZoneOffset != null) {
            off = (clock.timeZoneOffset / 3600).toNumber();
        }
        var codes = {
            -11 => "MDY", -10 => "HNL", -9 => "ANC", -8 => "LAX", -7 => "DEN",
            -6 => "CHI", -5 => "NYC", -4 => "CCS", -3 => "RIO", -2 => "FEN",
            -1 => "AZO", 0 => "LON", 1 => "PAR", 2 => "CAI", 3 => "MOW",
            4 => "DXB", 5 => "KHI", 6 => "DAC", 7 => "BKK", 8 => "HKG",
            9 => "TYO", 10 => "SYD", 11 => "NOU", 12 => "AKL"
        };
        if (codes.hasKey(off)) {
            return codes[off];
        }
        return "GMT";
    }

    // ------------------------------------------------------------------
    // Status strip: Bluetooth (left) + battery (right), LCD style.
    // ------------------------------------------------------------------
    private function drawStatus(dc, settings) {
        var y = 312;

        // Bluetooth, only when a phone is connected.
        var connected = false;
        if (settings has :phoneConnected && settings.phoneConnected != null) {
            connected = settings.phoneConnected;
        }
        if (connected) {
            var bx = PX + 22;
            dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(bx, y - 7, bx, y + 7);
            dc.drawLine(bx, y - 7, bx + 4, y - 3);
            dc.drawLine(bx + 4, y - 3, bx - 3, y + 3);
            dc.drawLine(bx, y + 7, bx + 4, y + 3);
            dc.drawLine(bx + 4, y + 3, bx - 3, y - 3);
        }

        // Battery gauge.
        var level = 1.0;
        var stats = Sys.getSystemStats();
        if (stats != null && stats.battery != null) {
            level = stats.battery / 100.0;
        }
        var bxr = PX + PW - 46;
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(bxr, y - 6, 22, 12);
        dc.fillRectangle(bxr + 22, y - 3, 3, 6);
        var fillW = (18 * level).toNumber();
        if (fillW > 0) {
            dc.fillRectangle(bxr + 2, y - 4, fillW, 8);
        }
        dc.drawText(bxr - 6, y, Gfx.FONT_XTINY,
            ((level * 100).toNumber()).format("%d") + "%",
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Main 7-segment time + small seconds.
    // ------------------------------------------------------------------
    private function drawTime(dc, clock, settings) {
        var use24 = mUse24Pref || settings.is24Hour;
        var hour = clock.hour;
        if (!use24) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var hh = use24 ? hour.format("%02d") : ((hour < 10) ? (" " + hour.format("%d")) : hour.format("%d"));
        var timeStr = hh + ":" + clock.min.format("%02d");

        var dw = 38; var dh = 62; var dt = 8; var dg = 7;
        var sw = 20; var sh = 34; var st = 5; var sg = 5;
        var gapTS = 12;

        var tw = 4 * dw + 3 * dg + (dt + dg);  // 4 digits + colon
        var showSec = mShowSeconds && !mLowPower;
        var secW = 2 * sw + sg;
        var total = tw + (showSec ? (gapTS + secW) : 0);
        var tx = mCx - total / 2;
        var ty = 238;

        var endx = drawSegString(dc, timeStr, tx, ty, dw, dh, dt, dg);

        if (showSec) {
            var sx = endx + gapTS;
            var sy = ty + dh - sh;
            drawSegString(dc, clock.sec.format("%02d"), sx, sy, sw, sh, st, sg);

            mSecX = sx; mSecY = sy; mSecW = sw; mSecH = sh; mSecT = st; mSecGap = sg;
            mSecClipX = sx - 3;
            mSecClipY = sy - 3;
            mSecClipW = secW + 6;
            mSecClipH = sh + 6;
        } else {
            mSecClipW = 0;
        }
    }

    // ------------------------------------------------------------------
    // 7-segment rendering.
    // ------------------------------------------------------------------

    // Draw a string of 7-seg digits (and ':'). Returns the x after the string.
    private function drawSegString(dc, text, x, y, w, h, t, gap) {
        var cx = x;
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals(":")) {
                var r = t / 2;
                if (r < 2) { r = 2; }
                dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(cx + r, (y + h * 0.34).toNumber(), r);
                dc.fillCircle(cx + r, (y + h * 0.66).toNumber(), r);
                cx += t + gap;
            } else {
                drawDigit(dc, cx, y, w, h, t, ch);
                cx += w + gap;
            }
        }
        return cx;
    }

    // Segment letters lit for each character.
    private function segmentsFor(ch) {
        if (ch.equals("0")) { return "abcdef"; }
        if (ch.equals("1")) { return "bc"; }
        if (ch.equals("2")) { return "abdeg"; }
        if (ch.equals("3")) { return "abcdg"; }
        if (ch.equals("4")) { return "bcfg"; }
        if (ch.equals("5")) { return "acdfg"; }
        if (ch.equals("6")) { return "acdefg"; }
        if (ch.equals("7")) { return "abc"; }
        if (ch.equals("8")) { return "abcdefg"; }
        if (ch.equals("9")) { return "abcdfg"; }
        return "";  // blank -> only ghosts
    }

    private function drawDigit(dc, x, y, w, h, t, ch) {
        var on = segmentsFor(ch);
        var half = h / 2;
        // Each segment: [name, isHorizontal, lx, ty, length]
        drawOneSeg(dc, on, "a", true,  x,         y,              w,           t, y, h);
        drawOneSeg(dc, on, "g", true,  x,         y + half - t/2, w,           t, y, h);
        drawOneSeg(dc, on, "d", true,  x,         y + h - t,      w,           t, y, h);
        drawOneSeg(dc, on, "f", false, x,         y,              half + t/2,  t, y, h);
        drawOneSeg(dc, on, "b", false, x + w - t, y,              half + t/2,  t, y, h);
        drawOneSeg(dc, on, "e", false, x,         y + half - t/2, half + t/2,  t, y, h);
        drawOneSeg(dc, on, "c", false, x + w - t, y + half - t/2, half + t/2,  t, y, h);
    }

    private function drawOneSeg(dc, on, name, horiz, lx, ty, L, t, ytop, dh) {
        var color = (on.find(name) != null) ? C_INK : C_GHOST;
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        var pts;
        if (horiz) {
            pts = [
                [sx(lx,         ty + t/2, ytop, dh), ty + t/2],
                [sx(lx + t/2,   ty,       ytop, dh), ty],
                [sx(lx + L-t/2, ty,       ytop, dh), ty],
                [sx(lx + L,     ty + t/2, ytop, dh), ty + t/2],
                [sx(lx + L-t/2, ty + t,   ytop, dh), ty + t],
                [sx(lx + t/2,   ty + t,   ytop, dh), ty + t]
            ];
        } else {
            pts = [
                [sx(lx + t/2, ty,       ytop, dh), ty],
                [sx(lx + t,   ty + t/2, ytop, dh), ty + t/2],
                [sx(lx + t,   ty + L-t/2, ytop, dh), ty + L-t/2],
                [sx(lx + t/2, ty + L,   ytop, dh), ty + L],
                [sx(lx,       ty + L-t/2, ytop, dh), ty + L-t/2],
                [sx(lx,       ty + t/2, ytop, dh), ty + t/2]
            ];
        }
        dc.fillPolygon(pts);
    }

    // Apply a rightward italic slant: top of a glyph shifts right.
    private function sx(x, y, ytop, dh) {
        return (x + (ytop + dh - y) * 0.10).toNumber();
    }

    // ------------------------------------------------------------------
    // Small icons.
    // ------------------------------------------------------------------
    private function drawHeart(dc, cx, cy, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 1, 2);
        dc.fillCircle(cx + 2, cy - 1, 2);
        dc.fillPolygon([[cx - 4, cy], [cx + 4, cy], [cx, cy + 5]]);
    }

    private function drawBell(dc, cx, cy, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx - 7, cy + 6], [cx - 6, cy + 2], [cx - 4, cy - 4],
            [cx - 2, cy - 7], [cx, cy - 8], [cx + 2, cy - 7],
            [cx + 4, cy - 4], [cx + 6, cy + 2], [cx + 7, cy + 6]
        ]);
        dc.fillRectangle(cx - 8, cy + 6, 16, 2);
        dc.fillCircle(cx, cy + 10, 2);
    }

    // ------------------------------------------------------------------
    // Helpers.
    // ------------------------------------------------------------------
    private function currentHeartRate() {
        try {
            if (Activity has :getActivityInfo) {
                var act = Activity.getActivityInfo();
                if (act != null && act.currentHeartRate != null) {
                    return act.currentHeartRate;
                }
            }
            if (ActivityMonitor has :getHeartRateHistory) {
                var it = ActivityMonitor.getHeartRateHistory(1, true);
                if (it != null) {
                    var sample = it.next();
                    if (sample != null && sample.heartRate != null
                            && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        return sample.heartRate;
                    }
                }
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    private function stringUpper(s) {
        if (s == null) {
            return "";
        }
        return s.toString().toUpper();
    }
}
