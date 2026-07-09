// On-watch exact input for the next-service odometer target (FR-23 reworked).
// Custom 3-digit entry view (the stock generic Picker shows one column at a
// time with a clipped title — unusable here). All three digits are always
// visible; the active digit is white with a red underline, the others muted.
// A live preview line shows the resulting odometer ("= 128,000 KM"), or
// "AUTO (BMW)" for 000.
//
// Controls: UP/DOWN change the active digit (wraps 0-9), START moves to the
// next digit and accepts after the last one, BACK steps to the previous
// digit (cancels from the first). Touch swipes map via BehaviorDelegate.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class ServiceOdoInputView extends WatchUi.View {

    var digits;   // [hundreds, tens, ones] of thousands of km
    var idx;      // active digit 0..2

    function initialize() {
        View.initialize();
        var k = SettingsMenu.nextServiceOdoK();
        if (k == 0) {
            // Seed from the current odometer so the user nudges digits
            // instead of dialing from zero.
            var state = VehicleCache.read();
            if (state != null && state.hasKey("odometerKm")) {
                k = state["odometerKm"] / 1000;   // integer thousands
            }
        }
        if (k > 999) { k = 999; }
        if (k < 0)   { k = 0; }
        digits = [k / 100, (k / 10) % 10, k % 10];
        idx = 0;
    }

    function valueK() {
        return digits[0] * 100 + digits[1] * 10 + digits[2];
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setColor(Theme.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, PageChrome.s(dc, 30), Graphics.FONT_XTINY, "NEXT SERVICE",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Three digits, active one white with a red underline.
        var spacing = PageChrome.s(dc, 36);
        var digitY  = cy - PageChrome.s(dc, 24);
        for (var i = 0; i < 3; i++) {
            var x = cx + (i - 1) * spacing;
            dc.setColor((i == idx) ? Theme.COLOR_WHITE : Theme.COLOR_MUTED,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, digitY, Graphics.FONT_NUMBER_MEDIUM, digits[i].toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            if (i == idx) {
                dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - PageChrome.s(dc, 14),
                    digitY + PageChrome.s(dc, 26),
                    PageChrome.s(dc, 28), PageChrome.s(dc, 3));
            }
        }

        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + PageChrome.s(dc, 16), Graphics.FONT_XTINY, "x1000 KM",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Live result preview.
        var k = valueK();
        if (k == 0) {
            dc.setColor(Theme.COLOR_OK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + PageChrome.s(dc, 38), Graphics.FONT_TINY, "AUTO (BMW)",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Theme.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + PageChrome.s(dc, 38), Graphics.FONT_TINY,
                "= " + k.toString() + ",000 KM",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        // No bottom hint line: long text gets clipped by the round screen edge
        // near the bottom, and the red underline already marks the active digit.
    }

}

class ServiceOdoInputDelegate extends WatchUi.BehaviorDelegate {

    var _view;
    var _menuItem;   // the Settings "Next Service" row — sub-label updated on accept

    function initialize(view, menuItem) {
        BehaviorDelegate.initialize();
        _view = view;
        _menuItem = menuItem;
    }

    function onPreviousPage() {   // UP: increment active digit
        _view.digits[_view.idx] = (_view.digits[_view.idx] + 1) % 10;
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {       // DOWN: decrement active digit
        _view.digits[_view.idx] = (_view.digits[_view.idx] + 9) % 10;
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {         // START: next digit, accept after the last
        if (_view.idx < 2) {
            _view.idx += 1;
            WatchUi.requestUpdate();
        } else {
            Application.Properties.setValue("nextServiceOdoK", _view.valueK());
            if (_menuItem != null) {
                _menuItem.setSubLabel(SettingsMenu.nextServiceLabel());
            }
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }

    function onBack() {           // BACK: previous digit, cancel from the first
        if (_view.idx > 0) {
            _view.idx -= 1;
            WatchUi.requestUpdate();
        } else {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }

}
