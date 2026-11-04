# Plan de capacitación gamificada

Última revisión: 2026-10-30

## Estado y alcance

Esta iteración continúa la capacitación, Brotecita y el minijuego virtual **Riego perfecto**. No reemplaza esos componentes. No se ejecutó SQL, no se modificó Neon, no se publicó contenido ni se desplegó el backend.

| Fase | Estado | Resultado |
| --- | --- | --- |
| A. Auditoría/consolidación | Completada | Se conservan las seis actividades publicadas, sus identificadores y el progreso. La disponibilidad lineal la confirma el backend. |
| B. Ruta visual | Completada en Flutter; requiere backend actualizado | La ruta muestra bloqueado, disponible, en progreso y completado a partir del progreso real. El cliente no desbloquea actividades localmente. |
| C. Introducción educativa | Completada usando contenido publicado | Antes del reto se consulta la versión publicada de la lección y se muestran objetivo, secciones y fuentes disponibles. No se generó ni alteró contenido editorial. |
| D. Minijuegos adicionales | Parcial, en vista previa local | Se añadieron Sol o sombra, Detective de plantas y Jardín inteligente virtual. D4, Ordena el cuidado, reutiliza la actividad publicada existente. Riego perfecto sigue como vista previa. |
| E. Resultados/recompensas | Completada para desafíos persistidos | XP y finalización vienen del backend. Se distingue XP nuevo de acierto repetido. Las estrellas no representan recompensas nuevas. |
| F. Pulido y accesibilidad | Parcial/comprobado | Se conserva tema y Brotecita, límites de ancho y controles existentes. El progreso desconocido ahora usa un estado visual neutro. Falta revisión manual en Android físico y con lector de pantalla. |
| G. Persistencia | Sin cambios de esquema | La ruta añade `disponible` al JSON. No se insertaron actividades ni se alteraron versiones. La migración de Riego perfecto sigue preparada y sin aplicar. |
| H. Calidad | Completada con avisos pendientes | 57 pruebas Flutter y 46 pruebas backend pasan; Web compila. El análisis no reporta errores, pero sí 4 warnings existentes en Dashboard y 58 avisos informativos. |
| I. Documentación | Completada | Este plan y `reporte-desarrollo-nocturno.md`. |

## Arquitectura final y decisiones

- El backend construye `disponible` por usuario en `GET /api/capacitacion/rutas/:idRuta`: es `true` solo para la primera actividad no completada cuyo prefijo ya está completado. Una actividad con intentos pero sin completar permanece como la actividad en progreso.
- Flutter interpreta la propiedad como nullable. Si un servidor anterior no la envía, la app falla de forma segura: muestra progreso/disponibilidad como no disponible y no permite iniciar un reto. Conviene desplegar el backend antes de actualizar Flutter.
- El parser solo acepta un booleano real para `disponible`; ausente, `null` o un tipo inesperado quedan como desconocidos y no se convierten en `false` ni en desbloqueo.
- Tras calificar una respuesta, Flutter vuelve a consultar la ruta. El resultado y el avance se apoyan en información confirmada por el servidor, no en XP calculado localmente.
- La introducción consulta `GET /api/capacitacion/lecciones/:idLeccion` y la ruta. Usa objetivo, secciones y fuentes de la versión publicada. Secciones largas permanecen plegables; no se vuelve a generar contenido con IA.
- Las prácticas nuevas son widgets locales sin llamadas HTTP, autenticación, persistencia, XP ni progreso. “Jardín inteligente” usa sectores virtuales A–D con pistas cualitativas, aisladas del ESP32. Las decisiones no son umbrales ni recomendaciones universales.
- Si el progreso de Brotecita es desconocido, muestra un emblema neutro con interrogación, en vez de dibujar la etapa semilla como si el progreso real fuera cero.
- Ordena el cuidado se conserva en el renderer publicado de ordenar pasos. Riego perfecto permanece en la pantalla de vista previa existente y no forma parte del progreso persistido.

## Archivos de esta iteración

