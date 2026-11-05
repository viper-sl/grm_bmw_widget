# BMW Status — Garmin Connect IQ-widget

[English](../../README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · **Nederlands** · [Italiano](README.it.md) · [Polski](README.pl.md) · [Svenska](README.sv.md) · [Suomi](README.fi.md) · [Ελληνικά](README.el.md)

> Vertaling van de voor gebruikers bedoelde delen van de [Engelse README](../../README.md) — bij twijfel geldt het Engelse origineel. Documentatie over bouwen, architectuur en testen is alleen in het Engels beschikbaar. De screenshots komen uit het Spaanse BMW-portaal; de benamingen en de lay-out in jouw land kunnen afwijken. De weergave op het horloge is in het Engels.

Een Garmin-**widget** die de live status van je BMW op je horloge toont — actieradius, brandstof, vergrendeling, portieren/ramen, banden, kilometerstand en onderhoudsinformatie — rechtstreeks uit de officiële [BMW CarData](https://bmw-cardata.bmwgroup.com/customer/public/api-specification) REST-API.

> Hobbyproject. Niet verbonden aan, goedgekeurd door of ondersteund door BMW of Garmin.

## Functies

- **Glance** — vergrendelstatus, actieradius en brandstof in één oogopslag in de widgetcarrousel.
- **Actieradius & brandstof** — resterende actieradius, brandstof in %, liters in de tank / tot vol en een optionele schatting van het verbruik (`~L/100 km`). Elektrisch en plug-in hybride: accu in % en elektrische actieradius.
- **Vergrendeling** — SECURED / UNLOCKED, een stip per geopend portier (voor + achter), motorkap en kofferbak, plus een rode **W**-badge bij een openstaand raam. Duidelijke indicator van hoe oud de gegevens zijn.
- **Kilometerteller** — kilometerstand en afstand tot de volgende onderhoudsbeurt (optioneel met eigen waarde).
- **Banden** — bandenspanning per wiel ten opzichte van de gewenste waarde en een schatting van de bandenslijtage (START wisselt tussen de drie weergaven).
- **Locatie van de auto** — je geparkeerde auto op de eigen kaart van het horloge; START schakelt een verschuifbare zoomweergave in of uit. Alleen op apparaten met kaarten (alle ondersteunde apparaten behalve Forerunner 255, 255 Music, 265 en 745).
- **About car** — gegroepeerd, alleen-lezen overzicht van vaste voertuiggegevens en live telematica (12V-accu, koelvloeistof, locatie, Teleservice, …).
- **Instellingen op het horloge** — vernieuwingsmodus, tankinhoud, eigen waarde voor onderhoud, verbruiksschatting en het submenu **Manage** (opnieuw koppelen / afmelden / alle containers verwijderen).

## Ondersteunde apparaten

Garmin fēnix-, epix-, Enduro-, MARQ- en Forerunner-horloges. De actuele lijst — en welke apparaten niet worden ondersteund — staat in de [Engelse README](../../README.md#supported-devices).

## Installatie

Je hebt een **BMW CarData Client ID** nodig (gratis, aan te maken in het BMW CarData-portaal) en een My BMW-account in een land waar CarData wordt aangeboden (EU / VK). Al het andere gaat automatisch: het horloge vindt je VIN en maakt zelf zijn gegevenscontainers aan.

### 1. Een BMW CarData-client aanmaken

Eenmalig, ca. 10 minuten. De benamingen in het portaal verschillen per taal; hier staan de Spaanse als voorbeeld — dat zijn ook de benamingen op de screenshots.

1. Log in op het **My BMW-webportaal** van je land en open het voertuigoverzicht — bijv. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Open **BMW CARDATA**.
3. Maak in het gedeelte voor technische toegang — *Technical access to BMW CarData* / ES *ACCESO TÉCNICO A BMW CARDATA* — een **client** aan en kopieer de **Client ID**.
4. Zet **beide** schakelaars aan: *CarData API access* (ES *Solicitar acceso a la API de CarData*) en *CarData streaming* (ES *Transmisión de CarData*). De widget vraagt bij het inloggen beide rechten tegelijk aan, dus allebei moeten aan staan, ook al wordt alleen de REST-API gebruikt.

   ![BMW CarData-portaal (Spaans): de clientpagina met de Client ID — hier onleesbaar gemaakt — en beide schakelaars aan](../images/cardata-client.png)

5. Open in het streaminggedeelte de **gegevensselectie** (ES *Cambiar selección de datos*) en vink de gegevensvelden uit onderdeel 2 aan. Alles selecteren werkt ook — de widget vraagt nooit iets buiten die lijst op.

   ![BMW CarData-portaal (Spaans): de streamingkaart met status "ready" en de knop "Cambiar selección de datos"](../images/cardata-streaming.png)

6. Sla op en **wacht 5–10 minuten**: een net aangemaakte client is niet meteen bruikbaar.

### 2. De gegevensvelden selecteren

Het zijn precies de **41 gegevensvelden** van de "volledige" container van de widget. De lijst (technische namen, in alle talen gelijk) staat in de Engelse README: [Select the data fields](../../README.md#2-select-the-data-fields).

![BMW CarData-portaal (Spaans): de selectie van voertuiggegevens met de 41 aangevinkte velden](../images/cardata-data-selection.png)

Tip: zet het filter aan dat alleen de geselecteerde attributen toont (ES *Mostrar solo atributos seleccionados*) om je selectie te controleren.

### 3. Het horloge koppelen

1. **Garmin Connect** → je apparaat → *Connect IQ Apps* → **BMW Status** → *Settings* → plak de **Client ID**. Laat VIN en Container ID leeg.
2. Open de widget → **START to connect**. Er verschijnen een koppelcode en een link.
3. Keur de code goed via de link die het horloge toont (BMW levert die samen met de code; anders `customer.bmwgroup.com/oneid/#/link`), op een telefoon of computer, en log in met je BMW-account.
4. Het horloge vindt je VIN, maakt beide containers aan en haalt de gegevens van je auto op. VIN en containers hoef je niet in te typen. Het refresh token is ca. 2 weken geldig en wordt bij elk gebruik verlengd — een widget die je regelmatig opent, blijft gekoppeld.

### Vernieuwen

- **START** op de pagina *Range & Fuel* of *Lock* → direct volledig vernieuwen (60 s wachttijd). Op *Tyres* wisselt START tussen werkelijk/gewenst/slijtage, op de kaartpagina schakelt het de zoom om, op *Odometer* doet het niets.
- **Eén keer per dag rond 10:00** — een volledige ophaalronde, ook in handmatige modus; die houdt ook de aanmelding (tokens) in leven.
- **Update Mode** (*Auto hourly* / *Auto adaptive*) bestaat alleen op apparaten met **API 6.0+** — fēnix 8, 8 Pro, 8 Solar, fēnix 9 (alle varianten), fēnix E, Enduro 3 / 4, MARQ Gen 3, FR970. Alle andere apparaten werken handmatig + dagelijks, en de instelling is daar verborgen.
- BMW staat **ca. 50 gegevensaanroepen per 24 uur** toe. Een volledige vernieuwing kost er 3, een achtergrondpoll 1; het verversen van het token telt niet mee.
- De actualiteit hangt af van de **auto**, niet van de widget: een geparkeerde BMW meldt zich soms maar om de paar uur. Daarom tonen de pagina's hoe oud de gegevens zijn.

### Problemen oplossen

| Melding / verschijnsel | Oorzaak / oplossing |
|---|---|
| `BMW Widget` / `Add Client ID in the Garmin Connect app` | Er staat nog geen Client ID in de instellingen — stap 3.1. Spaties aan het begin of einde bij het plakken worden genegeerd. |
| `Auth failed` → `Client ID looks incomplete — copy it again…` | BMW weigerde de koppeling en de opgeslagen waarde is geen volledige Client ID van 36 tekens — meestal is maar de helft geplakt. Kopieer hem opnieuw uit het portaal. |
| `Phone link lost — retrying…` tijdens het koppelen | Het horloge was even de verbinding met Garmin Connect kwijt (komt vaak voor als je op dezelfde telefoon goedkeurt). De code blijft geldig; rond het goedkeuren af — het horloge gaat vanzelf verder. |
| `No car on this BMW account` | Je BMW ID heeft geen voertuig, of je bent niet de **hoofdgebruiker**. CarData bedient alleen de hoofdgebruiker. |
| `Car not readable — check VIN` | De VIN in de instellingen klopt niet, of de auto staat niet meer op dit account. Maak het VIN-veld leeg zodat de widget de VIN zelf vindt. |
| `No car data yet` / `Check data selection in BMW portal` | Het ophalen lukte, maar leverde niets weer te geven op: geen gegevensvelden aangevinkt (stap 1.5) of de auto heeft sindsdien niets gemeld. |
| Koppelen mislukt direct na het aanmaken van de client | De activering in het portaal (5–10 min) is nog niet klaar; probeer het later opnieuw. |
| `Re-auth needed` / `Press START to re-pair` | Het refresh token is verlopen (widget langer dan ca. 2 weken niet geopend) → **Manage → Re-pair**. |
| `Auth failed` → `Check CarData API + streaming are on in the BMW portal` | Een van de twee schakelaars van je client staat uit in het portaal (stap 1.4). De widget vraagt beide rechten in één verzoek aan, dus BMW weigert de hele koppeling. Zet hem weer aan, wacht **5–10 min** en druk opnieuw op START. |
| Containerfout / `CU-124` | BMW staat maximaal **10 containers** per account toe. De installatie biedt aan ze allemaal te verwijderen en opnieuw te proberen; anders **Manage → Delete containers** (de widget maakt zijn eigen containers opnieuw aan). |
| Een pagina ontbreekt of waarden zijn leeg | Je auto (of je CarData-selectie) levert dat veld niet — pagina's verbergen zichzelf als hun belangrijkste gegevens ontbreken. |

## Privacy

De widget leest je voertuiggegevens alleen om ze op je horloge te tonen; er wordt niets verstuurd behalve naar de eigen API van BMW — achter deze app zit geen server, er is geen analytics en geen SDK van derden. Volledig beleid (Engels): [`PRIVACY.md`](../../PRIVACY.md).
