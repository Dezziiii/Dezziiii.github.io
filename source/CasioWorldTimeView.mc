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
// Models the physical watch: black resin case, resin strap lugs, four metal
// pushers, a recessed cushion LCD with printed bezel text, and the olive
// positive-LCD display with true hand-drawn 7-segment digits and a dot-matrix
// world map shaded for day/night.
//
// Custom data (the FR165 has no compass, and a watch face can only read the
// alarm *count*): top-left window = heart rate + steps, top-right = alarms.
//
class CasioWorldTimeView extends Ui.WatchFace {

    // ---- Materials (resin / metal / print) ----
    private const C_RESIN   = 0x0D0E11;
    private const C_RESINHI = 0x2C3036;
    private const C_RESINHI2= 0x454B53;
    private const C_RESINSH = 0x040405;
    private const C_STRAP   = 0x101217;
    private const C_STRAPHI = 0x23262D;
    private const C_STRAPSH = 0x040506;
    private const C_METAL   = 0x70757B;
    private const C_METALHI = 0xAEB4BA;
    private const C_METALSH = 0x34373C;
    private const C_PRINT   = 0xC7CABF;
    private const C_PRINTDM = 0x7E8378;

    // ---- LCD ----
    private const C_FRAME   = 0x2B3127;
    private const C_PANEL   = 0x9AA58D;
    private const C_PANELSH = 0x7F8A72;
    private const C_INK     = 0x181B15;
    private const C_GHOST   = 0x828D76;
    private const C_NIGHT   = 0x727C63;
    private const C_GLINT   = 0xBCC5AE;
    private const C_DIM     = 0x5D6655;

    // ---- LCD rectangle ----
    private const PX = 46;
    private const PY = 72;
    private const PW = 298;
    private const PH = 246;

    // ---- World map ----
    private const MAP_COLS = 56;
    private const MAP_ROWS = 20;
    private const MAP_W  = 214;
    private const MAP_X0 = 88;     // pxc - MAP_W/2
    private const MAP_Y0 = 156;

    private var mW = 390;
    private var mH = 390;
    private var mCx = 195;
    private var mCy = 195;

    private var mLowPower = false;
    private var mUse24Pref = false;
    private var mShowSeconds = true;

