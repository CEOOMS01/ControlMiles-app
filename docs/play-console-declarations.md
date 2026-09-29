# Google Play Console — permisos y Data safety (ControlMiles Android)

Preparado el 2026-09-29 a partir del código real de la app (AndroidManifest,
servicios y funciones del servidor). Los textos **en inglés** son para pegar en
Play Console (Google revisa en inglés); las notas **en español** son para ti.

> Si cambias lo que la app recoge o envía, este documento y el formulario de
> Data safety se actualizan juntos. Google compara el formulario con lo que la
> app hace de verdad.

---

## Parte A — Declaraciones de permisos

### A1. Ubicación en segundo plano (`ACCESS_BACKGROUND_LOCATION`) — OBLIGATORIO
Play Console → **Contenido de la app → Permisos sensibles → Permisos de ubicación**.

**Core feature that uses background location** (pegar):

> ControlMiles is a mileage log for gig and fleet drivers. Its core feature records each work trip's route and distance from GPS so the driver gets an accurate, audit-ready mileage log (IRS mileage deduction, fleet mileage and IFTA state miles). Trips last from minutes to hours while the driver uses navigation and gig apps, so ControlMiles must keep receiving location while it is in the background or the screen is off; otherwise the trip's miles would be missing. Location is only recorded during a trip the driver started (or confirmed from an automatic-detection prompt), a persistent notification is shown the whole time, and recording stops when the trip ends.

**Why the feature needs location in the background** (si lo pide por separado):

> During a trip the driver is using navigation and delivery apps, so ControlMiles is almost never in the foreground. Foreground-only location would lose the route and distance for most of every trip.

**Prominent disclosure** (ya está en la app, pantalla de permisos antes del aviso del sistema):

> ControlMiles collects location data to record your trips and calculate your mileage, even when the app is closed or not in use.

**Video** (Google pide un enlace, p. ej. YouTube "no listado"; 30–60 s basta). Guion:
1. Abrir la app recién instalada → pantalla de permisos con el texto de ubicación visible (2–3 s en pantalla).
2. Tocar Continuar → aparece el diálogo del sistema de ubicación → "Permitir todo el tiempo".
3. En Home, tocar **Start** → aparece la notificación persistente de viaje.
4. Salir a otra app (Maps o una app gig) con la notificación visible; volver: las millas han subido.
5. Tocar **End trip**.

### A2. Servicio en primer plano de ubicación (`FOREGROUND_SERVICE_LOCATION`) — OBLIGATORIO
Play Console → **Contenido de la app → Permisos de servicios en primer plano**. Tipo: **Location**.

**Task description** (pegar):

> While the driver has an active trip, a foreground service with a persistent notification keeps receiving GPS locations to record the trip's route and distance (mileage log). The service starts when the driver starts a trip and stops when the trip ends.

**Impact if the task were deferred or interrupted** (pegar):

> The trip's route and miles would be missing or wrong. A mileage log with gaps cannot be used for the IRS mileage deduction or for fleet mileage and IFTA reports.

**Video:** el mismo de A1.

### A3. Alarmas exactas (`SCHEDULE_EXACT_ALARM`) — si Play Console lo pregunta
> ControlMiles uses exact alarms only for time-critical trip reminders the driver sets up while tracking, for example the reminder that a paused trip is still open so mileage is not lost. The user can deny exact alarms; the app then falls back to inexact reminders.

### A4. Acceso de uso (`PACKAGE_USAGE_STATS`) — no tiene formulario propio, va en notas de revisión
⚠️ Es el permiso con más riesgo. Es opcional (función Premium) y se concede a mano en Ajustes. Pegar en **App access / notas para el revisor**:

> Usage access (PACKAGE_USAGE_STATS) is optional and only used by the Premium "Automatic gig-app detection" feature. It lets ControlMiles see which supported gig app (for example Uber, DoorDash, Instacart) is in the foreground so a trip can be started and tagged with the right app, as the in-app disclosure explains before the user is sent to Settings. ControlMiles only reads which of the supported gig apps is open; it does not read app content and does not upload the list of installed apps. The feature works without it (the driver picks the app manually).

La divulgación en la app ya existe (pantalla de permisos): *"Lets ControlMiles see which gig app you have open, so it can start your trip automatically."*

### A5. Excluir de optimización de batería (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) — notas de revisión
> ControlMiles asks (through the standard system dialog, which the user can decline) to be excluded from battery optimization because its core feature records trips in the background for hours; several manufacturers otherwise freeze the tracking service mid-trip and the mileage log gets gaps. It is requested only from the permissions screen and Settings, never forced.

### A6. Otros permisos (sin formulario)
- **Cámara:** foto del odómetro (evidencia de millas), recibos de combustible y fotos de defectos en inspecciones.
- **Reconocimiento de actividad:** detectar cuándo empieza y termina la conducción. Se procesa **solo en el teléfono** y no se envía.
- **Notificaciones:** viaje en curso, recordatorios y resumen semanal.

---

## Parte B — Formulario de Data safety
Play Console → **Contenido de la app → Seguridad de los datos**.

