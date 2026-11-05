# BMW Status — widżet Garmin Connect IQ

[English](../../README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Nederlands](README.nl.md) · [Italiano](README.it.md) · **Polski** · [Svenska](README.sv.md) · [Suomi](README.fi.md) · [Ελληνικά](README.el.md)

**[Przejdź do konfiguracji ↓](#konfiguracja)**

> Tłumaczenie tych części README, które są przeznaczone dla użytkowników — w razie wątpliwości obowiązuje [angielski README](../../README.md). Dokumentacja budowania, architektury i testów jest tylko po angielsku. Zrzuty ekranu pochodzą z hiszpańskiego portalu BMW; nazwy i układ w Twoim kraju mogą się różnić. Interfejs na zegarku jest po angielsku.

**Widżet** Garmin, który pokazuje na zegarku bieżący stan Twojego BMW — zasięg, paliwo, zamknięcie, drzwi/okna, opony, przebieg i informacje serwisowe — prosto z oficjalnego API REST [BMW CarData](https://bmw-cardata.bmwgroup.com/customer/public/api-specification).

> Projekt hobbystyczny. Niepowiązany z BMW ani Garmin, nie jest przez nie wspierany ani zatwierdzony.

## Funkcje

- **Glance** — stan zamknięcia, zasięg i paliwo od razu w karuzeli widżetów.
- **Zasięg i paliwo** — pozostały zasięg, poziom paliwa w %, litry w zbiorniku / do pełna i opcjonalne szacowanie zużycia (`~L/100 km`). Elektryki i hybrydy plug-in: poziom baterii w % i zasięg elektryczny.
- **Zamknięcie** — SECURED / UNLOCKED, kropka przy każdych otwartych drzwiach (przednie + tylne), masce i bagażniku oraz czerwony znaczek **W**, gdy otwarte jest okno. Wyraźny wskaźnik wieku danych.
- **Licznik** — przebieg i dystans do następnego serwisu (z opcjonalną własną wartością).
- **Opony** — ciśnienie w każdym kole w porównaniu z wartością docelową oraz szacowane zużycie opon (START przełącza trzy widoki).
- **Lokalizacja auta** — zaparkowany samochód na wbudowanej mapie zegarka; START włącza lub wyłącza widok z zoomem, który można przesuwać. Tylko na urządzeniach z mapami (wszystkie obsługiwane poza Forerunner 255, 255 Music, 265 i 745).
- **About car** — pogrupowany, tylko do odczytu przegląd stałych danych pojazdu i telematyki na żywo (akumulator 12 V, płyn chłodzący, lokalizacja, Teleservice, …).
- **Ustawienia na zegarku** — tryb odświeżania, pojemność zbiornika, własna wartość następnego serwisu, szacowanie zużycia i podmenu **Manage** (ponowne parowanie / wylogowanie / usunięcie wszystkich kontenerów).

## Obsługiwane urządzenia

Zegarki Garmin fēnix, epix, Enduro, MARQ i Forerunner. Aktualna lista — oraz urządzenia, które nie są obsługiwane — jest w [angielskim README](../../README.md#supported-devices).

## Konfiguracja

Potrzebujesz **Client ID BMW CarData** (bezpłatnego, tworzonego w portalu BMW CarData) oraz konta My BMW w kraju, w którym dostępne jest CarData (UE / Wielka Brytania). Resztę robi widżet: zegarek sam wykrywa VIN i tworzy własne kontenery danych.

### 1. Utworzenie klienta BMW CarData

Jednorazowo, ok. 10 minut. Nazwy w portalu zależą od języka; tutaj podano hiszpańskie jako przykład — takie widać też na zrzutach ekranu.

1. Zaloguj się do **portalu internetowego My BMW** swojego kraju i otwórz przegląd pojazdu — np. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Otwórz **BMW CARDATA**.
3. W sekcji dostępu technicznego — *Technical access to BMW CarData* / ES *ACCESO TÉCNICO A BMW CARDATA* — **utwórz klienta** i skopiuj **Client ID**.
4. Włącz **oba** przełączniki: *CarData API access* (ES *Solicitar acceso a la API de CarData*) oraz *CarData streaming* (ES *Transmisión de CarData*). Przy logowaniu widżet prosi o oba uprawnienia naraz, więc oba muszą być włączone, mimo że używane jest tylko REST API.

   ![Portal BMW CarData (hiszpański): strona klienta z Client ID — tu zakrytym — i oboma włączonymi przełącznikami](../images/cardata-client.png)

5. W sekcji streamingu otwórz **wybór danych** (ES *Cambiar selección de datos*) i zaznacz pola danych z punktu 2. Zaznaczenie wszystkiego też działa — widżet nigdy nie prosi o nic spoza tej listy.

   ![Portal BMW CarData (hiszpański): karta streamingu ze statusem „ready" i przyciskiem „Cambiar selección de datos"](../images/cardata-streaming.png)

6. Zapisz i **poczekaj 5–10 minut**: świeżo utworzony klient nie działa od razu.

### 2. Wybór pól danych

To dokładnie **41 pól danych** „pełnego" kontenera widżetu. Lista (identyfikatory techniczne, takie same we wszystkich językach) znajduje się w angielskim README: [Select the data fields](../../README.md#2-select-the-data-fields).

![Portal BMW CarData (hiszpański): wybór danych pojazdu z zaznaczonymi 41 polami](../images/cardata-data-selection.png)

Wskazówka: włącz filtr pokazujący tylko wybrane atrybuty (ES *Mostrar solo atributos seleccionados*), aby sprawdzić swój wybór.

### 3. Parowanie zegarka

1. **Garmin Connect** → Twoje urządzenie → *Connect IQ Apps* → **BMW Status** → *Settings* → wklej **Client ID**. VIN i Container ID zostaw puste.
2. Otwórz widżet → **START to connect**. Pojawią się kod parowania i link.
3. Zatwierdź kod pod linkiem wyświetlonym na zegarku (BMW podaje go razem z kodem; awaryjnie `customer.bmwgroup.com/oneid/#/link`), na telefonie lub komputerze, logując się kontem BMW.
4. Zegarek wykrywa VIN, tworzy oba kontenery i pobiera dane Twojego auta. Nie trzeba wpisywać VIN-u ani kontenerów. Refresh token działa ok. 2 tygodnie i odnawia się przy każdym użyciu — widżet otwierany regularnie pozostaje sparowany.

### Odświeżanie

- **START** na stronie *Range & Fuel* lub *Lock* → natychmiastowe pełne odświeżenie (60 s przerwy między odświeżeniami). Na *Tyres* START przełącza widok rzeczywisty/docelowy/zużycie, na stronie mapy przełącza zoom, na *Odometer* nic nie robi.
- **Raz dziennie ok. 10:00** — pełne pobranie, także w trybie ręcznym; podtrzymuje też logowanie (tokeny).
- **Update Mode** (*Auto hourly* / *Auto adaptive*) jest tylko na urządzeniach z **API 6.0+** — fēnix 8, 8 Pro, 8 Solar, fēnix 9 (wszystkie warianty), fēnix E, Enduro 3 / 4, MARQ Gen 3, FR970. Pozostałe urządzenia działają ręcznie + raz dziennie, a to ustawienie jest ukryte.
- BMW dopuszcza **ok. 50 zapytań o dane na dobę**. Pełne odświeżenie zużywa 3, odpytanie w tle 1; odnowienie tokenu nie jest wliczane.
- Aktualność danych zależy od **samochodu**, nie od widżetu: zaparkowane BMW może wysyłać dane tylko co kilka godzin. Dlatego strony pokazują wiek danych.

### Rozwiązywanie problemów

| Komunikat / objaw | Przyczyna / rozwiązanie |
|---|---|
| `BMW Widget` / `Add Client ID in the Garmin Connect app` | W ustawieniach nie ma jeszcze Client ID — krok 3.1. Spacje na początku lub końcu wklejonej wartości są ignorowane. |
| `Auth failed` → `Client ID looks incomplete — copy it again…` | BMW odrzuciło parowanie, a zapisana wartość nie jest pełnym, 36-znakowym Client ID — zwykle wklejono tylko połowę. Skopiuj go ponownie z portalu. |
| `Phone link lost — retrying…` podczas parowania | Zegarek na chwilę stracił połączenie z Garmin Connect (częste, gdy zatwierdzasz na tym samym telefonie). Kod nadal jest ważny; dokończ zatwierdzanie — zegarek kontynuuje sam. |
| `No car on this BMW account` | Twoje BMW ID nie ma pojazdu albo nie jesteś jego **głównym** użytkownikiem. CarData obsługuje tylko głównego użytkownika. |
| `Car not readable — check VIN` | VIN w ustawieniach jest błędny albo auto nie jest już na tym koncie. Wyczyść pole VIN, aby widżet sam go wykrył. |
| `No car data yet` / `Check data selection in BMW portal` | Pobranie się udało, ale nie zwróciło niczego do wyświetlenia: nie zaznaczono pól danych (krok 1.5) albo auto od tego czasu nic nie przesłało. |
| Parowanie nie działa tuż po utworzeniu klienta | Aktywacja w portalu (5–10 min) jeszcze się nie zakończyła; spróbuj ponownie. |
| `Re-auth needed` / `Press START to re-pair` | Refresh token wygasł (widżet nieotwierany dłużej niż ok. 2 tygodnie) → **Manage → Re-pair**. |
| `Auth failed` → `Check CarData API + streaming are on in the BMW portal` | Jeden z dwóch przełączników klienta jest wyłączony w portalu (krok 1.4). Widżet prosi o oba uprawnienia jednym żądaniem, więc BMW odrzuca całe parowanie. Włącz go ponownie, poczekaj **5–10 min** i naciśnij START jeszcze raz. |
| Błąd kontenera / `CU-124` | BMW ogranicza konto do **10 kontenerów**. Konfiguracja proponuje usunięcie wszystkich i ponowną próbę; w przeciwnym razie **Manage → Delete containers** (widżet utworzy własne od nowa). |
| Brakuje strony lub wartości są puste | Twoje auto (albo wybór pól w CarData) nie przesyła tego pola — strony ukrywają się same, gdy brakuje ich kluczowych danych. |

## Prywatność

Widżet odczytuje dane Twojego pojazdu wyłącznie po to, by pokazać je na zegarku; nic nie jest wysyłane nigdzie poza własne API BMW — za tą aplikacją nie stoi żaden serwer, nie ma analityki ani zewnętrznych SDK. Pełna polityka (po angielsku): [`PRIVACY.md`](../../PRIVACY.md).
