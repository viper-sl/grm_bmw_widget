# Asset sources

Original/high-resolution sources for the icons shipped in `resources/drawables/`
(which holds the small, device-sized renders actually compiled into the app),
plus UI mockups. Not referenced by any build.

| File | Purpose |
|---|---|
| `bmw-car-icon.png` | BMW car+roundel source → `resources/drawables/launcher_icon.png` (40×40) |
| `bmw-icon-svg.webp` | Older BMW roundel-only source (superseded by `bmw-car-icon.png`) |
| `closed_w.png` / `open_w.png` | Lock-state icon sources (white) → 48×48 drawables of the same name |
| `closed_b.png` / `open_b.png` | Lock-state icon sources (black variant, unused) |
| `Refresh_icon.svg.png` | Refresh icon source → `resources/drawables/refresh_icon.png` |
| `glance.png` | Glance layout mockup (260×260) |

Regenerate a drawable with e.g.:

```sh
sips -s format png -z 40 40 resources-src/bmw-car-icon.png --out resources/drawables/launcher_icon.png
```
