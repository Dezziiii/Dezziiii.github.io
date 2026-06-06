using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application;
using Toybox.ActivityMonitor;
using Toybox.Activity;

//
// Casio AE1200 ("World Time") inspired watch face.
//
//  +----------------------------------------+
//  |  [STEPS/HR]     WORLD TIME    [ALARM]   |   <- top-left activity box,
//  |                                          |      top-right alarm box
//  |   . . . dot-matrix world map . . . .     |
//  |          FRI  6 JUN 2026                 |
//  |                                          |
//  |            12:34  56                     |   <- big time + small seconds
//  |        SU MO TU WE TH FR SA              |   <- day-of-week strip
//  +----------------------------------------+
//
// Note on the top-left window: the Forerunner 165 has no magnetometer, so a
// watch face cannot show a live compass heading. Instead, the AE1200's
// top-left window is repurposed as a live activity readout (heart rate +
// daily step count).
//
// Note on alarms: Connect IQ exposes only the *number* of active alarms to a
// watch face (DeviceSettings.alarmCount) -- individual alarm times are not
// available -- so the top-right window shows the active-alarm count.
//
class CasioWorldTimeView extends Ui.WatchFace {

    // --- screen geometry (filled in onLayout) ---
    private var mW = 390;
    private var mH = 390;
    private var mCx = 195;
    private var mCy = 195;

    // --- power / settings state ---
    private var mLowPower = false;
    private var mUse24Pref = false;
    private var mShowSeconds = true;

    // --- theme colors (fixed: the WH-1A positive-LCD look, kept on always) ---
    private var mBg = 0x99A38C;     // greenish LCD background
    private var mInk = 0x1B1D18;    // dark "ink" / segments
    private var mDim = 0x6C7563;    // faded ink (inactive elements)

    // --- seconds region cache, shared with onPartialUpdate ---
    private var mSecX = 0;
    private var mSecCy = 0;
    private var mSecClipX = 0;
    private var mSecClipY = 0;
    private var mSecClipW = 0;
    private var mSecClipH = 0;

    // --- dot-matrix world map ---
    // 56 columns x 20 rows. Each entry is [row, startCol, endCol] of "land".
    // Drawn west->east, north->south, equirectangular and intentionally
    // blocky, exactly like the AE1200's printed map.
    private const MAP_COLS = 56;
    private const MAP_ROWS = 20;
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

    // Read user settings (safe defaults if a property is missing).
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
    // Full redraw (called on wake and once per minute).
    // ------------------------------------------------------------------
    function onUpdate(dc) {
        loadSettings();

        // Background -- the light positive-LCD look, kept on at all times.
        dc.setColor(mInk, mBg);
        dc.clear();

        var clock = Sys.getClockTime();
        var settings = Sys.getDeviceSettings();

        drawWorldMap(dc);
        drawActivityBox(dc);
        drawAlarmBox(dc, settings);
        drawTopLabel(dc);
        drawDate(dc);
        drawDayStrip(dc, clock);
        drawTime(dc, clock, settings);

        // When awake, seconds tick via onPartialUpdate every second.
    }

