// Page: Lock overview — matches UX mock page 3.
// Header · "SECURED/UNLOCKED" status · ONE state icon (48×48) centered below it ·
// cross layout: HOOD above · door cells on the sides · TRUNK below.
// Rear-door cells render ONLY when the vehicle reports them (FR-19, OQ-4) — a car
// without row2 descriptors keeps the original single DOOR L/R cross.
// OK/START → manual data refresh (same as the range/fuel page).
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

class PageLock extends WatchUi.View {

    var _iconClosed;   // closed_w.png (48×48) — shown when secured
    var _iconOpen;     // open_w.png   (48×48) — shown when unsecured

    var _sync;
    var _refreshing;
    var _rateLimited;

    function initialize() {
        View.initialize();
        _refreshing  = false;
        _rateLimited = false;
        try { _iconClosed = WatchUi.loadResource(Rez.Drawables.ClosedIcon); } catch (e) { _iconClosed = null; }
        try { _iconOpen   = WatchUi.loadResource(Rez.Drawables.OpenIcon);   } catch (e) { _iconOpen   = null; }
    }

    function onSelect() {
        if (_refreshing) { return true; }
        var lastSync = Application.Storage.getValue(ForegroundSync.KEY_LAST_FG);
        if (lastSync != null && (Time.now().value() - lastSync) < ForegroundSync.COOLDOWN_SECONDS) {
            return true;
        }
        _refreshing  = true;
        _rateLimited = false;
        WatchUi.requestUpdate();
        _sync = new ForegroundSync();
        _sync.run(method(:onRefreshDone), true);  // START = manual full refresh
        return true;
    }

    function onRefreshDone(success) {
        _refreshing = false;
        if (!success && _sync != null && _sync.isRateLimited()) {
            _rateLimited = true;   // daily limit — show note, don't bounce to auth
        } else if (!success) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
        }
        WatchUi.requestUpdate();
    }

    // FR-16: a Cache that has previously held doorsLocked keeps showing this page (with
    // its last-known state + Data Age) even if the most recent fetch omitted it — the
    // FR-15 merge-on-write ensures doorsLocked is never dropped from the Cache once seen.
    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("doorsLocked");
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();
        var state = VehicleCache.read();
        if (state == null) { return; }
        _renderDirect(dc, state);
    }

    function _renderDirect(dc, state) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);

        var locked = state.hasKey("doorsLocked") ? state["doorsLocked"] : true;

        // Status label at top. (FR-17 RUNNING state removed — engine.isIgnitionOn never
        // populates on this vehicle/account, B10; the amber RUNNING branch was unreachable.)
        var statusLabel;
        var statusColor;
        if (locked) {
            statusLabel = "SECURED";
            statusColor = Theme.COLOR_OK_HI;
        } else {
            statusLabel = "UNLOCKED";
            statusColor = Theme.COLOR_WARN;
        }
        dc.setColor(statusColor, Theme.COLOR_BG);
        dc.drawText(cx, PageChrome.s(dc, 52), Graphics.FONT_SMALL, statusLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Icon + cross shifted down to sit between the status label and age text
        var mid = cy + PageChrome.s(dc, 16);
        var icon = locked ? _iconClosed : _iconOpen;
        if (icon != null) {
            dc.drawBitmap(cx - icon.getWidth() / 2, mid - icon.getHeight() / 2, icon);
        }

        // Cross layout: HOOD above · door cells on sides · TRUNK below.
        _cell(dc, cx, mid - PageChrome.s(dc, 46), "HOOD",  state, "hoodOpen", null, 0);
        _cell(dc, cx, mid + PageChrome.s(dc, 46), "TRUNK", state, "trunkOpen", null, 0);

        // FR-19: rear doors only if this vehicle reports them — then each side
        // stacks front above rear; otherwise the original single DOOR L/R cells.
        // FR-18: each door cell shows a red "W" badge beside its status dot when
        // that door's window is open/intermediate.
        var hasRear = state.hasKey("doorRLOpen") || state.hasKey("doorRROpen");
        if (hasRear) {
            _cell(dc, cx - PageChrome.s(dc, 60), mid - PageChrome.s(dc, 22), "DOOR FL", state, "doorFLOpen", "windowFLOpen", -PageChrome.s(dc, 18));
            _cell(dc, cx + PageChrome.s(dc, 60), mid - PageChrome.s(dc, 22), "DOOR FR", state, "doorFROpen", "windowFROpen", PageChrome.s(dc, 18));
            _cell(dc, cx - PageChrome.s(dc, 60), mid + PageChrome.s(dc, 24), "DOOR RL", state, "doorRLOpen", "windowRLOpen", -PageChrome.s(dc, 18));
            _cell(dc, cx + PageChrome.s(dc, 60), mid + PageChrome.s(dc, 24), "DOOR RR", state, "doorRROpen", "windowRROpen", PageChrome.s(dc, 18));
        } else {
            _cell(dc, cx - PageChrome.s(dc, 60), mid, "DOOR L", state, "doorFLOpen", "windowFLOpen", -PageChrome.s(dc, 18));
            _cell(dc, cx + PageChrome.s(dc, 60), mid, "DOOR R", state, "doorFROpen", "windowFROpen", PageChrome.s(dc, 18));
        }

        PageChrome.drawAgeProminent(dc, state);
        PageChrome.drawNavDots(dc);
        PageChrome.drawRefreshHint(dc, _refreshing);
        if (_rateLimited) { PageChrome.drawRateLimitNote(dc); }
    }

    function _drawWindowBadge(dc, x, y, radius) {
        dc.setColor(Theme.COLOR_ERROR, Theme.COLOR_BG);
        dc.fillCircle(x, y, radius);
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_ERROR);
        dc.drawText(x, y, Graphics.FONT_XTINY, "W",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // windowKey/badgeDx: when windowKey is non-null and that window is open/intermediate,
    // draw a red "W" badge offset by badgeDx on the same row as the status dot.
    function _cell(dc, x, y, name, state, key, windowKey, badgeDx) {
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(x, y - PageChrome.s(dc, 12), Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var isOpen = state.hasKey(key) ? state[key] : false;
        if (isOpen) {
            dc.setColor(Theme.COLOR_ERROR, Theme.COLOR_BG);
            dc.drawCircle(x, y + PageChrome.s(dc, 10), PageChrome.s(dc, 7));
            dc.fillCircle(x, y + PageChrome.s(dc, 10), PageChrome.s(dc, 3));
        } else {
            dc.setColor(Theme.COLOR_OK, Theme.COLOR_BG);
            dc.fillCircle(x, y + PageChrome.s(dc, 10), PageChrome.s(dc, 7));
        }

        if (windowKey != null && state.hasKey(windowKey) && state[windowKey]) {
            _drawWindowBadge(dc, x + badgeDx, y + PageChrome.s(dc, 10), PageChrome.s(dc, 8));
        }
    }

}
