// Input delegate — routes up/down button presses to page navigation.
using Toybox.WatchUi;

class BmwWidgetDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() {
        if (_view != null) { return _view.onNextPage(); }
        return false;
    }

    function onPreviousPage() {
        if (_view != null) { return _view.onPreviousPage(); }
        return false;
    }

}