- `Backend/src/services/capacitacion.service.js`: agrega `disponible` al resultado de ruta.
- `Backend/test/capacitacion.test.js`: regresión del desbloqueo lineal.
- `Backend/migrations/propuestas/2026_propuesta_capacitacion_minijuegos.sql`: conserva `simulacion_riego` al reemplazar la restricción de tipos.
- `systema_riego_app/lib/services/capacitacion_service.dart`: parseo seguro nullable de disponibilidad.
- `systema_riego_app/lib/widgets/capacitacion/brotecita_widget.dart`: estado visual neutro para progreso desconocido.
- `systema_riego_app/lib/pages/aprender_jardineria_page.dart`: ruta, disponibilidad, introducción de lección y entrada a prácticas.
- `systema_riego_app/lib/pages/retos_practica_page.dart`: catálogo y tres minijuegos locales de vista previa.
- `systema_riego_app/test/capacitacion_page_test.dart`, `systema_riego_app/test/brotecita_integration_test.dart`, `systema_riego_app/test/brotecita_widget_test.dart`, `systema_riego_app/test/riego_perfecto_test.dart`: fixtures y pruebas de ruta/introducción y estado sin progreso.
- `systema_riego_app/test/retos_practica_test.dart`: prácticas y su estado no persistente.

El árbol ya contenía cambios sin commit antes de esta iteración en módulos
ajenos al alcance, además de Brotecita, Riego perfecto, configuración API y
propuestas de migración. No se revirtieron ni se atribuyen a este trabajo.
Revisar `git status` antes de preparar cualquier commit.

## Contratos y migraciones

No cambian endpoints, JWT, `Idempotency-Key`, respuestas correctas, XP ni
identificadores. Se agrega solo `disponible` (boolean) al objeto de actividad
que devuelve `GET /api/capacitacion/rutas/:idRuta`.

El esquema PostgreSQL no se modificó. Permanecen como propuestas, no ejecutadas:

- `Backend/migrations/2026_add_simulacion_riego.sql`: columna de configuración y restricción de tipos para habilitar `simulacion_riego`; requiere revisión y aplicación manual antes de persistir Riego perfecto.
- `Backend/migrations/propuestas/2026_propuesta_capacitacion_minijuegos.sql`: propuesta general para futuros tipos. No es requisito de las prácticas locales.

La propuesta genérica ahora incluye `simulacion_riego`; sin ese tipo, podía
reemplazar la restricción y bloquear futuras filas Riego perfecto al validarla.
La reversión `2026_add_capacitacion_gamificada.down.sql` elimina tablas de ruta,
intentos y progreso; no debe ejecutarse si esos datos deben conservarse.

No se publicaron juegos nuevos en la ruta. Sol o sombra, Detective y Jardín
inteligente deben seguir rotulados **“Vista previa · Sin XP ni progreso”**
hasta diseñar evaluación server-side, contratos, pruebas de autorización e
idempotencia, una migración revisada y publicación autorizada.

## Pendientes y riesgos

1. Desplegar el backend con `disponible` antes de distribuir Flutter; una API vieja deja la ruta bloqueada intencionalmente.
2. Validar en un teléfono Android pequeño y con lector de pantalla; compilar Web no sustituye esa revisión física.
3. Revisar editorialmente el contenido y sus fuentes antes de publicar contenido nuevo. Este cambio no modifica contenido publicado.
4. Para convertir las prácticas en actividades persistentes hacen falta evaluación/calificación server-side, pruebas de autorización e idempotencia y migración aditiva revisada. No se hizo aquí.
5. No se probó contra Neon, Render ni hardware físico.

## Validación manual

1. Actualizar/desplegar primero el backend en un entorno autorizado.
2. Abrir Asistente → Aprender jardinería con una cuenta autenticada.
3. Comprobar que el progreso y el primer reto disponible coincidan con el servidor.
4. Con una API anterior sin `disponible`, confirmar que Flutter informa disponibilidad no confirmada y no inicia el reto.
5. Abrir la introducción y revisar objetivo, secciones y fuentes de la versión publicada. Iniciar un desafío y comprobar que el resultado actualiza ruta/XP desde backend.
6. Abrir Retos de práctica; probar Sol o sombra, Detective y los cuatro sectores virtuales. Confirmar que no se agrega XP ni progreso.
7. Repetir Riego perfecto en vista previa; confirmar que no invoca actuadores.

## Comandos de validación local (PowerShell)

Desde `systema_riego_app`, si `flutter.bat` queda bloqueado, el Dart incluido
en `C:\flutter` permitió lanzar Flutter directamente:

```powershell
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
$env:TEMP=(Resolve-Path '.dart_tool').Path
$env:TMP=$env:TEMP
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' `
  'C:\flutter\bin\cache\flutter_tools.snapshot' --suppress-analytics `
  test --no-pub --concurrency=1 --reporter=expanded
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' `
  'C:\flutter\bin\cache\flutter_tools.snapshot' --suppress-analytics `
  analyze --no-pub
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' `
  'C:\flutter\bin\cache\flutter_tools.snapshot' --suppress-analytics `
  build web --no-pub
```

Desde `Backend`: `npm test`.
