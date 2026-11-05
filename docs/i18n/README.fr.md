# BMW Status — widget Garmin Connect IQ

[English](../../README.md) · [Deutsch](README.de.md) · **Français** · [Español](README.es.md) · [Nederlands](README.nl.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Svenska](README.sv.md) · [Suomi](README.fi.md) · [Ελληνικά](README.el.md)

> Traduction des parties du README destinées aux utilisateurs — en cas de doute, le [README en anglais](../../README.md) fait foi. La documentation de build, d'architecture et de tests n'existe qu'en anglais. Les captures d'écran proviennent du portail BMW espagnol ; les libellés et la mise en page dans votre pays peuvent différer. L'interface de la montre est en anglais.

Un **widget** Garmin qui affiche sur votre montre l'état en direct de votre BMW — autonomie, carburant, verrouillage, portières/vitres, pneus, compteur kilométrique et informations d'entretien — directement depuis l'API REST officielle [BMW CarData](https://bmw-cardata.bmwgroup.com/customer/public/api-specification).

> Projet personnel / de loisir. Sans lien avec BMW ou Garmin, ni approuvé ou pris en charge par eux.

## Fonctionnalités

- **Glance** — état du verrouillage, autonomie et carburant d'un coup d'œil dans le carrousel des widgets.
- **Autonomie et carburant** — autonomie restante, carburant en %, litres dans le réservoir / pour faire le plein et une estimation facultative de la consommation (`~L/100 km`). Électrique et hybride rechargeable : batterie en % et autonomie électrique.
- **Verrouillage** — SECURED / UNLOCKED, un point par portière ouverte (avant + arrière), capot et coffre, plus un badge rouge **W** pour toute vitre ouverte. Indicateur bien visible de l'ancienneté des données.
- **Compteur kilométrique** — kilométrage et distance jusqu'au prochain entretien (avec valeur personnalisée facultative).
- **Pneus** — pression de chaque roue par rapport à la valeur cible et estimation de l'usure (START fait défiler les trois vues).
- **Position du véhicule** — votre voiture garée sur la carte intégrée de la montre ; START active ou désactive une vue zoom explorable. Uniquement sur les appareils dotés de cartographie (tous les appareils pris en charge sauf Forerunner 255, 255 Music, 265 et 745).
- **About car** — vue groupée en lecture seule : données fixes du véhicule et télématique en direct (batterie 12 V, liquide de refroidissement, position, Teleservice, …).
- **Réglages sur la montre** — mode d'actualisation, capacité du réservoir, valeur d'entretien personnalisée, estimation de consommation et sous-menu **Manage** (réappairer / se déconnecter / supprimer tous les conteneurs).

## Appareils pris en charge

