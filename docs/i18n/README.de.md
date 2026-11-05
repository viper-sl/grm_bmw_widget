# BMW Status — Garmin Connect IQ Widget

[English](../../README.md) · **Deutsch** · [Français](README.fr.md) · [Español](README.es.md) · [Nederlands](README.nl.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Svenska](README.sv.md) · [Suomi](README.fi.md) · [Ελληνικά](README.el.md)

**[Direkt zur Einrichtung ↓](#einrichtung)**

> Übersetzung der für Nutzer relevanten Teile des [englischen README](../../README.md) — im Zweifel gilt das englische Original. Build-, Architektur- und Testdokumentation gibt es nur auf Englisch. Die Screenshots stammen aus dem spanischen BMW-Portal; Bezeichnungen und Layout in Ihrem Land können abweichen. Die Anzeigen auf der Uhr sind englisch.

Ein Garmin-**Widget**, das den Live-Status Ihres BMW auf der Uhr anzeigt — Reichweite, Kraftstoff, Verriegelung, Türen/Fenster, Reifen, Kilometerstand und Service-Infos — direkt aus der offiziellen [BMW CarData](https://bmw-cardata.bmwgroup.com/customer/public/api-specification) REST-API.

> Hobbyprojekt. Steht in keiner Verbindung zu BMW oder Garmin und wird von diesen weder empfohlen noch unterstützt.

## Funktionen

- **Glance** — Verriegelungsstatus, Reichweite und Tankfüllung auf einen Blick im Widget-Karussell.
- **Reichweite & Kraftstoff** — Restreichweite, Tankfüllung in %, Liter im Tank bzw. bis voll und eine optionale Verbrauchsschätzung (`~L/100 km`). Elektro und Plug-in-Hybrid: Akkustand in % und elektrische Reichweite.
- **Verriegelung** — SECURED / UNLOCKED, Punkte für jede geöffnete Tür (vorn + hinten), Motorhaube und Kofferraum sowie ein rotes **W**, wenn ein Fenster offen ist. Gut sichtbare Anzeige, wie alt die Daten sind.
- **Kilometerstand** — Gesamtkilometer und Strecke bis zum nächsten Service (optional mit eigenem Wert).
- **Reifen** — Druck je Rad im Vergleich zum Sollwert und Schätzung der Reifenabnutzung (START wechselt zwischen den drei Ansichten).
- **Fahrzeugstandort** — Ihr geparktes Auto auf der Karte der Uhr; START schaltet eine verschiebbare Zoom-Ansicht ein bzw. aus. Nur auf Geräten mit Kartenfunktion (alle unterstützten außer Forerunner 255, 255 Music, 265 und 745).
- **About car** — gruppierte, schreibgeschützte Übersicht mit festen Fahrzeugdaten und Live-Telematik (12-V-Batterie, Kühlmittel, Standort, Teleservice, …).
- **Einstellungen auf der Uhr** — Aktualisierungsmodus, Tankgröße, eigener Service-Wert, Verbrauchsschätzung und das Untermenü **Manage** (erneut koppeln / abmelden / alle Container löschen).

## Unterstützte Geräte

Garmin fēnix, epix, Enduro, MARQ und Forerunner. Die aktuelle Liste — und welche Geräte nicht unterstützt werden — steht im [englischen README](../../README.md#supported-devices).

## Einrichtung

Sie benötigen eine **BMW-CarData-Client-ID** (kostenlos, im BMW-CarData-Portal) und ein My-BMW-Konto in einem Land, in dem CarData angeboten wird (EU / UK). Alles Weitere erledigt das Widget selbst: Die Uhr ermittelt Ihre FIN (VIN) und legt ihre Datencontainer selbst an.

### 1. BMW-CarData-Client anlegen

Einmalig, ca. 10 Minuten. Die Bezeichnungen im Portal unterscheiden sich je nach Sprache; hier stehen die spanischen als Beispiel — sie sind auch auf den Screenshots zu sehen.

1. Melden Sie sich im **My BMW Webportal** Ihres Landes an und öffnen Sie die Fahrzeugübersicht — z. B. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Öffnen Sie **BMW CARDATA**.
3. Legen Sie im Bereich für den technischen Zugang — *Technical access to BMW CarData* / ES *ACCESO TÉCNICO A BMW CARDATA* — einen **Client** an und kopieren Sie die **Client ID**.
4. Schalten Sie **beide** Schalter ein: *CarData API access* (ES *Solicitar acceso a la API de CarData*) und *CarData streaming* (ES *Transmisión de CarData*). Das Widget fordert bei der Anmeldung beide Berechtigungen gemeinsam an, daher müssen beide aktiv sein, obwohl nur die REST-API genutzt wird.

   ![BMW-CarData-Portal (spanisch): Client-Seite mit der Client ID — hier unkenntlich gemacht — und beiden eingeschalteten Schaltern](../images/cardata-client.png)

5. Öffnen Sie im Streaming-Bereich die **Datenauswahl** (ES *Cambiar selección de datos*) und wählen Sie die Datenfelder aus Abschnitt 2 aus. Alles auszuwählen funktioniert ebenfalls — das Widget fordert nie etwas außerhalb dieser Liste an.

   ![BMW-CarData-Portal (spanisch): Streaming-Bereich mit Status „ready" und der Schaltfläche „Cambiar selección de datos"](../images/cardata-streaming.png)

6. Speichern und **5–10 Minuten warten**: Ein neu angelegter Client ist nicht sofort nutzbar.

### 2. Datenfelder auswählen

Es sind genau die **41 Datenfelder** des „vollen" Containers des Widgets. Die Liste (technische Bezeichner, in allen Sprachen identisch) steht im englischen README: [Select the data fields](../../README.md#2-select-the-data-fields).

![BMW-CarData-Portal (spanisch): Datenauswahl mit den 41 angehakten Feldern](../images/cardata-data-selection.png)

Tipp: Schalten Sie den Filter ein, der nur die ausgewählten Attribute zeigt (ES *Mostrar solo atributos seleccionados*), um Ihre Auswahl zu prüfen.

### 3. Uhr koppeln

1. **Garmin Connect** → Ihr Gerät → *Connect IQ Apps* → **BMW Status** → *Settings* → die **Client ID** einfügen. VIN und Container ID bleiben leer.
2. Öffnen Sie das Widget → **START to connect**. Ein Koppelungscode und ein Link erscheinen.
3. Bestätigen Sie den Code am Link, den die Uhr anzeigt (BMW liefert ihn zusammen mit dem Code; ersatzweise `customer.bmwgroup.com/oneid/#/link`), auf einem Smartphone oder Computer und melden Sie sich mit Ihrem BMW-Konto an.
4. Die Uhr ermittelt Ihre FIN, legt beide Container an und lädt die Daten Ihres Autos. VIN und Container müssen nicht eingetippt werden. Das Refresh-Token gilt ca. 2 Wochen und wird bei jeder Nutzung verlängert — ein Widget, das Sie regelmäßig öffnen, bleibt gekoppelt.

### Aktualisierung

- **START** auf der Seite *Range & Fuel* oder *Lock* → sofortige vollständige Aktualisierung (60 s Sperrzeit). Auf *Tyres* wechselt START zwischen Ist-/Soll-/Verschleißansicht, auf der Kartenseite schaltet es den Zoom um, auf *Odometer* tut es nichts.
- **Einmal täglich um ca. 10:00 Uhr** — ein vollständiger Abruf, auch im manuellen Modus; er hält zugleich die Anmeldung (Token) am Leben.
- **Update Mode** (*Auto hourly* / *Auto adaptive*) gibt es nur auf Geräten mit **API 6.0+** — fēnix 8, 8 Pro, 8 Solar, fēnix 9 (alle Varianten), fēnix E, Enduro 3 / 4, MARQ Gen 3, FR970. Alle anderen Geräte aktualisieren manuell + täglich; die Einstellung ist dort ausgeblendet.
- BMW erlaubt **ca. 50 Datenabrufe in 24 Stunden**. Eine vollständige Aktualisierung verbraucht 3, ein Hintergrundabruf 1; das Erneuern des Tokens zählt nicht mit.
- Die Aktualität hängt vom **Auto** ab, nicht vom Widget: Ein geparkter BMW meldet sich unter Umständen nur alle paar Stunden. Die Seiten zeigen deshalb das Alter der Daten an.

### Fehlerbehebung

| Anzeige / Symptom | Ursache / Lösung |
|---|---|
| `BMW Widget` / `Add Client ID in the Garmin Connect app` | In den Einstellungen fehlt noch die Client ID — Schritt 3.1. Leerzeichen am Anfang oder Ende beim Einfügen werden ignoriert. |
| `Auth failed` → `Client ID looks incomplete — copy it again…` | BMW hat die Kopplung abgelehnt, und der gespeicherte Wert ist keine vollständige, 36 Zeichen lange Client ID — meist wurde nur ein Teil eingefügt. Kopieren Sie sie erneut aus dem Portal. |
| `Phone link lost — retrying…` beim Koppeln | Die Uhr hat kurz die Verbindung zu Garmin Connect verloren (häufig, wenn Sie am selben Smartphone bestätigen). Der Code bleibt gültig; schließen Sie die Bestätigung ab — die Uhr macht von selbst weiter. |
| `No car on this BMW account` | Ihre BMW ID hat kein Fahrzeug, oder Sie sind nicht dessen **Hauptnutzer**. CarData liefert nur Daten für den Hauptnutzer. |
| `Car not readable — check VIN` | Die VIN in den Einstellungen ist falsch, oder das Auto gehört nicht mehr zu diesem Konto. Leeren Sie das VIN-Feld, damit das Widget sie selbst ermittelt. |
| `No car data yet` / `Check data selection in BMW portal` | Der Abruf hat funktioniert, lieferte aber nichts Anzeigbares: keine Datenfelder ausgewählt (Schritt 1.5) oder das Auto hat seither nichts gemeldet. |
| Koppeln schlägt direkt nach dem Anlegen des Clients fehl | Die 5–10-minütige Aktivierung im Portal ist noch nicht abgeschlossen; versuchen Sie es später erneut. |
| `Re-auth needed` / `Press START to re-pair` | Das Refresh-Token ist abgelaufen (Widget länger als ca. 2 Wochen nicht geöffnet) → **Manage → Re-pair**. |
| `Auth failed` → `Check CarData API + streaming are on in the BMW portal` | Einer der beiden Schalter Ihres Clients im Portal ist aus (Schritt 1.4). Das Widget fordert beide Berechtigungen in einer Anfrage an, daher lehnt BMW die gesamte Kopplung ab. Schalter wieder einschalten, **5–10 Minuten** warten, dann erneut START drücken. |
| Container-Fehler / `CU-124` | BMW erlaubt pro Konto höchstens **10 Container**. Die Einrichtung bietet an, alle zu löschen und es erneut zu versuchen; andernfalls **Manage → Delete containers** (das Widget legt seine eigenen neu an). |
| Eine Seite fehlt, oder Werte sind leer | Ihr Auto (oder Ihre CarData-Auswahl) liefert dieses Feld nicht — Seiten blenden sich aus, wenn ihre wichtigsten Daten fehlen. |

## Datenschutz

Das Widget liest die Fahrzeugdaten nur, um sie auf Ihrer Uhr anzuzeigen; es wird nichts an andere Stellen als die BMW-eigene API gesendet — es gibt keinen Server hinter dieser App, keine Analyse und kein SDK von Drittanbietern. Vollständige Erklärung (englisch): [`PRIVACY.md`](../../PRIVACY.md).
