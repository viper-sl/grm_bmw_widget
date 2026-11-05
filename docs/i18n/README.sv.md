# BMW Status — widget för Garmin Connect IQ

[English](../../README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Nederlands](README.nl.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · **Svenska** · [Suomi](README.fi.md) · [Ελληνικά](README.el.md)

> Översättning av de delar av README som riktar sig till användare — vid tveksamhet gäller den [engelska README](../../README.md). Dokumentation om bygge, arkitektur och tester finns bara på engelska. Skärmbilderna kommer från BMW:s spanska portal; benämningar och layout i ditt land kan skilja sig. Gränssnittet på klockan är på engelska.

En Garmin-**widget** som visar live-status för din BMW på klockan — räckvidd, bränsle, lås, dörrar/fönster, däck, vägmätare och serviceinformation — direkt från det officiella REST-API:et [BMW CarData](https://bmw-cardata.bmwgroup.com/customer/public/api-specification).

> Hobbyprojekt. Har ingen koppling till BMW eller Garmin och är inte godkänt eller supportat av dem.

## Funktioner

- **Glance** — låsstatus, räckvidd och bränsle med en blick i widgetkarusellen.
- **Räckvidd & bränsle** — återstående räckvidd, bränsle i %, liter i tanken / till full tank och en valfri uppskattning av förbrukningen (`~L/100 km`). Elbil och laddhybrid: batteri i % och elektrisk räckvidd.
- **Lås** — SECURED / UNLOCKED, en prick för varje öppen dörr (fram + bak), motorhuv och baklucka, plus en röd **W**-markering när ett fönster är öppet. Tydlig indikator för hur gammal datan är.
- **Vägmätare** — mätarställning och sträcka till nästa service (med valfritt eget värde).
- **Däck** — tryck per hjul jämfört med rekommenderat tryck och en uppskattning av däckslitaget (START växlar mellan de tre vyerna).
- **Bilens position** — din parkerade bil på klockans egen karta; START slår på eller av en zoomvy som går att panorera. Bara på enheter med kartstöd (alla som stöds utom Forerunner 255, 255 Music, 265 och 745).
- **About car** — grupperad, skrivskyddad översikt med fasta fordonsuppgifter och live-telematik (12 V-batteri, kylvätska, position, Teleservice, …).
- **Inställningar på klockan** — uppdateringsläge, tankvolym, eget värde för nästa service, förbrukningsuppskattning och undermenyn **Manage** (parkoppla om / logga ut / radera alla containrar).

## Enheter som stöds

Garmin-klockor i serierna fēnix, epix, Enduro, MARQ och Forerunner. Den aktuella listan — och vilka enheter som inte stöds — finns i den [engelska README](../../README.md#supported-devices).

## Kom igång

Du behöver ett **BMW CarData Client ID** (gratis, skapas i BMW CarData-portalen) och ett My BMW-konto i ett land där CarData erbjuds (EU / Storbritannien). Allt annat sker automatiskt: klockan hittar ditt VIN och skapar sina egna datacontainrar.

### 1. Skapa en BMW CarData-klient

Görs en gång, cirka 10 minuter. Benämningarna i portalen skiljer sig mellan språk; här används de spanska som exempel — det är också dem du ser på skärmbilderna.

1. Logga in i **My BMW-webbportalen** för ditt land och öppna fordonsöversikten — t.ex. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Öppna **BMW CARDATA**.
3. I avsnittet för teknisk åtkomst — *Technical access to BMW CarData* / ES *ACCESO TÉCNICO A BMW CARDATA* — **skapa en klient** och kopiera **Client ID**.
4. Slå på **båda** reglagen: *CarData API access* (ES *Solicitar acceso a la API de CarData*) och *CarData streaming* (ES *Transmisión de CarData*). Widgeten ber om båda behörigheterna samtidigt vid inloggningen, så båda måste vara på även om bara REST-API:et används.

   ![BMW CarData-portalen (spanska): klientsidan med Client ID — överstruket här — och båda reglagen påslagna](../images/cardata-client.png)

5. Öppna **dataurvalet** (ES *Cambiar selección de datos*) i streamingavsnittet och kryssa i datafälten från avsnitt 2. Att välja allt fungerar också — widgeten begär aldrig något utanför den listan.

   ![BMW CarData-portalen (spanska): streamingkortet med status "ready" och knappen "Cambiar selección de datos"](../images/cardata-streaming.png)

6. Spara och **vänta 5–10 minuter**: en nyskapad klient går inte att använda direkt.

### 2. Välja datafält

Det är exakt de **41 datafälten** i widgetens "fulla" container. Listan (tekniska namn, samma på alla språk) finns i den engelska README: [Select the data fields](../../README.md#2-select-the-data-fields).

![BMW CarData-portalen (spanska): urvalet av fordonsdata med de 41 fälten ikryssade](../images/cardata-data-selection.png)

Tips: slå på filtret som bara visar valda attribut (ES *Mostrar solo atributos seleccionados*) för att kontrollera ditt urval.

### 3. Parkoppla klockan

1. **Garmin Connect** → din enhet → *Connect IQ Apps* → **BMW Status** → *Settings* → klistra in **Client ID**. Lämna VIN och Container ID tomma.
2. Öppna widgeten → **START to connect**. En parkopplingskod och en länk visas.
3. Godkänn koden på länken som klockan visar (BMW skickar den tillsammans med koden; annars `customer.bmwgroup.com/oneid/#/link`), på en telefon eller dator, och logga in med ditt BMW-konto.
4. Klockan hittar ditt VIN, skapar båda containrarna och hämtar din bils data. Du behöver inte skriva in VIN eller containrar. Refresh token gäller i cirka 2 veckor och förnyas vid varje användning — en widget du öppnar regelbundet förblir parkopplad.

### Uppdatering

- **START** på sidan *Range & Fuel* eller *Lock* → omedelbar fullständig uppdatering (60 s väntetid). På *Tyres* växlar START mellan faktiskt/rekommenderat/slitage, på kartsidan slår det på eller av zoomen, på *Odometer* gör det ingenting.
- **En gång om dagen vid cirka 10:00** — en fullständig hämtning, även i manuellt läge; den håller också inloggningen (token) vid liv.
- **Update Mode** (*Auto hourly* / *Auto adaptive*) finns bara på enheter med **API 6.0+** — fēnix 8, 8 Pro, 8 Solar, fēnix 9 (alla varianter), fēnix E, Enduro 3 / 4, MARQ Gen 3, FR970. Alla andra enheter kör manuellt + dagligen, och inställningen är dold.
- BMW tillåter **cirka 50 datanrop per 24 timmar**. En fullständig uppdatering använder 3, en bakgrundshämtning 1; förnyelse av token räknas inte.
- Hur färsk datan är beror på **bilen**, inte på widgeten: en parkerad BMW kanske bara rapporterar med några timmars mellanrum. Sidorna visar därför hur gammal datan är.

### Felsökning

| Visning / symptom | Orsak / lösning |
|---|---|
| `BMW Widget` / `Add Client ID in the Garmin Connect app` | Inget Client ID i inställningarna än — steg 3.1. Mellanslag i början eller slutet vid inklistring ignoreras. |
| `Auth failed` → `Client ID looks incomplete — copy it again…` | BMW avvisade parkopplingen och det sparade värdet är inte ett fullständigt Client ID på 36 tecken — oftast har bara halva klistrats in. Kopiera det igen från portalen. |
| `Phone link lost — retrying…` vid parkoppling | Klockan tappade kontakten med Garmin Connect en stund (vanligt när du godkänner på samma telefon). Koden gäller fortfarande; godkänn färdigt så fortsätter klockan av sig själv. |
| `No car on this BMW account` | Ditt BMW ID har inget fordon, eller så är du inte dess **huvudanvändare**. CarData betjänar bara huvudanvändaren. |
| `Car not readable — check VIN` | VIN i inställningarna är fel, eller bilen finns inte längre på kontot. Töm VIN-fältet så att widgeten hittar det själv. |
| `No car data yet` / `Check data selection in BMW portal` | Hämtningen lyckades men gav inget som går att visa: inga datafält ikryssade (steg 1.5) eller så har bilen inte rapporterat sedan dess. |
| Parkopplingen misslyckas direkt efter att klienten skapats | Aktiveringen i portalen (5–10 min) är inte klar än; försök igen. |
| `Re-auth needed` / `Press START to re-pair` | Refresh token har gått ut (widgeten har inte öppnats på mer än ~2 veckor) → **Manage → Re-pair**. |
| `Auth failed` → `Check CarData API + streaming are on in the BMW portal` | Ett av klientens två reglage är avstängt i portalen (steg 1.4). Widgeten begär båda behörigheterna i en enda förfrågan, så BMW avvisar hela parkopplingen. Slå på det igen, vänta **5–10 min** och tryck START igen. |
| Containerfel / `CU-124` | BMW tillåter högst **10 containrar** per konto. Installationen erbjuder att radera alla och försöka igen; annars **Manage → Delete containers** (widgeten skapar sina egna på nytt). |
| En sida saknas eller värden är tomma | Din bil (eller ditt CarData-urval) rapporterar inte det fältet — sidor döljer sig själva när deras viktigaste data saknas. |

## Integritet

Widgeten läser dina fordonsdata bara för att visa dem på klockan; inget skickas någon annanstans än till BMW:s eget API — det finns ingen server bakom appen, ingen analys och inga tredjeparts-SDK:er. Fullständig policy (på engelska): [`PRIVACY.md`](../../PRIVACY.md).
