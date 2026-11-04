# Estado final del módulo de capacitación gamificada

## Alcance implementado

La ruta publicada conserva sus seis actividades, sus identificadores, intentos,
progreso y XP. La calificación continúa siendo responsabilidad del backend:
Flutter solo envía la respuesta y espera la confirmación del servidor. Los
reintentos usan la misma `Idempotency-Key` y el mismo cuerpo, y un acierto no
vuelve a otorgar XP.

Se añadieron cuatro experiencias visuales:

- **Riego perfecto** (`simulacion_riego`): simulación determinista de dosis y
  humedad; no consulta sensores ni actuadores.
- **Sol o sombra** (`minijuego_luz`): decisión visual con arrastre o toque.
- **Detective de plantas** (`diagnostico_interactivo`): pistas examinables y
  una decisión basada en evidencia.
- **Jardín inteligente** (`simulacion_jardin`): decisiones virtuales para los
  sectores A–D.

La vista local de demostración usa IDs negativos, XP cero y no llama a la red.
Por diseño no modifica el progreso real. La ruta real usa los endpoints y
contratos ya existentes.

## Arquitectura y contratos

Los renderizadores están registrados en
`systema_riego_app/lib/widgets/capacitacion/actividad_renderer.dart` y cada
minijuego tiene su widget independiente. El servicio de capacitación conserva
JWT, `Idempotency-Key` y el POST de respuestas. Las configuraciones versionadas
son:

```json
{"version":1,"acciones":[{"tipo":"regar","agua":15}]}
{"version":1,"seleccion":"indirecta"}
{"version":1,"accion":"observar"}
{"version":1,"decisiones":[{"sector":"A","accion":"regar"}]}
```

El backend calcula el resultado; nunca se aceptan desde Flutter los campos
`correcto`, `ganado` o `xp` como autoridad. `BrotecitaWidget` calcula su etapa
solo a partir del progreso entregado por la API. Cuando el progreso no está
disponible, permanece en estado de descanso y no muestra una recompensa.

## Demo local

Desde `systema_riego_app`:

```powershell
& "C:\flutter\bin\flutter.bat" run -d chrome -t lib/main_capacitacion_demo.dart
```

También se puede abrir la aplicación normal y pulsar **DEMO · Recorrido sin
conexión** dentro de Aprender jardinería. La etiqueta indica explícitamente
que no hay XP ni persistencia.

## Persistencia y publicación

No se ejecutaron SQL, seeds, despliegues ni cambios en Neon. Para publicar los
minijuegos reales hay que revisar y aplicar manualmente, en una rama de
pruebas, `2026_add_capacitacion_minijuegos_extensibles.sql` y después el seed
correspondiente. La migración es aditiva y no reemplaza la función ni los
triggers de inmutabilidad. La ruta publicada original no se modifica; cualquier
publicación debe hacerse sobre una nueva ruta/versionado y verificarse antes de
promoverla.

La migración valida la FK de `id_ruta_previa` mediante `pg_constraint` (OID,
columnas y acción `RESTRICT`), sin comparar `pg_get_constraintdef()` con un
nombre de esquema fijo. Así evita falsos conflictos según `search_path`. El
seed evita además la ambigüedad entre `r.id_ruta_previa` y la variable PL/pgSQL
al repetirse.

Antes y después de publicar deben comprobarse: seis actividades originales sin
cambios, cuatro actividades nuevas con su configuración, intentos/progreso/XP
sin diferencias, y que la ruta sucesora permanezca bloqueada hasta completar la
anterior. Para revertir, retirar la ruta nueva; no borrar actividades, intentos
ni progreso.

## Validación

Se ejecutaron pruebas Flutter focalizadas de capacitación y Brotecita (22
aprobadas) y la suite backend existente (56 aprobadas en la última ejecución).
La compatibilidad del servicio se comprobó en PostgreSQL 18 local con esquema
anterior y extendido: seis actividades y 65 XP permanecen intactos, la
idempotencia y el desbloqueo lineal funcionan, y se rechazan respuestas
manipuladas.

`flutter analyze --no-pub` no reporta errores de compilación; quedan avisos
preexistentes del Dashboard (casts/assertions innecesarios y una variable no
usada), además de informativos del linter. No se corrigieron porque están fuera
del alcance.
