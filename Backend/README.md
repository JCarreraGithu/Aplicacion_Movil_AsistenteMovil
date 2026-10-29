# Backend

## Integración ESP32

El ESP32 decide el riego autónomamente. La API registra telemetría, publica solicitudes manuales de la app como comandos con vencimiento y recoge sus confirmaciones. El ESP32 debe ignorar cualquier comando cuyo plazo haya expirado y continuar el riego local sin depender de la conexión.

### Variables de entorno

Las variables nuevas están declaradas vacías en `.env.example`; si se omiten o quedan vacías, la API usa estos valores predeterminados:

| Variable | Predeterminado | Uso |
| --- | ---: | --- |
| `DISPOSITIVO_ONLINE_SEGUNDOS` | `120` | Ventana para considerar conectado un dispositivo. |
| `MAX_RIEGO_MANUAL_SEGUNDOS` | `300` | Duración máxima de un comando `ENCENDER` manual. |
| `COMANDO_TTL_SEGUNDOS` | `120` | Tiempo de vida de cada comando. |
| `CAUDAL_BOMBA_LPM` | `1.0` | Caudal para estimar litros cuando el ESP32 no informa `cantidad_agua`. |

La clave de dispositivo se muestra en claro solamente al crearlo o rotarla. Guárdala en el dispositivo; la base de datos conserva únicamente su hash. Los siguientes ejemplos están escritos para `cmd.exe` de Windows (`curl.exe`, variables `%NOMBRE%` y comillas dobles escapadas).

Antes de usar los endpoints, aplica `migrations/2026_add_esp32_protocol.sql` en PostgreSQL.

### API para la aplicación (JWT)

Crear un dispositivo y recibir su clave una sola vez:

```bat
curl.exe -X POST "http://localhost:3000/api/dispositivos" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"id_sector\":1,\"nombre\":\"ESP32 jardín\"}"
```

Listar todos los dispositivos del usuario o filtrar por sector:

```bat
curl.exe -X GET "http://localhost:3000/api/dispositivos?id_sector=1" -H "Authorization: Bearer %TOKEN%"
```

Rotar la clave (la respuesta nueva solo se muestra una vez):

```bat
curl.exe -X POST "http://localhost:3000/api/dispositivos/1/rotar-clave" -H "Authorization: Bearer %TOKEN%"
```

Activar o desactivar un dispositivo:

```bat
curl.exe -X PATCH "http://localhost:3000/api/dispositivos/1" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"activo\":true}"
```

Solicitar un riego manual. `APAGAR` no necesita duración; `ENCENDER` requiere entre 10 segundos y el máximo configurado. Ambos requieren que el dispositivo del sector esté en línea:

```bat
curl.exe -X POST "http://localhost:3000/api/actuadores/1/comandos" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"accion\":\"ENCENDER\",\"duracion_segundos\":60}"
```

Consultar el estado de un comando:

```bat
curl.exe -X GET "http://localhost:3000/api/actuadores/1/comandos/25" -H "Authorization: Bearer %TOKEN%"
```

### API para el ESP32 (`X-Device-Key`)

Enviar lecturas y el estado actual de actuadores. Se aceptan hasta 100 lecturas por lote; las repeticiones por `uid` se deduplican y los códigos desconocidos se devuelven en `omitidas`:

```bat
curl.exe -X POST "http://localhost:3000/api/device/lecturas" -H "X-Device-Key: %DEVICE_KEY%" -H "Content-Type: application/json" -d "{\"lecturas\":[{\"uid\":\"a1b2c3d4-17\",\"codigo\":\"HUM-001\",\"valor\":43.5,\"unidad\":\"%\",\"hace_segundos\":40}],\"actuadores\":[{\"codigo\":\"BOMBA-001\",\"estado\":\"apagado\"}]}"
```

Reportar un riego ya ocurrido. Si se omite `cantidad_agua`, se estima usando `CAUDAL_BOMBA_LPM`:

```bat
curl.exe -X POST "http://localhost:3000/api/device/riegos" -H "X-Device-Key: %DEVICE_KEY%" -H "Content-Type: application/json" -d "{\"uid\":\"a1b2c3d4-18\",\"hace_segundos\":600,\"duracion_segundos\":90,\"modo\":\"AUTOMATICO\",\"cantidad_agua\":null}"
```

Consultar comandos pendientes vigentes. La respuesta marca los entregados como `ENVIADO`:

```bat
curl.exe -X GET "http://localhost:3000/api/device/comandos" -H "X-Device-Key: %DEVICE_KEY%"
```

Confirmar la ejecución o el fallo de un comando propio:

```bat
curl.exe -X POST "http://localhost:3000/api/device/comandos/25/ack" -H "X-Device-Key: %DEVICE_KEY%" -H "Content-Type: application/json" -d "{\"estado\":\"EJECUTADO\"}"
```

Todos los endpoints `/api/device` están limitados por `express-rate-limit`. Los estados y datos reportados por el dispositivo son la fuente para la telemetría; el backend no decide automatizaciones ni genera comandos automáticos.
