// Input delegate for the map page ONLY — every other page uses the shared
// PageDelegate. This one exists for two reasons:
//   * PageDelegate never overrides onBack, so BACK in zoom mode would fall through
//     and exit the widget instead of collapsing back to preview (FR-34).
//   * While the native browse interface owns UP/DOWN for zooming, those buttons
//     must not also move the page carousel (FR-33).
// onSelect is deliberately NOT overridden: it inherits PageDelegate's, keeping the
// NEEDS_REBOOTSTRAP re-pair check and routing OK through PageNav.selectCurrent()
// exactly like every other page.
using Toybox.WatchUi;

(:mapPage)
class MapPageDelegate extends PageDelegate {

    var _view;

    function initialize(view) {
        PageDelegate.initialize();
        _view = view;
    }

    // FR-33 — swallow carousel navigation while zooming.
    function onNextPage() {
        if (_view != null && _view.isBrowsing()) { return true; }
        return PageDelegate.onNextPage();
    }

    function onPreviousPage() {
        if (_view != null && _view.isBrowsing()) { return true; }
        return PageDelegate.onPreviousPage();
    }

    // FR-34 — zoom mode collapses to preview. FR-35 — in preview, defer to the
    // default so BACK behaves exactly as it does on every other page.
    function onBack() {
        if (_view != null && _view.isBrowsing()) {
            _view.setMapMode(WatchUi.MAP_MODE_PREVIEW);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

}
