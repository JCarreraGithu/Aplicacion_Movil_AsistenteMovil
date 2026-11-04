# Riego perfecto — contrato y habilitación manual

Implementación virtual `simulacion_riego`, versión de contrato 1. No utiliza
sensores, comandos, bombas ni dispositivos. Los valores siguientes son reglas
de un juego discreto; no son porcentajes medidos ni umbrales para plantas reales.

## Configuración guardada en la actividad

```json
{
  "version": 1,
  "humedad_inicial": 20,
  "objetivo_min": 45,
  "objetivo_max": 65,
  "incremento_por_unidad": 2,
  "agua_max_por_accion": 15,
  "agua_max_total": 40,
  "max_acciones": 8
}
```

Se almacena en `capacitacion_actividad.configuracion`. Todos los números deben
ser enteros. Humedad y objetivo están entre 0 y 100, el inicio debe estar por
debajo del objetivo, incremento entre 1 y 10, dosis y presupuesto entre 1 y 100,
y acciones entre 1 y 20. El objetivo debe ser alcanzable. Un contrato nuevo debe
usar otra versión y un manejador compatible, sin reinterpretar intentos v1.

La respuesta HTTP de rutas incorpora `configuracion` como un campo aditivo.
Se obtiene con `to_jsonb(a)->'configuracion'` para mantener las seis actividades
operativas incluso antes de aplicar la migración (no existe aún esa columna).

## Envío y calificación

Se conserva `POST /api/capacitacion/rutas/:idRuta/actividades/:idActividad/respuestas`,
JWT y `Idempotency-Key`:

```json
{
  "respuesta": {
    "version": 1,
    "acciones": [
      {"tipo": "regar", "agua": 5},
      {"tipo": "regar", "agua": 10}
    ]
  }
}
```

Solo se admiten esas claves. No se admiten humedad final, configuración,
`correcto`, dosis negativas, decimales ni acciones de hardware. El servidor
valida cada dosis y el presupuesto y reproduce la secuencia:

`humedad = min(100, humedad_anterior + agua × incremento_por_unidad)`.

Se acierta si la humedad recalculada está entre ambos límites, incluidos. La
secuencia vacía es válida y se califica como insuficiente. Un exceso no se
deshace: reiniciar inicia otro historial desde la humedad inicial. Esta fase no
simula evaporación, drenaje ni fisiología real. No se verifica que un humano
haya tocado realmente la pantalla; sí que la secuencia sea válida bajo reglas
del servidor y que nadie acumule XP repetido por la misma actividad.

Se preservan los campos de respuesta anteriores y se añade, solo para este tipo:

```json
{
  "resultado_simulacion": {
    "version": 1,
    "humedad_final": 50,
    "agua_total": 15,
    "estado": "adecuada"
  }
}
```

`explicacion` incluye retroalimentación determinista y la explicación editorial
guardada. `respuesta_correcta` continúa siendo obligatorio en el esquema; para
este tipo se propone el descriptor `{"version":1,"criterio":"humedad_objetivo"}`.
El calificador usa la configuración del servidor, no compara ese descriptor con
un supuesto resultado enviado por Flutter. El XP proviene de la actividad y se
otorga solo al primer acierto; reintentos de red conservan la misma clave/cuerpo.

## Vista previa disponible ahora

Asistente → Aprender jardinería → «Riego perfecto · Vista previa».
Funciona aunque no existan rutas publicadas o no cargue el catálogo. Es un
escenario local explícito, sin registro de intentos, progreso ni XP. Permite
variar dosis, regar, observar humedad/animaciones y reiniciar.

## Habilitar persistencia posteriormente (no realizado)

1. Revisar `migrations/2026_add_simulacion_riego.sql`, estructura y restricciones
   reales, permisos del propietario y respaldo. Aplicar manualmente solo con
   autorización. El script es transaccional e idempotente para los nombres de
   restricción documentados; no inserta ni publica contenido.
