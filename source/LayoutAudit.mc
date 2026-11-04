// Layout audit — test builds only. Renders every screen of the widget into a recording
// stand-in for Graphics.Dc and checks, with the device's REAL font metrics, that no
// text leaves the round display and that no two texts (or a text and an icon) overlap.
//
// Why a stand-in: the simulator cannot be screenshotted from automation, and a Dc has
// no pixel read-back. Measuring is enough: getTextDimensions() comes from a real Dc,
// so the numbers are the device's own fonts. Run per device:
//   monkeyc ... --unit-test -d <device> ; monkeydo bin/test.prg <device> -t
// and read the "AUDIT" lines; testLayout_allScreensFit fails if any issue is found.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Test;
using Toybox.Time;

(:debug)
class LayoutAuditDc {

    var _real;      // a real Dc, for font metrics only
    var _w;
    var _h;
    var boxes;      // [x0, y0, x1, y1, label, kind]  kind: 0 text, 1 bitmap

    function initialize(real, w, h) {
        _real = real;
        _w = w;
        _h = h;
        boxes = [];
    }

    function getWidth()  { return _w; }
    function getHeight() { return _h; }
    function getFontHeight(f) { return _real.getFontHeight(f); }
    function getTextDimensions(t, f) { return _real.getTextDimensions(t, f); }
    function getTextWidthInPixels(t, f) { return _real.getTextWidthInPixels(t, f); }

    function setColor(a, b) {}
    function clear() {}
    function setPenWidth(p) {}
    function setAntiAlias(b) {}
    function fillRectangle(x, y, w, h) {}
    function fillRoundedRectangle(x, y, w, h, r) {}
    function fillCircle(x, y, r) {}
    function drawCircle(x, y, r) {}
    function drawLine(a, b, c, d) {}
    function fillPolygon(p) {}

    function drawBitmap(x, y, b) {
        if (b == null) { return; }
        boxes.add([x, y, x + b.getWidth(), y + b.getHeight(), "<bitmap>", 1]);
    }

    function drawText(x, y, font, text, just) {
        if (text == null) { return; }
        text = text.toString();
        var d = _real.getTextDimensions(text, font);
        var w = d[0];
        var fh = d[1];
        // Ink box, not the font's line box: Garmin fonts carry generous internal
        // leading, and the full line box would flag every tightly-stacked pair.
        // 0.70 of the line height covers caps plus descenders on every font measured.
        var ih = (fh * 70) / 100;
        var x0;
        if ((just & 3) == Graphics.TEXT_JUSTIFY_CENTER) { x0 = x - w / 2; }
        else if ((just & 3) == Graphics.TEXT_JUSTIFY_RIGHT) { x0 = x - w; }
        else { x0 = x; }
        var cyText = ((just & Graphics.TEXT_JUSTIFY_VCENTER) != 0) ? y : y + fh / 2;
        boxes.add([x0, cyText - ih / 2, x0 + w, cyText + ih / 2, text, 0]);
    }

    // Issues as strings. round: check corners against the inscribed circle; else the
    // rectangle only (glance area).
    function issues(round) {
        var out = [];
        var r = _w / 2;
        var cx = _w / 2;
        var cy = _h / 2;
        for (var i = 0; i < boxes.size(); i++) {
            var b = boxes[i];
            if (b[5] != 0) { continue; }
            var over = 0;
            if (b[0] < 0) { over = -b[0]; }
            if (b[2] > _w && b[2] - _w > over) { over = b[2] - _w; }
            if (b[1] < 0 && -b[1] > over) { over = -b[1]; }
            if (b[3] > _h && b[3] - _h > over) { over = b[3] - _h; }
            if (round) {
                var xs = [b[0], b[2]];
                var ys = [b[1], b[3]];
                for (var a = 0; a < 2; a++) {
                    for (var c = 0; c < 2; c++) {
                        var dx = xs[a] - cx;
                        var dy = ys[c] - cy;
                        var dist = Math.sqrt(dx * dx + dy * dy);
                        var o = (dist - r).toNumber();
                        if (o > over) { over = o; }
                    }
                }
            }
            if (over > 1) { out.add("CLIP " + over + "px '" + b[4] + "'"); }
        }
        for (var i = 0; i < boxes.size(); i++) {
            for (var j = i + 1; j < boxes.size(); j++) {
                var p = boxes[i];
                var q = boxes[j];
                if (p[5] != 0 && q[5] != 0) { continue; }       // bitmap vs bitmap
                // The map page's halo draws one string 9 times, ±s(1) apart (up to 2×3 px
                // on 466 px screens between opposite copies): not a clash.
                if (p[4].equals(q[4]) && (p[0] - q[0]).abs() <= 6 && (p[1] - q[1]).abs() <= 6) { continue; }
                var ox = _min(p[2], q[2]) - _max(p[0], q[0]);
                var oy = _min(p[3], q[3]) - _max(p[1], q[1]);
                if (ox > 1 && oy > 1) {
                    out.add("OVERLAP " + ox + "x" + oy + "px '" + p[4] + "' / '" + q[4] + "'");
                }
            }
        }
        return out;
    }