### Preguntas generales
| Pregunta | Respuesta |
|---|---|
| ¿Tu app recoge o comparte alguno de los tipos de datos requeridos? | **Sí** |
| ¿Todos los datos se cifran en tránsito? | **Sí** (HTTPS/TLS a Supabase y a todos los servicios) |
| ¿Ofreces una forma de pedir que se eliminen los datos? | **Sí**: en la app (Settings → Danger Zone → Delete Account) y en la web **https://controlmiles.com/delete-account** |
| ¿Revisión de seguridad independiente (MASA)? | No |

### Tipos de datos
"Recoger" = sale del teléfono hacia nuestros servidores. "Compartir" = se envía a un tercero.

| Categoría → tipo | ¿Recoge? | ¿Comparte? | ¿Obligatorio u opcional? | Finalidades | Notas |
|---|---|---|---|---|---|
| **Ubicación → Ubicación precisa** | Sí | No | Obligatorio | Funcionalidad de la app; Prevención de fraude, seguridad y cumplimiento | Ruta GPS de cada viaje, mapa en vivo de la flota, geocercas, eventos de seguridad |
| **Ubicación → Ubicación aproximada** | Sí | **Sí** | Obligatorio | Funcionalidad de la app | Coordenadas redondeadas a ~200 m que se envían a la API pública de OpenStreetMap (Overpass) para consultar el límite de velocidad. Sin nombre ni ID de usuario |
| **Información personal → Nombre** | Sí | No | Obligatorio | Funcionalidad de la app; Gestión de la cuenta | |
| **Información personal → Dirección de correo** | Sí | No | Obligatorio | Gestión de la cuenta; Comunicaciones del desarrollador | Inicio de sesión, restablecer contraseña, invitaciones de flota |
| **Información personal → IDs de usuario** | Sí | No | Obligatorio | Gestión de la cuenta; Funcionalidad de la app | ID de cuenta, ID de conductor CM-D |
| **Información financiera → Historial de compras** | Sí | No | Opcional | Gestión de la cuenta; Funcionalidad de la app | Suscripciones de Google Play (token, estado, vencimiento). Google procesa el pago; nosotros no vemos la tarjeta |
| **Información financiera → Otra información financiera** | Sí | No | Opcional | Funcionalidad de la app | Compras de combustible que registra el conductor de flota (galones, precio) |
| **Fotos y videos → Fotos** | Sí | No | Obligatorio | Funcionalidad de la app; Prevención de fraude, seguridad y cumplimiento | Odómetro (semanal, obligatorio), recibos, defectos de inspección |
| **Actividad en la app → Apps instaladas** | Sí | No | Opcional | Funcionalidad de la app | Solo qué app gig compatible se usó en cada viaje (función Premium) |
| **Actividad en la app → Otro contenido generado por el usuario** | Sí | No | Opcional | Funcionalidad de la app | Datos del vehículo (marca, modelo, placa, VIN), incidentes, inspecciones, mantenimiento, notas |
| **Info y rendimiento de la app → Registros de fallos** | Sí | No | Opcional | Funcionalidad de la app; Analítica | Mensaje y traza del error, a nuestro servicio de monitoreo |
| **Info y rendimiento de la app → Diagnóstico** | Sí | No | Opcional | Funcionalidad de la app | Contadores de calidad del GPS de cada viaje para el sellado antifraude |

**No se recoge:** contactos, mensajes, calendario, salud/fitness (el reconocimiento de actividad no sale del teléfono), audio, archivos, historial web ni IDs de publicidad. **No hay publicidad.**

### Servicios propios y proveedores (no cuentan como "compartir")
- **CGC Core** (sellado antifraude de viajes y monitoreo de errores) es un servicio **propio** del ecosistema del desarrollador (confirmado por el dueño el 2026-09-29). Por eso "Diagnóstico" y "Registros de fallos" se declaran **recogidos, no compartidos**.
- **Servidores (Supabase, Cloudflare R2 para mapas, Vercel):** son proveedores que procesan los datos por cuenta nuestra, así que tampoco cuentan como "compartir".
- **Único dato compartido con un tercero:** la ubicación aproximada que se manda a OpenStreetMap (Overpass) para consultar límites de velocidad.

---

## Parte C — Otras secciones de "Contenido de la app"
| Sección | Qué poner |
|---|---|
| Política de privacidad | https://controlmiles.com/privacy |
| Eliminación de cuenta | https://controlmiles.com/delete-account |
| Anuncios | No contiene anuncios |
| Público objetivo | **18+** (los términos exigen 18 años; la app lo confirma al registrarse) |
| Acceso a la app | Crea una **cuenta de revisor** (gig) con viajes de ejemplo y pon su correo y contraseña **solo en Play Console**. Añade también un ID de conductor de flota de prueba si quieres que revisen el modo flota |
| Clasificación de contenido | Cuestionario IARC: utilidad o productividad, sin violencia, sin contenido de usuarios compartido públicamente, **comparte la ubicación del usuario: Sí** (con el administrador de su flota) |
| App financiera | No es una app de servicios financieros (la deducción del IRS es solo una estimación informativa) |