2. Revisar editorialmente el escenario, su explicación y las fuentes existentes
   de fundamentos del riego. Mantener visible que son unidades virtuales.
3. Crear una lección/version y ruta **nuevas en borrador** dentro del módulo, por
   ejemplo una práctica «Riego perfecto». Crear en esa ruta una actividad nueva
   con tipo `simulacion_riego`, configuración v1, `opciones: []`, descriptor
   anterior y XP explícitamente revisado. No mover ni modificar las seis filas
   existentes. No se suministra un seed que inserte contenido automáticamente.
4. La ruta publicada actual es inmutable y hay una ruta por versión de lección:
   no se puede agregar un séptimo paso a esa misma ruta sin rediseñar el
   versionado. La alternativa anterior mantiene accesibles sus seis actividades
   y progreso. El desbloqueo existente es lineal dentro de cada ruta; no se añade
   un prerrequisito entre rutas.
5. Validar en PostgreSQL de pruebas: dos usuarios, actividad incorrecta/correcta,
   repetir clave, cambiar cuerpo con misma clave (409), volver a acertar con
   nueva clave (0 XP adicional), bloquear un paso posterior, volver a entrar y
   comprobar continuidad. Verificar 0 cambios en los seis registros anteriores.
6. Revisar y autorizar publicación manual de la versión y de la ruta. El catálogo
   existente las mostrará. No se publica nada desde Flutter ni desde esta tarea.

No hay rollback que borre datos. Para revertir la habilitación de esquema se
debería verificar primero que no haya actividades de los nuevos tipos y preparar
la restricción anterior. Conservar la columna JSON evita perder configuraciones.

## Pruebas locales

```powershell
Set-Location 'C:\Users\testr\Desktop\PROYECTOS\SISTEMA_RIEGO\Backend'
npm test
Set-Location '..\systema_riego_app'
& 'C:\flutter\bin\flutter.bat' test --no-pub
& 'C:\flutter\bin\flutter.bat' analyze --no-pub
& 'C:\flutter\bin\flutter.bat' run -d chrome
```

En Android, conectar un dispositivo con depuración USB, consultar `flutter devices`
y ejecutar `flutter run -d <id>` con el mismo SDK. Esta prueba en modo debug no
genera una APK de distribución. Para la vista previa no hace falta configurar
datos nuevos; para probar persistencia se requiere contenido autorizado en pruebas.

## Archivos de esta fase

- `Backend/src/services/capacitacion/simulacion-riego.js`: validación y reproducción de acciones.
- `Backend/src/services/capacitacion/actividad-calificadores.js`: registro del calificador.
- `Backend/src/services/capacitacion.service.js`: configuración compatible y resultado calculado.
- `Backend/test/simulacion-riego.test.js` y `Backend/test/capacitacion.test.js`: límites, manipulación, aislamiento, idempotencia y regresión.
- `Backend/migrations/2026_add_simulacion_riego.sql`: propuesta de habilitación sin contenido.
- `systema_riego_app/lib/models/simulacion_riego.dart`: contrato visual v1.
- `systema_riego_app/lib/widgets/capacitacion/riego_perfecto_widget.dart`: juego independiente.
- `systema_riego_app/lib/widgets/capacitacion/actividad_renderer.dart`: registro e inicialización de respuestas.
- `systema_riego_app/lib/pages/riego_perfecto_preview_page.dart`: vista previa sin servicios HTTP.
- `systema_riego_app/lib/pages/aprender_jardineria_page.dart`: acceso y confirmación del servidor.
- `systema_riego_app/lib/services/capacitacion_service.dart`: campos opcionales de configuración/resultado.
- `systema_riego_app/test/riego_perfecto_test.dart`: widget móvil, registro, vista previa, envío y reintentos.

La suite prueba UI y servicios con HTTP/BD simulados y reglas puras con `node:test`.
No sustituye la verificación con PostgreSQL de pruebas descrita arriba. En esta
fase no se ejecutó SQL ni se verificó el juego en un Android físico.