    // Seconds region cache for onPartialUpdate.
    private var mSecX = 0;
    private var mSecY = 0;
    private var mSecW = 19;
    private var mSecH = 32;
    private var mSecT = 5;
    private var mSecGap = 5;
    private var mSecClipX = 0;
    private var mSecClipY = 0;
    private var mSecClipW = 0;
    private var mSecClipH = 0;

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
        mCy = mH / 2;
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
        return (v == null) ? def : v;
    }

    // ------------------------------------------------------------------
    function onUpdate(dc) {
        loadSettings();
        var clock = Sys.getClockTime();
        var settings = Sys.getDeviceSettings();

        // Resin body.
        dc.setColor(C_RESIN, C_RESIN);
        dc.clear();

        drawStraps(dc);
        drawBezel(dc);
        drawPushers(dc);
        drawCaseText(dc);

        drawPanel(dc);
        drawGlint(dc);
        drawHrDial(dc);
        drawAlarmField(dc, settings);
        drawDashDisplay(dc);
        drawWorldMap(dc, clock);
        drawTime(dc, clock, settings);
        drawDateRow(dc, clock);
    }

    function onPartialUpdate(dc) {
        if (!mShowSeconds || mLowPower || mSecClipW <= 0) {
            return;
        }
        var clock = Sys.getClockTime();
        dc.setClip(mSecClipX, mSecClipY, mSecClipW, mSecClipH);
        dc.setColor(C_PANEL, C_PANEL);
        dc.clear();
        drawSegString(dc, clock.sec.format("%02d"), mSecX, mSecY, mSecW, mSecH, mSecT, mSecGap);
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

    // ==================================================================
    // Physical hardware
    // ==================================================================

    private function drawStraps(dc) {
        drawOneStrap(dc, true);
        drawOneStrap(dc, false);
    }

    private function drawOneStrap(dc, top) {
        var y0 = top ? 0 : mH;
        var y1 = top ? 52 : (mH - 52);
        var wt = 150;
        var wb = 176;
        dc.setColor(C_STRAP, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [mCx - wt / 2, y0], [mCx + wt / 2, y0],
            [mCx + wb / 2, y1], [mCx - wb / 2, y1]
        ]);
        dc.setColor(C_STRAPHI, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(mCx - wt / 2 + 4, y0, mCx - wb / 2 + 4, y1);
        dc.setColor(C_STRAPSH, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(mCx + wt / 2 - 4, y0, mCx + wb / 2 - 4, y1);

        // Keeper loop.
        var ky = top ? 20 : (mH - 20);
        var kw = (wb * 0.82).toNumber();
        dc.setColor(C_STRAPHI, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mCx - kw / 2, ky - 6, kw, 12, 2);
        dc.setColor(C_STRAP, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mCx - kw / 2 + 2, ky - 4, kw - 4, 8, 2);

        // Buckle holes on the lower strap.
        if (!top) {
            dc.setColor(C_STRAPSH, Gfx.COLOR_TRANSPARENT);
            for (var i = 0; i < 3; i++) {
                dc.fillCircle(mCx, mH - 40 - i * 11, 2);
            }
        }
    }

    private function drawBezel(dc) {
        dc.setPenWidth(2);
        dc.setColor(C_RESINHI, Gfx.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(34, 60, 322, 270, 46);
        dc.setColor(C_RESINSH, Gfx.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(40, 66, 310, 258, 40);
        // Top-left moulding highlight.
        dc.setColor(C_RESINHI2, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(mCx, mCy, 150, Gfx.ARC_COUNTER_CLOCKWISE, 108, 162);
    }

    private function drawPushers(dc) {
        drawPusher(dc, 40, 120);
        drawPusher(dc, 40, 270);
        drawPusher(dc, mW - 40, 120);
        drawPusher(dc, mW - 40, 270);
    }

    private function drawPusher(dc, cx, cy) {
        // Resin guard nubs.
        dc.setColor(C_RESINHI, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 7, cy - 18, 14, 8, 3);
        dc.fillRoundedRectangle(cx - 7, cy + 10, 14, 8, 3);
        // Metal dome.
        dc.setColor(C_METALSH, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 10);
        dc.setColor(C_METAL, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 9);
        dc.setColor(C_METALHI, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 2, 5);
    }

    private function drawCaseText(dc) {
        dc.setColor(C_PRINT, Gfx.COLOR_TRANSPARENT);
        dc.drawText(mCx, 52, Gfx.FONT_TINY, "WORLD TIME",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(312, 52, Gfx.FONT_TINY, "CASIO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mCx, 338, Gfx.FONT_TINY, "ILLUMINATOR",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ==================================================================
    // LCD
    // ==================================================================

    private function drawPanel(dc) {
        dc.setColor(C_FRAME, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(PX - 4, PY - 4, PW + 8, PH + 8, 24);
        dc.setColor(C_PANEL, Gfx.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(PX, PY, PW, PH, 20);
        dc.setColor(C_PANELSH, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(PX, PY, PW, PH, 20);
    }

    private function drawGlint(dc) {
        dc.setColor(C_GLINT, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(PX + 16, PY + 9, PX + 42, PY + 9);
        dc.setPenWidth(2);
        dc.drawLine(PX + 16, PY + 14, PX + 30, PY + 14);
    }

    // Row 1, left: square heart-rate dial (keeps the AE1200 square + circular
    // dial look, repurposed for heart rate).
    private const R1Y = 84;
    private const SQS = 66;

    private function drawHrDial(dc) {
        var sqx = PX + 8;
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(sqx, R1Y, SQS, SQS);

        var dcx = sqx + SQS / 2;
        var dcy = R1Y + 30;
        var dr = 20;
        dc.setColor(C_GHOST, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(dcx, dcy, dr);
        dc.setPenWidth(1);
        for (var a = 0; a < 360; a += 30) {
            var r = Math.toRadians(a);
            dc.drawLine((dcx + (dr - 3) * Math.cos(r)).toNumber(), (dcy + (dr - 3) * Math.sin(r)).toNumber(),
                        (dcx + dr * Math.cos(r)).toNumber(), (dcy + dr * Math.sin(r)).toNumber());
        }

        // Needle: map HR 40..200 bpm onto a 270-degree sweep (gap at bottom).
        var hr = currentHeartRate();
        var frac = 0.0;
        if (hr != null) {
            frac = (hr - 40) / 160.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
        }
        var nang = Math.toRadians(135 + frac * 270);
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(dcx, dcy,
            (dcx + (dr - 3) * Math.cos(nang)).toNumber(),
            (dcy + (dr - 3) * Math.sin(nang)).toNumber());
        dc.fillCircle(dcx, dcy, 3);

        // Bottom: heart + bpm number.
        drawHeart(dc, dcx - 13, R1Y + SQS - 12, C_INK);
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(dcx + 2, R1Y + SQS - 9, Gfx.FONT_XTINY, (hr != null) ? hr.format("%d") : "--",
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // Row 1, middle: alarm (directly right of the square).
    private function drawAlarmField(dc, settings) {
        var count = 0;
        if (settings has :alarmCount && settings.alarmCount != null) {
            count = settings.alarmCount;
        }
        var active = (count > 0);
        var alx = PX + 8 + SQS + 8;
        var alw = 64;

        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(alx + alw / 2, R1Y + 12, Gfx.FONT_XTINY, "ALARM",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(active ? C_INK : C_DIM, Gfx.COLOR_TRANSPARENT);
        drawBell(dc, alx + 14, R1Y + 34);

        if (active) {
            drawSegString(dc, count.format("%d"), alx + 30, R1Y + 22, 16, 24, 4, 4);
        } else {
            dc.setColor(C_DIM, Gfx.COLOR_TRANSPARENT);
            dc.drawText(alx + 40, R1Y + 34, Gfx.FONT_SMALL, "0",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(alx + alw / 2, R1Y + SQS - 8, Gfx.FONT_XTINY, active ? "ALM-SET" : "ALM-OFF",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // Row 1, right: a stopwatch-style chrono display (the AE1200 STW mode in
    // its reset state) plus the little dash row.
    private function drawDashDisplay(dc) {
        var dxx = PX + 8 + SQS + 8 + 64 + 8;
        var dxw = PX + PW - 8 - dxx;

        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(dxx + 4, R1Y + 12, Gfx.FONT_XTINY, "STW",
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(dxx + dxw - 2, R1Y + 12, Gfx.FONT_XTINY, "1/100",
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);

        // Reset chrono MIN:SEC + centiseconds.
        var endc = drawSegString(dc, "00:00", dxx + 6, R1Y + 22, 12, 18, 3, 3);
        drawSegString(dc, "00", endc + 4, R1Y + 28, 7, 11, 2, 2);
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(dxx + dxw - 2, R1Y + 40, Gfx.FONT_XTINY, "SPLIT",
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);

        // Dash row.
        for (var i = 0; i < 3; i++) {
            drawDigit(dc, dxx + 6 + i * 12, R1Y + SQS - 12, 10, 4, 4, "-");
        }
    }

    // ------------------------------------------------------------------
    // World map shaded for day/night + sun/moon + home cursor.
    // ------------------------------------------------------------------
    private function drawWorldMap(dc, clock) {
        var colSp = MAP_W.toFloat() / MAP_COLS;
        var rowSp = 2.8;

        var u = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var uh = u.hour + u.min / 60.0;
        var n = (u.month - 1) * 30.4 + u.day;
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

        // Home-city pointer above the map (the blinking AE1200 cursor).
        var off = 0;
        if (clock has :timeZoneOffset && clock.timeZoneOffset != null) {
            off = (clock.timeZoneOffset / 3600).toNumber();
        }
        var homeLon = off * 15;
        if (homeLon > 180) { homeLon = 180; }
        if (homeLon < -180) { homeLon = -180; }
        var hxp = mapPx(homeLon, colSp);
        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon([[hxp - 4, MAP_Y0 - 8], [hxp + 4, MAP_Y0 - 8], [hxp, MAP_Y0 - 2]]);

        drawSun(dc, wrapLon(lonSun), Math.toDegrees(decl), colSp, rowSp);
        drawMoon(dc, wrapLon(lonSun + 180), -Math.toDegrees(decl), colSp, rowSp);
    }

    private function isDay(lon, lat, decl, lonSun) {
        var hh = Math.toRadians(lon - lonSun);
        var la = Math.toRadians(lat);
        return (Math.sin(la) * Math.sin(decl) + Math.cos(la) * Math.cos(decl) * Math.cos(hh)) > 0;
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
            dc.drawLine((x + 4 * Math.cos(r)).toNumber(), (y + 4 * Math.sin(r)).toNumber(),
                        (x + 6 * Math.cos(r)).toNumber(), (y + 6 * Math.sin(r)).toNumber());
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
        return codes.hasKey(off) ? codes[off] : "GMT";
    }

    // ------------------------------------------------------------------
    // Row 3: big time + small seconds, with AM/PM.
    // ------------------------------------------------------------------
    private function drawTime(dc, clock, settings) {
        var use24 = mUse24Pref || settings.is24Hour;
        var hour = clock.hour;
        var ampm = (clock.hour < 12) ? "AM" : "PM";
        if (!use24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var hh = use24 ? hour.format("%02d") : ((hour < 10) ? (" " + hour.format("%d")) : hour.format("%d"));
        var timeStr = hh + ":" + clock.min.format("%02d");

        var dw = 34; var dh = 54; var dt = 7; var dg = 6;
        var sw = 18; var sh = 30; var st = 5; var sg = 4;
        var gapTS = 10;

        var tw = 4 * dw + 3 * dg + (dt + dg);
        var showSec = mShowSeconds && !mLowPower;
        var secW = 2 * sw + sg;
        var total = tw + (showSec ? (gapTS + secW) : 0);
        var tx = mCx - total / 2 + 6;
        var ty = 220;

        if (!use24) {
            dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
            dc.drawText(tx - 8, ty + 12, Gfx.FONT_XTINY, ampm,
                Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        }

        var endx = drawSegString(dc, timeStr, tx, ty, dw, dh, dt, dg);

        if (showSec) {
            var sx = endx + gapTS;
            var sy = ty + dh - sh;
            drawSegString(dc, clock.sec.format("%02d"), sx, sy, sw, sh, st, sg);
            mSecX = sx; mSecY = sy; mSecW = sw; mSecH = sh; mSecT = st; mSecGap = sg;
            mSecClipX = sx - 3; mSecClipY = sy - 3; mSecClipW = secW + 6; mSecClipH = sh + 6;
        } else {
            mSecClipW = 0;
        }
    }

    // Date row beneath the time: day-of-week | home city | M-D.
    private function drawDateRow(dc, clock) {
        var infoM = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var infoS = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dow = stringUpper(infoM.day_of_week);
        var date = infoS.month.format("%d") + "-" + infoS.day.format("%d");
        var dty = 288;

        dc.setColor(C_INK, Gfx.COLOR_TRANSPARENT);
        dc.drawText(PX + 14, dty, Gfx.FONT_XTINY, dow,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(mCx + 6, dty, Gfx.FONT_XTINY, cityCode(clock),
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(PX + PW - 14, dty, Gfx.FONT_XTINY, date,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ==================================================================
    // 7-segment digits
    // ==================================================================
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
        if (ch.equals("-")) { return "g"; }
        return "";
    }

    private function drawDigit(dc, x, y, w, h, t, ch) {
        var on = segmentsFor(ch);
        var half = h / 2;
        drawOneSeg(dc, on, "a", true,  x,         y,              w,          t, y, h);
        drawOneSeg(dc, on, "g", true,  x,         y + half - t/2, w,          t, y, h);
        drawOneSeg(dc, on, "d", true,  x,         y + h - t,      w,          t, y, h);
        drawOneSeg(dc, on, "f", false, x,         y,              half + t/2, t, y, h);
        drawOneSeg(dc, on, "b", false, x + w - t, y,              half + t/2, t, y, h);
        drawOneSeg(dc, on, "e", false, x,         y + half - t/2, half + t/2, t, y, h);
        drawOneSeg(dc, on, "c", false, x + w - t, y + half - t/2, half + t/2, t, y, h);
    }

    private function drawOneSeg(dc, on, name, horiz, lx, ty, L, t, ytop, dh) {
        dc.setColor((on.find(name) != null) ? C_INK : C_GHOST, Gfx.COLOR_TRANSPARENT);
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
                [sx(lx + t/2, ty,         ytop, dh), ty],
                [sx(lx + t,   ty + t/2,   ytop, dh), ty + t/2],
                [sx(lx + t,   ty + L-t/2, ytop, dh), ty + L-t/2],
                [sx(lx + t/2, ty + L,     ytop, dh), ty + L],
                [sx(lx,       ty + L-t/2, ytop, dh), ty + L-t/2],
                [sx(lx,       ty + t/2,   ytop, dh), ty + t/2]
            ];
        }
        dc.fillPolygon(pts);
    }

    private function sx(x, y, ytop, dh) {
        return (x + (ytop + dh - y) * 0.10).toNumber();
    }

    // ==================================================================
    private function drawHeart(dc, cx, cy, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 1, 2);
        dc.fillCircle(cx + 2, cy - 1, 2);
        dc.fillPolygon([[cx - 4, cy], [cx + 4, cy], [cx, cy + 5]]);
    }

    private function drawBell(dc, cx, cy) {
        // colour already set by caller
        dc.fillPolygon([
            [cx - 6, cy + 5], [cx - 5, cy + 1], [cx - 3, cy - 4],
            [cx - 1, cy - 6], [cx + 1, cy - 6], [cx + 3, cy - 4],
            [cx + 5, cy + 1], [cx + 6, cy + 5]
        ]);
        dc.fillRectangle(cx - 7, cy + 5, 14, 2);
        dc.fillCircle(cx, cy + 8, 1);
    }

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
                    var s = it.next();
                    if (s != null && s.heartRate != null
                            && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        return s.heartRate;
                    }
                }
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    private function stringUpper(s) {
        if (s == null) { return ""; }
        return s.toString().toUpper();
    }
}
