// Single source of truth for the tank-litres math shown on the glance and the
// Range & Fuel page. The class is deliberately tiny — it lands in the glance's
// ~28 KB code image.
//
// (:glance) — KEEP, but the mechanism is UNCONFIRMED. Observed: the glance threw an
// IQ error the first time it rendered this class's math, and stopped once the tag was
// added. What is actually verified about the tag:
//   - builds are deterministic, and the .prg genuinely differs with/without it,
//   - but the .prg is the SAME SIZE either way — no extra code is emitted.
// That size result agrees with docs/findings/connectiq-gotchas.md ("Glance scope"),
// which measured that tagging a *dependency* (vs. the GlanceView itself) is a no-op
// because the glance image is built by reachability. So the tag may well be cosmetic
// and the real fix incidental (e.g. the failing run used a stale build/Storage — see
// the same file's simulator section). Left in place because it is harmless and the
// glance works; do not cite it as a fix for anything until someone A/B's it in the
// simulator (strip the tag, rebuild, open the glance below 50 % fuel).
//
// WHY LITRES ARE DERIVED FROM PERCENT, NOT READ FROM BMW'S LITRES FIELD:
// vehicle.drivetrain.fuelSystem.remainingFuel (Vehicle State "fuelLitres") is NOT
// refreshed with the rest of the telematics. Live captures taken hours apart
// (bmw_data/capture_*_20260614*.json) show it frozen at 44 L, timestamp
// 2026-06-13T17:05:44Z, while fuelSystem.level ("fuelPercent") moved 99 % → 83 %
// → 82 % with fresh timestamps. BMW appears to publish it only around a refuel
// event, and VehicleCache.write()'s merge then keeps that stale value alive
// indefinitely. Deriving from the fresh percent keeps every surface consistent:
// the glance used to read the raw field and rendered "41 % (+8L)" (52 − stale 44)
// while the page derived "31L to fill" (52 − 41 % of 52) for the same car.
using Toybox.Application;

(:glance)
class FuelMath {

    // Fallback when the tankLitres property is unset (matches properties.xml).
    static const DEFAULT_TANK_LITRES = 52;

    // User-configured usable tank size in litres (IQ setting; 40..80 in 4 L steps).
    static function tankLitres() {
        var t = Application.Properties.getValue("tankLitres");
        return (t != null) ? t.toNumber() : DEFAULT_TANK_LITRES;
    }

    // Litres currently in the tank. Truncates rather than rounds, on purpose:
    // never overstate how much fuel is left. Null when the percent is unknown.
    static function litresInTank(fuelPercent) {
        if (fuelPercent == null) { return null; }
        return (tankLitres() * fuelPercent.toNumber()) / 100;
    }

    // Litres still needed to fill the tank. Clamped at 0 — the reported level can
    // read slightly over 100 % right after a brim-full fill.
    static function litresToFill(fuelPercent) {
        var inTank = litresInTank(fuelPercent);
        if (inTank == null) { return null; }
        var fill = tankLitres() - inTank;
        return (fill < 0) ? 0 : fill;
    }

}