    function _min(a, b) { return (a < b) ? a : b; }
    function _max(a, b) { return (a > b) ? a : b; }
}

(:debug)
class LayoutAudit {

    static var _real;
    static var _total;

    static function _realDc() {
        if (_real == null) {
            var bmp;
            if (Graphics has :createBufferedBitmap) {
                bmp = Graphics.createBufferedBitmap({ :width => 8, :height => 8 }).get();
            } else {
                bmp = new Graphics.BufferedBitmap({ :width => 8, :height => 8 });
            }
            _real = bmp.getDc();
        }
        return _real;
    }

    static function _screen() {
        var ds = System.getDeviceSettings();
        return new LayoutAuditDc(_realDc(), ds.screenWidth, ds.screenHeight);
    }

    static function _report(name, dc, round) {
        var iss = dc.issues(round);
        for (var i = 0; i < iss.size(); i++) {
            System.println("AUDIT " + System.getDeviceSettings().screenWidth + " " + name + ": " + iss[i]);
        }
        _total += iss.size();
    }

    // Worst-case content: a long model name, a four-digit range, low fuel (longest
    // litres line), the consumption row, a failing-fetch triangle and the longest
    // failure banner.
    static function _fixtureState() {
        return {
            "rangeKm" => 1088, "fuelPercent" => 15, "fuelLitres" => 8,
            "doorsLocked" => false,
            "doorFLOpen" => true, "doorFROpen" => false, "doorRLOpen" => true, "doorRROpen" => false,
            "windowFLOpen" => true, "windowFROpen" => true, "windowRLOpen" => true, "windowRROpen" => true,
            "hoodOpen" => true, "trunkOpen" => true,
            "odometerKm" => 188888, "serviceDistanceKm" => 28800,
            "tyrePressureFL" => 2.4, "tyrePressureFR" => 2.4, "tyrePressureRL" => 2.9, "tyrePressureRR" => 2.9,
            "tyreTargetFL" => 2.5, "tyreTargetFR" => 2.5, "tyreTargetRL" => 3.0, "tyreTargetRR" => 3.0,
            "tyreWearKmFL" => 18800, "tyreWearKmFR" => 18800, "tyreWearKmRL" => 28800, "tyreWearKmRR" => 28800,
            "lastUpdated" => Time.now().value() - 23 * 3600,
            "latitude" => 48.1, "longitude" => 11.5
        };
    }

    // The longest ForegroundSync.failText() / _friendlyError() string.
    static const LONG_FAIL = "Car not readable — check VIN";

    (:typecheck(false))
    static function run() {
        _total = 0;
        Application.Storage.clearValues();
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_NAME, "BMW M440i xDrive Gran Coupé");
        var st = _fixtureState();
        VehicleCache.write(st);
        for (var k = 0; k < 6; k++) { QuotaGuard.onFetchFailed(); }   // show the ⚠ mark

        // ── data pages, plain and with each banner ─────────────────────────────
        var rf = new PageRangeFuel();
        var dc = _screen(); rf._renderDirect(dc, st); _report("RangeFuel", dc, true);
        rf._failed = true; rf._failText = LONG_FAIL;
        dc = _screen(); rf._renderDirect(dc, st); _report("RangeFuel+fail", dc, true);
        rf._failed = false; rf._rateLimited = true;
        dc = _screen(); rf._renderDirect(dc, st); _report("RangeFuel+limit", dc, true);

        var lk = new PageLock();
        dc = _screen(); lk._renderDirect(dc, st); _report("Lock", dc, true);
        lk._failed = true; lk._failText = LONG_FAIL;
        dc = _screen(); lk._renderDirect(dc, st); _report("Lock+fail", dc, true);

        dc = _screen(); new PageOdometer()._renderDirect(dc, st); _report("Odometer", dc, true);

        var ty = new PageTyres();
        for (var m = 0; m < 3; m++) {
            ty._mode = m;
            dc = _screen(); ty._renderDirect(dc, st); _report("Tyres mode" + m, dc, true);
        }
        _mapOverlays();

        dc = _screen(); PageChrome.drawEmptyState(dc); _report("EmptyState", dc, true);

