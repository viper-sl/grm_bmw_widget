// Input delegate for the BMW widget carousel.
//
// fēnix 6 is a WIDGET: its *initial* view gets restricted input — UP/DOWN scroll
// the system widget loop and are never delivered to this delegate. The documented
// escape (used by the reference widgets) is to pushView() an interactive copy on
// SELECT/START. The pushed view receives full button input: UP/DOWN page through
// the carousel, BACK pops back to the widget loop.
//
// _interactive = false → initial widget preview (SELECT opens the carousel)
// _interactive = true  → pushed carousel (UP/DOWN navigate, BACK exits)
using Toybox.WatchUi;

class BmwWidgetDelegate extends WatchUi.BehaviorDelegate {

    var _view;
    var _interactive;

    function initialize(view, interactive) {
        BehaviorDelegate.initialize();
        _view = view;
        _interactive = interactive;
    }

    // SELECT/START on the preview opens the interactive carousel.
    function onSelect() {
        if (!_interactive) {
            var v = new BmwWidgetView();
            WatchUi.pushView(v, new BmwWidgetDelegate(v, true), WatchUi.SLIDE_LEFT);
            return true;
        }
        return false;
    }

    function onNextPage() {
        if (_view != null) {
            return _view.onNextPage();
        }
        return false;
    }

    function onPreviousPage() {
        if (_view != null) {
            return _view.onPreviousPage();
        }
        return false;
    }

}
