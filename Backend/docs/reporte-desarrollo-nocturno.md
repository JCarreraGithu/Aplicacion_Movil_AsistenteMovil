# Reporte de desarrollo nocturno — capacitación gamificada

Fecha: 2026-10-30

## Resultado

Se completó una iteración local de la experiencia gamificada sin reemplazar la
ruta, las seis actividades publicadas, Brotecita ni Riego perfecto. La ruta de
aprendizaje obtiene la disponibilidad del backend, presenta la lección
publicada antes de iniciar un desafío y ofrece tres prácticas nuevas en modo
vista previa.

## Cambios principales

1. `GET /api/capacitacion/rutas/:idRuta` ahora incluye `disponible` por actividad. Solo se marca disponible el primer desafío no completado, después de completar el prefijo anterior.
2. Flutter analiza `disponible` como nullable y bloquea de forma segura si la API no confirma disponibilidad. Después de un intento correcto recarga el estado desde el backend.
3. La introducción consulta la lección publicada, con su objetivo, secciones y fuentes existentes.
4. Se añadieron prácticas locales Sol o sombra, Detective de plantas y Jardín inteligente (sectores virtuales A–D). Tienen retroalimentación local claramente rotulada como vista previa sin XP/progreso; no usan servicios ni endpoints de riego.
5. Ordena el cuidado permanece en la actividad publicada existente. Riego perfecto continúa en su vista previa previa.
6. Se añadieron pruebas de la regla de disponibilidad, del modo seguro cuando falta el campo y de las prácticas locales.
7. La auditoría de integración endureció el parseo de `disponible` (solo acepta booleano), dio a Brotecita una representación neutra cuando no hay progreso confirmado y añadió `simulacion_riego` a la lista de tipos de la propuesta de migración genérica.

## Archivos de esta iteración

- Backend: `src/services/capacitacion.service.js`, `test/capacitacion.test.js`.
- Flutter: `lib/services/capacitacion_service.dart`, `lib/pages/aprender_jardineria_page.dart`, nuevo `lib/pages/retos_practica_page.dart`.
- Pruebas Flutter: `test/capacitacion_page_test.dart`, `test/brotecita_integration_test.dart`, `test/riego_perfecto_test.dart`, nuevo `test/retos_practica_test.dart`.
- Documentación: `docs/plan-capacitacion-gamificada.md`, este reporte.

El repositorio ya tenía cambios no relacionados sin commit cuando comenzó la
tarea. El árbol de trabajo completo incluye archivos previos de otros módulos,
Brotecita y Riego perfecto; se dejaron intactos. No se hizo commit.

## Validaciones ejecutadas

- Backend, desde `Backend`: `npm test` — **46/46 pruebas aprobadas**.
- Flutter, SDK instalado en `C:\flutter`: `flutter test --no-pub` — **57 pruebas aprobadas**, incluida la navegación de prácticas en viewport 320×568. Tras habilitar acceso local al socket del test runner, Flutter terminó con código 0.
- Flutter: `flutter analyze --no-pub` — reportó **0 errores**, 4 warnings en `lib/pages/dashboard_page.dart` (archivo fuera del alcance de esta tarea) y 58 avisos informativos. El proceso nativo de Flutter terminó anormalmente después de imprimir el informe completo; no se corrigieron avisos ajenos al alcance.
- Flutter Web: `flutter build web --no-pub` — compilación exitosa. Flutter mostró el aviso informativo habitual de la prueba preliminar WASM y el tree-shaking de fuentes.
- `git diff --check` — sin errores de whitespace; Git reportó avisos de conversión LF/CRLF en archivos modificados.
- La vista previa `retos_practica_page.dart` no importa servicios de capacitación, sensores, dispositivos ni actuadores.

## Pendientes y límites

- El campo `disponible` requiere desplegar el backend antes de distribuir la versión Flutter. No se desplegó Render.
- Los tres juegos nuevos son demostraciones locales: no guardan resultados ni XP. La evaluación persistente requerirá contratos de actividad, validador backend, idempotencia, migración revisada y publicación futura.
- `Backend/migrations/2026_add_simulacion_riego.sql` y `Backend/migrations/propuestas/2026_propuesta_capacitacion_minijuegos.sql` siguen sin ejecutar. La propuesta genérica omitía `simulacion_riego` al reemplazar la restricción de tipo; se corrigió localmente y se añadió una prueba estática. No se conectó Neon.
- `2026_add_capacitacion_gamificada.down.sql` elimina las tablas de intentos y progreso; no usarlo para revertir si esos datos deben conservarse.
- No se publicó ni alteró contenido educativo. No se ejecutó SQL ni se modificaron datos.
- No se verificó en hardware Android, ESP32 o bombas; no hubo llamadas físicas.
- La interfaz no fue revisada manualmente con lector de pantalla ni con pruebas de movimiento reducido en un dispositivo real.

## Verificación manual sugerida

1. Desplegar primero el backend actualizado en un entorno autorizado.
2. Desde Flutter Web o Android, iniciar sesión y abrir Asistente → Aprender jardinería.
3. Confirmar estado y disponibilidad de cada nodo; completar el siguiente desafío y verificar que el avance venga actualizado desde backend.
4. Revisar la introducción de la lección y sus fuentes; empezar el desafío y revisar el resultado/XP.
5. Abrir Retos de práctica y completar cada juego. Debe indicarse en todo momento que no otorga XP ni persiste progreso.
6. Cerrar/reabrir el módulo y confirmar que solo los desafíos reales conservan progreso.

## Pasos para publicación futura (no ejecutados)

1. Revisar esta documentación y el diff completo, separando los cambios previos no relacionados.
2. Desplegar el backend que añade `disponible`; verificar respuesta de ruta con cuentas que tengan cero, parcial y todo el progreso.
3. Aprobar por separado la migración de `simulacion_riego` antes de almacenar Riego perfecto como actividad.
4. Diseñar y revisar contenido/calificadores server-side para nuevos juegos antes de insertarlos o publicarlos.
5. Solo tras autorización explícita, aplicar migración/publicar contenido y preparar despliegue Flutter. En esta sesión no se realizó ninguno de esos pasos.
