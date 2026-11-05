# BMW Status — widget de Garmin Connect IQ

[English](../../README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · **Español** · [Nederlands](README.nl.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Svenska](README.sv.md) · [Suomi](README.fi.md) · [Ελληνικά](README.el.md)

**[Ir a la configuración ↓](#configuración)**

> Traducción de las partes del README pensadas para usuarios — si hay dudas, manda el [README en inglés](../../README.md). La documentación de compilación, arquitectura y pruebas solo existe en inglés. Las capturas son del portal de BMW en español; los textos y la disposición en tu país pueden variar. La interfaz del reloj está en inglés.

Un **widget** de Garmin que muestra en tu reloj el estado en tiempo real de tu BMW — autonomía, combustible, cierre, puertas/ventanillas, neumáticos, cuentakilómetros e información de mantenimiento — directamente desde la API REST oficial de [BMW CarData](https://bmw-cardata.bmwgroup.com/customer/public/api-specification).

> Proyecto personal / de aficionado. Sin afiliación con BMW ni Garmin, ni respaldado o soportado por ellos.

## Funciones

- **Glance** — estado del cierre, autonomía y combustible de un vistazo en el carrusel de widgets.
- **Autonomía y combustible** — autonomía restante, % de combustible, litros en el depósito / para llenarlo y una estimación opcional del consumo (`~L/100 km`). Eléctricos e híbridos enchufables: % de batería y autonomía eléctrica.
- **Cierre** — SECURED / UNLOCKED, un punto por cada puerta abierta (delanteras + traseras), capó y maletero, además de una insignia roja **W** si hay alguna ventanilla abierta. Indicador bien visible de la antigüedad de los datos.
- **Cuentakilómetros** — kilometraje y distancia hasta el próximo mantenimiento (con valor propio opcional).
- **Neumáticos** — presión de cada rueda frente a la presión objetivo y estimación del desgaste (START recorre las tres vistas).
- **Ubicación del coche** — tu coche aparcado en el mapa integrado del reloj; START activa o desactiva una vista con zoom explorable. Solo en dispositivos con mapas (todos los compatibles salvo Forerunner 255, 255 Music, 265 y 745).
- **About car** — vista agrupada de solo lectura con los datos fijos del vehículo y la telemática en directo (batería de 12 V, refrigerante, ubicación, Teleservice, …).
- **Ajustes en el reloj** — modo de actualización, capacidad del depósito, valor propio para el mantenimiento, estimación de consumo y el submenú **Manage** (volver a vincular / cerrar sesión / borrar todos los contenedores).

## Dispositivos compatibles

Relojes Garmin fēnix, epix, Enduro, MARQ y Forerunner. La lista actualizada — y los dispositivos que no son compatibles — está en el [README en inglés](../../README.md#supported-devices).

## Configuración

Necesitas un **Client ID de BMW CarData** (gratuito, se crea en el portal BMW CarData) y una cuenta My BMW en un país donde se ofrezca CarData (UE / Reino Unido). Todo lo demás es automático: el reloj descubre tu VIN y crea él mismo sus contenedores de datos.

### 1. Crear un cliente de BMW CarData

Se hace una sola vez, unos 10 minutos. Los textos del portal cambian según el idioma; aquí se usan los españoles, que son también los de las capturas.

1. Inicia sesión en el **portal web My BMW** de tu país y abre el resumen de tu vehículo — p. ej. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Abre **BMW CARDATA**.
3. En la sección de acceso técnico — *ACCESO TÉCNICO A BMW CARDATA* — **crea un cliente** y copia el **ID de cliente** (Client ID).
4. Activa **los dos** interruptores: *Solicitar acceso a la API de CarData* y *Transmisión de CarData*. El widget pide ambos permisos juntos al iniciar sesión, así que los dos deben estar activados aunque solo se use la API REST.

   ![Portal BMW CarData (español): la página del cliente con el ID de cliente — tapado aquí — y los dos interruptores activados](../images/cardata-client.png)

5. En la sección de transmisión abre la **selección de datos** (*Cambiar selección de datos*) y marca los campos de datos del apartado 2. Seleccionarlo todo también funciona — el widget nunca pide nada fuera de esa lista.

   ![Portal BMW CarData (español): la tarjeta de transmisión con el estado «ready» y el botón «Cambiar selección de datos»](../images/cardata-streaming.png)

6. Guarda y **espera de 5 a 10 minutos**: un cliente recién creado no se puede usar al instante.

### 2. Seleccionar los campos de datos

Son exactamente los **41 campos** del contenedor «completo» del widget. La lista (identificadores técnicos, iguales en todos los idiomas) está en el README en inglés: [Select the data fields](../../README.md#2-select-the-data-fields).

![Portal BMW CarData (español): la selección de datos del vehículo con los 41 campos marcados](../images/cardata-data-selection.png)

Consejo: activa el filtro que muestra solo los atributos seleccionados (*Mostrar solo atributos seleccionados*) para comprobar tu selección.

### 3. Vincular el reloj

1. **Garmin Connect** → tu dispositivo → *Connect IQ Apps* → **BMW Status** → *Settings* → pega el **Client ID**. Deja VIN y Container ID vacíos.
2. Abre el widget → **START to connect**. Aparecen un código de vinculación y un enlace.
3. Aprueba el código en el enlace que muestra el reloj (BMW lo envía junto con el código; si no, `customer.bmwgroup.com/oneid/#/link`), desde el móvil o el ordenador, iniciando sesión con tu cuenta de BMW.
4. El reloj descubre tu VIN, crea los dos contenedores y descarga los datos de tu coche. No hay que escribir VIN ni contenedores. El refresh token dura unas 2 semanas y se renueva en cada uso — un widget que abres con regularidad sigue vinculado.

### Actualización

- **START** en la página *Range & Fuel* o *Lock* → actualización completa inmediata (60 s de espera entre actualizaciones). En *Tyres*, START alterna real/objetivo/desgaste; en la página del mapa activa o desactiva el zoom; en *Odometer* no hace nada.
- **Una vez al día, hacia las 10:00** — descarga completa incluso en modo manual; además mantiene vivo el inicio de sesión (tokens).
- **Update Mode** (*Auto hourly* / *Auto adaptive*) solo existe en dispositivos con **API 6.0+** — fēnix 8, 8 Pro, 8 Solar, fēnix 9 (todas las variantes), fēnix E, Enduro 3 / 4, MARQ Gen 3, FR970. El resto funciona en modo manual + diario, y el ajuste está oculto.
- BMW permite **unas 50 consultas de datos cada 24 h**. Una actualización completa gasta 3, una consulta en segundo plano 1; la renovación del token no cuenta.
- La frescura depende del **coche**, no del widget: un BMW aparcado puede enviar datos solo cada pocas horas. Por eso las páginas muestran la antigüedad de los datos.

### Solución de problemas

| Pantalla / síntoma | Causa / solución |
|---|---|
| `BMW Widget` / `Add Client ID in the Garmin Connect app` | Aún no hay Client ID en los ajustes — paso 3.1. Los espacios al principio o al final al pegar se ignoran. |
| `Auth failed` → `Client ID looks incomplete — copy it again…` | BMW rechazó la vinculación y el valor guardado no es un Client ID completo de 36 caracteres — normalmente se pegó solo la mitad. Cópialo de nuevo desde el portal. |
| `Phone link lost — retrying…` al vincular | El reloj perdió un momento la conexión con Garmin Connect (es habitual si apruebas desde el mismo móvil). El código sigue siendo válido; termina de aprobarlo y el reloj continúa solo. |
| `No car on this BMW account` | Tu BMW ID no tiene ningún vehículo, o no eres su usuario **principal**. CarData solo atiende al usuario principal. |
| `Car not readable — check VIN` | El VIN de los ajustes es incorrecto o el coche ya no está en esta cuenta. Vacía el campo VIN para que el widget lo descubra. |
| `No car data yet` / `Check data selection in BMW portal` | La descarga funcionó pero no devolvió nada que mostrar: no hay campos de datos marcados (paso 1.5) o el coche no ha enviado nada desde entonces. |
| La vinculación falla justo después de crear el cliente | La activación de 5–10 min en el portal aún no ha terminado; vuelve a intentarlo. |
| `Re-auth needed` / `Press START to re-pair` | El refresh token ha caducado (widget sin abrir más de ~2 semanas) → **Manage → Re-pair**. |
| `Auth failed` → `Check CarData API + streaming are on in the BMW portal` | Uno de los dos interruptores de tu cliente está desactivado en el portal (paso 1.4). El widget pide ambos permisos en una sola solicitud, así que BMW rechaza toda la vinculación. Actívalo de nuevo, espera **5–10 min** y pulsa START otra vez. |
| Error de contenedor / `CU-124` | BMW limita cada cuenta a **10 contenedores**. La configuración ofrece borrarlos todos y reintentar; si no, **Manage → Delete containers** (el widget vuelve a crear los suyos). |
| Falta una página o hay valores vacíos | Tu coche (o tu selección de CarData) no envía ese campo — las páginas se ocultan solas cuando faltan sus datos principales. |

## Privacidad

El widget lee los datos de tu vehículo solo para mostrarlos en tu reloj; no se envía nada a ningún sitio salvo a la propia API de BMW — no hay ningún servidor detrás de esta app, ni analítica, ni SDK de terceros. Política completa (en inglés): [`PRIVACY.md`](../../PRIVACY.md).
