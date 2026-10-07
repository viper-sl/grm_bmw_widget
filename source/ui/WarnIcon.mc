// Yellow warning triangle with a dark "!" — marks data whose last few fetch attempts
// failed (StorageKeys.KEY_FETCH_FAILS). Drawn from primitives, not a bitmap: glance
// scope cannot resolve Rez.Drawables, and this has to look the same on both surfaces.
// (:glance) so the glance can use it; the foreground pages share the same code.
using Toybox.Graphics;

(:glance)
class WarnIcon {

    // Triangle of height `h` centered on (cx, cy). Width ≈ 1.15 h (equilateral-ish).
    static function draw(dc, cx, cy, h) {
        var half = (h * 4) / 7;
        var top  = cy - h / 2;
        var bot  = top + h;
        dc.setColor(Theme.COLOR_CAUTION, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, top], [cx + half, bot], [cx - half, bot]]);

        // "!" — a bar and a dot, sized off the triangle so it stays centered at any h.
        var stroke = h / 7;
        if (stroke < 2) { stroke = 2; }
        var x = cx - stroke / 2;
        dc.setColor(Theme.COLOR_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, cy - (h * 3) / 14, stroke, (h * 5) / 14);
        dc.fillRectangle(x, cy + (h * 3) / 14, stroke, stroke);
    }

    // Width the triangle occupies at height `h` — for laying out text beside it.
    static function width(h) {
        return ((h * 4) / 7) * 2;
    }

}