    // ------------------------------------------------------------------
    // Per-second update: repaint only the small seconds window.
    // ------------------------------------------------------------------
    function onPartialUpdate(dc) {
        if (!mShowSeconds || mLowPower) {
            return;
        }
        if (mSecClipW <= 0) {
            return;
        }
        var clock = Sys.getClockTime();
        var secStr = clock.sec.format("%02d");

        dc.setClip(mSecClipX, mSecClipY, mSecClipW, mSecClipH);
        dc.setColor(mInk, mBg);
        dc.clear();
        dc.drawText(mSecX, mSecCy, Gfx.FONT_NUMBER_MEDIUM, secStr,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
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
    // World map (dot matrix).
    // ------------------------------------------------------------------
    private function drawWorldMap(dc) {
        var mapW = 308;
        var x0 = mCx - mapW / 2;     // left edge
        var y0 = 138;                // top edge
        var colSp = mapW.toFloat() / MAP_COLS;  // ~5.5px
        var rowSp = 4.0;
        var r = 2;

        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        for (var i = 0; i < mMap.size(); i++) {
            var seg = mMap[i];
            var row = seg[0];
            var c0 = seg[1];
            var c1 = seg[2];
            var y = (y0 + row * rowSp + rowSp / 2).toNumber();
            for (var c = c0; c <= c1; c++) {
                var x = (x0 + c * colSp + colSp / 2).toNumber();
                dc.fillCircle(x, y, r);
            }
        }
    }

    // ------------------------------------------------------------------
    // Top-left: live activity readout (heart rate + daily steps).
    // (The FR165 has no compass, so this window shows useful live data.)
    // ------------------------------------------------------------------
    private function drawActivityBox(dc) {
        var bx = 56;
        var by = 60;
        var bw = 92;
        var bh = 74;
        drawWindowFrame(dc, bx, by, bw, bh);
        var ccx = bx + bw / 2;

        // --- Heart rate row (heart icon + bpm) at the top. ---
        var hr = currentHeartRate();
        var hrStr = (hr != null) ? hr.format("%d") : "--";
        var hrW = dc.getTextWidthInPixels(hrStr, Gfx.FONT_XTINY);
        var groupW = 12 + hrW;          // heart (~10px) + gap + text
        var hx = ccx - groupW / 2;
        drawHeart(dc, hx + 4, by + 16, mInk);
        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.drawText(hx + 12, by + 15, Gfx.FONT_XTINY, hrStr,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

        // --- Step count (large, centered). ---
        var steps = 0;
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            steps = info.steps;
        }
        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 41, Gfx.FONT_TINY, steps.format("%d"),
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // --- Label. ---
        dc.drawText(ccx, by + bh - 11, Gfx.FONT_XTINY, "STEPS",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // Latest heart rate from the activity monitor history (null if unknown).
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

    // A small heart icon (two lobes + a point) drawn from primitives.
    private function drawHeart(dc, cx, cy, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 1, 2);
        dc.fillCircle(cx + 2, cy - 1, 2);
        var pts = [
            [cx - 4, cy],
            [cx + 4, cy],
            [cx, cy + 5]
        ];
        dc.fillPolygon(pts);
    }

    // ------------------------------------------------------------------
    // Top-right: active alarm window (count + bell, AE1200 style).
    // ------------------------------------------------------------------
    private function drawAlarmBox(dc, settings) {
        var bw = 92;
        var bh = 74;
        var bx = mW - 56 - bw;
        var by = 60;
        drawWindowFrame(dc, bx, by, bw, bh);

        var count = 0;
        if (settings has :alarmCount && settings.alarmCount != null) {
            count = settings.alarmCount;
        }
        var active = (count > 0);

        // Title.
        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.drawText(bx + bw / 2, by + 13, Gfx.FONT_XTINY, "ALARM",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // Bell icon + count / OFF.
        var bellColor = active ? mInk : mDim;
        drawBell(dc, bx + 28, by + 46, active, bellColor);

        if (active) {
            dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
            dc.drawText(bx + 56, by + 44, Gfx.FONT_NUMBER_MEDIUM, count.format("%d"),
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.drawText(bx + bw / 2, by + bh - 11, Gfx.FONT_XTINY, "ACTIVE",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(mDim, Gfx.COLOR_TRANSPARENT);
            dc.drawText(bx + 58, by + 44, Gfx.FONT_SMALL, "OFF",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.drawText(bx + bw / 2, by + bh - 11, Gfx.FONT_XTINY, "NONE SET",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    // A small alarm bell drawn from primitives.
    private function drawBell(dc, cx, cy, filled, color) {
        var pts = [
            [cx - 7, cy + 6],
            [cx - 6, cy + 2],
            [cx - 4, cy - 4],
            [cx - 2, cy - 7],
            [cx,     cy - 8],
            [cx + 2, cy - 7],
            [cx + 4, cy - 4],
            [cx + 6, cy + 2],
            [cx + 7, cy + 6]
        ];
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        // Base rim.
        dc.fillRectangle(cx - 8, cy + 6, 16, 2);
        // Clapper.
        dc.fillCircle(cx, cy + 10, 2);
        // Top knob.
        dc.fillCircle(cx, cy - 9, 1);
    }

    // ------------------------------------------------------------------
    // Centered "WORLD TIME" label between the two windows.
    // ------------------------------------------------------------------
    private function drawTopLabel(dc) {
        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.drawText(mCx, 74, Gfx.FONT_XTINY, "WORLD TIME",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Date line just under the map.
    // ------------------------------------------------------------------
    private function drawDate(dc) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dow = stringUpper(info.day_of_week);
        var month = stringUpper(info.month);
        var text = dow + "  " + info.day.format("%d") + " " + month + " " + info.year.format("%d");

        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.drawText(mCx, 230, Gfx.FONT_XTINY, text,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Big time (HH:MM) plus small seconds, centered as a group.
    // ------------------------------------------------------------------
    private function drawTime(dc, clock, settings) {
        var use24 = mUse24Pref || settings.is24Hour;
        var hour = clock.hour;
        var ampm = null;
        if (!use24) {
            ampm = (hour < 12) ? "AM" : "PM";
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var hh = use24 ? hour.format("%02d") : hour.format("%d");
        var mm = clock.min.format("%02d");
        var timeStr = hh + ":" + mm;
        var secStr = clock.sec.format("%02d");

        var timeFont = Gfx.FONT_NUMBER_HOT;
        var secFont = Gfx.FONT_NUMBER_MEDIUM;
        var gap = 8;

        var wTime = dc.getTextWidthInPixels(timeStr, timeFont);
        var hTime = dc.getFontHeight(timeFont);
        var showSec = mShowSeconds && !mLowPower;
        var wSec = showSec ? dc.getTextWidthInPixels(secStr, secFont) : 0;
        var hSec = dc.getFontHeight(secFont);

        var groupW = wTime + (showSec ? (gap + wSec) : 0);
        var timeCy = 282;
        var leftX = mCx - groupW / 2;

        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.drawText(leftX, timeCy, timeFont, timeStr,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

        if (showSec) {
            var secX = leftX + wTime + gap;
            // Bottom-align the seconds with the big digits.
            var secCy = timeCy + (hTime / 2) - (hSec / 2);

            dc.drawText(secX, secCy, secFont, secStr,
                Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

            // Cache the region so onPartialUpdate can repaint just this.
            mSecX = secX;
            mSecCy = secCy;
            mSecClipX = secX - 3;
            mSecClipY = secCy - hSec / 2 - 1;
            mSecClipW = wSec + 6;
            mSecClipH = hSec + 2;
        } else {
            mSecClipW = 0;
        }

        // AM/PM marker in 12-hour mode.
        if (ampm != null && !mLowPower) {
            dc.setColor(mDim, Gfx.COLOR_TRANSPARENT);
            dc.drawText(leftX, timeCy - hTime / 2 + 6, Gfx.FONT_XTINY, ampm,
                Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ------------------------------------------------------------------
    // Day-of-week strip (SU MO TU WE TH FR SA) with today highlighted.
    // ------------------------------------------------------------------
    private function drawDayStrip(dc, clock) {
        var labels = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var todayIdx = info.day_of_week - 1;   // 1=Sun -> index 0

        var spacing = 36;
        var y = 332;
        var startX = mCx - 3 * spacing;

        for (var i = 0; i < 7; i++) {
            var x = startX + i * spacing;
            if (i == todayIdx) {
                dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
                dc.drawText(x, y, Gfx.FONT_XTINY, labels[i],
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
                dc.setPenWidth(2);
                dc.drawLine(x - 11, y + 12, x + 11, y + 12);
            } else {
                dc.setColor(mDim, Gfx.COLOR_TRANSPARENT);
                dc.drawText(x, y, Gfx.FONT_XTINY, labels[i],
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    // ------------------------------------------------------------------
    // Helpers.
    // ------------------------------------------------------------------
    private function drawWindowFrame(dc, x, y, w, h) {
        dc.setColor(mInk, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y, w, h, 6);
    }

    private function stringUpper(s) {
        if (s == null) {
            return "";
        }
        return s.toString().toUpper();
    }
}