        // ── shell prompts ─────────────────────────────────────────────────────
        var v = new BmwWidgetView();
        dc = _screen(); v._drawLoading(dc);       _report("Loading", dc, true);
        dc = _screen(); v._drawRateLimited(dc);   _report("RateLimited", dc, true);
        dc = _screen(); v._drawRelinkPrompt(dc);  _report("Relink", dc, true);
        dc = _screen(); v._drawNoData(dc);        _report("NoData", dc, true);
        v._offlineText = LONG_FAIL;
        dc = _screen(); v._drawOffline(dc);       _report("Offline", dc, true);
        var prevCid = Application.Properties.getValue("clientId");
        try {
            Application.Properties.setValue("clientId", "");
            dc = _screen(); v._drawSetupPrompt(dc); _report("Setup(no id)", dc, true);
            Application.Properties.setValue("clientId", "12345678-1234-1234-1234-123456789abc");
            dc = _screen(); v._drawSetupPrompt(dc); _report("Setup", dc, true);
        } finally {
            Application.Properties.setValue("clientId", (prevCid != null) ? prevCid : "");
        }

        _authScreens();
        _glance(st);

        Application.Storage.clearValues();
        return _total;
    }

    (:mapPage, :typecheck(false))
    static function _mapOverlays() {
        if (!(Toybox.WatchUi has :MapView)) { return; }
        var mp = new PageMap();
        var dc = _screen();
        mp._drawHeader(dc);
        mp._drawAge(dc);
        _report("Map overlays", dc, true);
    }
    (:noMapPage) static function _mapOverlays() {}

    (:typecheck(false))
    static function _authScreens() {
        var msgs = [
            DeviceAuthManager.MSG_BAD_CLIENT_ID,
            DeviceAuthManager.MSG_NO_CLIENT_ID,
            DeviceAuthManager._oauthHint("invalid_request"),
            // BMW's own description, capped at _MSG_MAX — the longest text this screen gets.
            DeviceAuthManager._serverError(400, { "error" => "x", "error_description" =>
                "The request is missing a required parameter, includes an unsupported parameter value (other than grant type), repeats a parameter" })
        ];
        for (var i = 0; i < msgs.size(); i++) {
            var a = new DeviceAuthManager();
            a._state = DeviceAuthManager.FAILED;
            a._errMsg = msgs[i];
            var dc = _screen(); new AuthView(a).onUpdate(dc); _report("Auth failed #" + i, dc, true);
        }
        var p = new DeviceAuthManager();
        p._state = DeviceAuthManager.PENDING;
        p._userCode = "WXYZ-MWQM";        // widest plausible 8-char code
        var dc = _screen(); new AuthView(p).onUpdate(dc); _report("Auth pending", dc, true);
        p._linkLost = true;
        dc = _screen(); new AuthView(p).onUpdate(dc); _report("Auth pending+link lost", dc, true);

        var s = new DeviceAuthManager();
        s._state = DeviceAuthManager.SUCCESS;
        var av = new AuthView(s);
        dc = _screen(); av.onUpdate(dc); _report("Auth paired", dc, true);
        av._rateLimited = true;
        dc = _screen(); av.onUpdate(dc); _report("Auth paired+limit", dc, true);
        av._rateLimited = false; av._cleanupFailed = true;
        dc = _screen(); av.onUpdate(dc); _report("Auth cleanup failed", dc, true);
        av._cleanupFailed = false; av._cleaning = true;
        dc = _screen(); av.onUpdate(dc); _report("Auth cleaning", dc, true);

        var r = new AuthView(new DeviceAuthManager());
        r._recovering = true;
        dc = _screen(); r.onUpdate(dc); _report("Auth recovering", dc, true);
    }

    // The glance draws into its own content strip, not the round screen. Sizes are the
    // device's glance contentArea (simulator.json); approximated from the screen width
    // where the two measured families sit, which is what matters for text that fits.
    (:typecheck(false))
    static function _glance(st) {
        var sw = System.getDeviceSettings().screenWidth;
        var gw = (sw <= 280) ? (176 * sw) / 260 : (349 * sw) / 454;
        var gh = (sw <= 280) ? (93 * sw) / 260 : (130 * sw) / 454;
        var g = new BmwWidgetGlanceView();
        var dc = new LayoutAuditDc(_realDc(), gw, gh);
        g.onUpdate(dc);
        _report("Glance", dc, false);
        Application.Storage.deleteValue(StorageKeys.KEY_GLANCE_STATE);
        dc = new LayoutAuditDc(_realDc(), gw, gh);
        g.onUpdate(dc);
        _report("Glance(unset)", dc, false);
    }
}

(:test)
function testLayout_allScreensFit(logger as Test.Logger) as Lang.Boolean {
    var n = LayoutAudit.run();
    System.println("AUDIT " + System.getDeviceSettings().screenWidth + " total issues: " + n);
    Test.assertEqualMessage(n, 0, "text clipped or overlapping — see the AUDIT lines");
    return true;
}