Montres Garmin fēnix, epix, Enduro, MARQ et Forerunner. La liste à jour — et les appareils non pris en charge — figurent dans le [README en anglais](../../README.md#supported-devices).

## Mise en service

Il vous faut un **Client ID BMW CarData** (gratuit, créé sur le portail BMW CarData) et un compte My BMW dans un pays où CarData est proposé (UE / Royaume-Uni). Tout le reste est automatique : la montre découvre votre VIN et crée elle-même ses conteneurs de données.

### 1. Créer un client BMW CarData

À faire une seule fois, environ 10 minutes. Les libellés du portail varient selon la langue ; ceux en espagnol servent d'exemple — ce sont aussi ceux des captures d'écran.

1. Connectez-vous au **portail web My BMW** de votre pays et ouvrez l'aperçu de votre véhicule — p. ex. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Ouvrez **BMW CARDATA**.
3. Dans la section d'accès technique — *Technical access to BMW CarData* / ES *ACCESO TÉCNICO A BMW CARDATA* — **créez un client** et copiez le **Client ID**.
4. Activez **les deux** interrupteurs : *CarData API access* (ES *Solicitar acceso a la API de CarData*) et *CarData streaming* (ES *Transmisión de CarData*). Le widget demande les deux autorisations ensemble lors de la connexion : les deux doivent donc être activés, même si seule l'API REST est utilisée.

   ![Portail BMW CarData (espagnol) : la page du client avec le Client ID — masqué ici — et les deux interrupteurs activés](../images/cardata-client.png)

5. Dans la section streaming, ouvrez la **sélection des données** (ES *Cambiar selección de datos*) et cochez les champs de la section 2. Tout sélectionner fonctionne aussi — le widget ne demande jamais rien en dehors de cette liste.

   ![Portail BMW CarData (espagnol) : la carte de streaming avec l'état « ready » et le bouton « Cambiar selección de datos »](../images/cardata-streaming.png)

6. Enregistrez et **attendez 5 à 10 minutes** : un client tout juste créé n'est pas utilisable immédiatement.

### 2. Sélectionner les champs de données

Ce sont exactement les **41 champs** du conteneur « complet » du widget. La liste (identifiants techniques, identiques dans toutes les langues) se trouve dans le README en anglais : [Select the data fields](../../README.md#2-select-the-data-fields).

![Portail BMW CarData (espagnol) : la sélection des données du véhicule avec les 41 champs cochés](../images/cardata-data-selection.png)

Astuce : activez le filtre qui n'affiche que les attributs sélectionnés (ES *Mostrar solo atributos seleccionados*) pour vérifier votre sélection.

### 3. Appairer la montre

1. **Garmin Connect** → votre appareil → *Connect IQ Apps* → **BMW Status** → *Settings* → collez le **Client ID**. Laissez VIN et Container ID vides.
2. Ouvrez le widget → **START to connect**. Un code d'appairage et un lien s'affichent.
3. Validez le code au lien indiqué par la montre (BMW le fournit avec le code ; à défaut `customer.bmwgroup.com/oneid/#/link`), sur un téléphone ou un ordinateur, en vous connectant avec votre compte BMW.
4. La montre découvre votre VIN, crée les deux conteneurs et récupère les données de votre voiture. Aucune saisie de VIN ni de conteneur. Le refresh token dure environ 2 semaines et est renouvelé à chaque utilisation — un widget ouvert régulièrement reste appairé.

### Actualisation

- **START** sur la page *Range & Fuel* ou *Lock* → actualisation complète immédiate (délai de 60 s entre deux actualisations). Sur *Tyres*, START fait défiler réel/cible/usure ; sur la page de la carte, il bascule le zoom ; sur *Odometer*, il ne fait rien.
- **Une fois par jour vers 10 h 00** — récupération complète, même en mode manuel ; elle maintient aussi la connexion (jetons) valide.
- **Update Mode** (*Auto hourly* / *Auto adaptive*) n'existe que sur les appareils **API 6.0+** — fēnix 8, 8 Pro, 8 Solar, fēnix 9 (toutes variantes), fēnix E, Enduro 3 / 4, MARQ Gen 3, FR970. Tous les autres appareils fonctionnent en manuel + quotidien, et le réglage y est masqué.
- BMW autorise **environ 50 appels de données par 24 h**. Une actualisation complète en consomme 3, une interrogation en arrière-plan 1 ; le renouvellement du jeton n'est pas compté.
- La fraîcheur dépend de la **voiture**, pas du widget : une BMW garée peut ne transmettre ses données qu'à quelques heures d'intervalle. Les pages affichent donc l'ancienneté des données.

### Dépannage

| Affichage / symptôme | Cause / solution |
|---|---|
| `BMW Widget` / `Add Client ID in the Garmin Connect app` | Aucun Client ID dans les réglages — étape 3.1. Les espaces en début ou fin de saisie sont ignorés. |
| `Auth failed` → `Client ID looks incomplete — copy it again…` | BMW a refusé l'appairage et la valeur enregistrée n'est pas un Client ID complet de 36 caractères — souvent un copier-coller partiel. Recopiez-le depuis le portail. |
| `Phone link lost — retrying…` pendant l'appairage | La montre a brièvement perdu Garmin Connect (fréquent quand vous validez sur le même téléphone). Le code reste valide ; terminez la validation — la montre reprend toute seule. |
| `No car on this BMW account` | Votre BMW ID n'a pas de véhicule, ou vous n'en êtes pas l'utilisateur **principal**. CarData ne sert que l'utilisateur principal. |
| `Car not readable — check VIN` | Le VIN saisi dans les réglages est erroné, ou la voiture n'est plus sur ce compte. Videz le champ VIN pour laisser le widget le découvrir. |
| `No car data yet` / `Check data selection in BMW portal` | La récupération a fonctionné mais n'a rien renvoyé d'affichable : aucun champ de données coché (étape 1.5), ou la voiture n'a rien transmis depuis. |
| L'appairage échoue juste après la création du client | L'activation de 5 à 10 min sur le portail n'est pas terminée ; réessayez. |
| `Re-auth needed` / `Press START to re-pair` | Le refresh token a expiré (widget non ouvert depuis plus de 2 semaines environ) → **Manage → Re-pair**. |
| `Auth failed` → `Check CarData API + streaming are on in the BMW portal` | L'un des deux interrupteurs de votre client est désactivé sur le portail (étape 1.4). Le widget demande les deux autorisations en une seule requête : BMW refuse donc tout l'appairage. Réactivez-le, attendez **5 à 10 min**, puis appuyez de nouveau sur START. |
| Erreur de conteneur / `CU-124` | BMW limite un compte à **10 conteneurs**. La mise en service propose de tous les supprimer et de réessayer ; sinon **Manage → Delete containers** (le widget recrée les siens). |
| Une page manque, ou des valeurs sont vides | Votre voiture (ou votre sélection CarData) ne transmet pas ce champ — les pages se masquent d'elles-mêmes quand leurs données principales manquent. |

## Confidentialité

Le widget lit les données de votre véhicule uniquement pour les afficher sur votre montre ; rien n'est envoyé ailleurs qu'à l'API de BMW — aucun serveur derrière cette application, aucune analyse, aucun SDK tiers. Politique complète (en anglais) : [`PRIVACY.md`](../../PRIVACY.md).
