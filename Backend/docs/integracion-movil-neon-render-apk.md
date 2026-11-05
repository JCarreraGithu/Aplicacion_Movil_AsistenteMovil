# Integración móvil: orden manual de ejecución

Validado localmente el 4 de noviembre de 2026. No se accedió a Neon ni a Render.
Este procedimiento afecta únicamente conversaciones IA y archivado de plantas.

## Resultado y compatibilidad

- Las claves de `usuario.id_usuario` y `planta.id_planta` son INTEGER/SERIAL en
  el esquema confirmado por el repositorio. `SISTEMA_RIEGO` sin comillas resuelve
  como `sistema_riego`. Falta comparar el catálogo de la rama Neon antes de aplicar.
- Las dos migraciones son aditivas y transaccionales; no contienen DELETE,
  TRUNCATE, DROP ni actualizaciones de los registros existentes. `fecha_eliminacion`
  es nullable y sin default: las plantas actuales continúan visibles.
- Se agregaron validaciones para abortar ante columnas preexistentes incompatibles
  y una PK de conversaciones diferente. `IF NOT EXISTS` por sí solo no garantiza
  compatibilidad con cualquier objeto del mismo nombre.
- La versión anterior puede continuar consultando/creando plantas y consultando
  `consulta_ia` después de aplicar ambos archivos. No conoce el archivado y puede
  mostrar plantas archivadas si se revierte el backend después de usarlo.
- Las FK nuevas son RESTRICT: una vez creadas conversaciones asociadas, borrar
  físicamente un jardín/sector/planta/usuario puede resultar bloqueado. Los
  endpoints antiguos de borrado físico de jardín/sector pueden retornar 500.
  No es pérdida de datos ni afecta al archivado; no recomendar esas operaciones
  como prueba ni usar CASCADE para resolverlas. Una adaptación de esos endpoints
  queda fuera de esta entrega.
- Se conserva `consulta_ia`; no se transforma ni elimina su historial. La nueva
  tabla empieza vacía. Flutter permite importar cada consulta como conversación
  independiente. No se pueden reconstruir grupos, contexto de casos o bytes de
  fotografías que el historial anterior nunca almacenó. La importación local
  necesita sincronizarse para aparecer en otro dispositivo.
- La propiedad se valida con JWT: conversaciones siempre filtran por
  `(id_usuario,id)`, y planta por `planta -> sector -> jardin.id_usuario`.
  Un id de conversación igual para dos usuarios designa dos registros distintos.
  El id_usuario enviado en JSON no se utiliza. El rol SQL no sustituye esta
  validación HTTP: no hay RLS por usuario final.
- La edición simultánea de una conversación desde dos dispositivos sigue usando
  el último snapshot recibido. La copia local puede quedar desactualizada frente
  a otra sesión; se recomienda validar primero con un dispositivo por usuario.

## 1. Respaldo y rama de pruebas

En Neon Console crear/verificar una rama de pruebas derivada del estado actual;
conservar producción y la rama de respaldo. En SQL Editor seleccionar explícitamente
la rama antes de cada ejecución. `current_database()` no identifica por sí solo
la rama. No reutilizar un editor abierto de producción.

PowerShell, con PostgreSQL 18 instalado. Los comandos piden la contraseña y no
la escriben en archivos. Sustituir los campos de conexión con los de Neon; no
copiar contraseñas al repositorio. Usar host directo para respaldo/migraciones.

```powershell
$pgBin = 'C:\Program Files\PostgreSQL\18\bin'
$repo = 'C:\Users\testr\Desktop\PROYECTOS\SISTEMA_RIEGO'
$env:PGHOST = Read-Host 'Host directo de la base origen a respaldar'
$env:PGDATABASE = Read-Host 'Nombre de la base origen'
$env:PGUSER = Read-Host 'Rol propietario de la base origen'
$env:PGPORT = '5432'
$env:PGSSLMODE = 'require'
$backupDir = Join-Path $env:USERPROFILE 'Documents\RespaldosRiego'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backup = Join-Path $backupDir ('riego-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.dump')
& "$pgBin\pg_dump.exe" -W --format=custom --file=$backup
if ($LASTEXITCODE -ne 0) { throw 'Falló el respaldo: detenerse' }
& "$pgBin\pg_restore.exe" --list $backup
if ($LASTEXITCODE -ne 0) { throw 'El archivo no puede leerse: detenerse' }
```

`--list` solo verifica legibilidad del archivo; comprobar una restauración en
otra base desechable antes de depender del backup. El dump contiene datos
privados: conservar fuera de Git. No restaurarlo sobre producción para probarlo.

## 2. Preflight y snapshot en SQL Editor de la rama de pruebas

```sql
SELECT current_database(), current_user, version();
SELECT table_name,column_name,data_type,is_nullable,column_default
FROM information_schema.columns WHERE table_schema='sistema_riego'
AND ((table_name IN ('usuario','planta') AND column_name IN ('id_usuario','id_planta','fecha_eliminacion'))
 OR table_name='conversacion_ia') ORDER BY table_name,ordinal_position;
SELECT c.relname,pg_get_userbyid(c.relowner) AS propietario
FROM pg_class c WHERE c.oid IN ('sistema_riego.planta'::regclass,'sistema_riego.usuario'::regclass);
SELECT 'plantas' AS tabla,count(*) AS filas,
 md5(coalesce(jsonb_agg(to_jsonb(t)-'fecha_eliminacion' ORDER BY t.id_planta)::text,'[]')) AS hash
FROM sistema_riego.planta t
UNION ALL SELECT 'consultas',count(*),md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.id_consulta)::text,'[]')) FROM sistema_riego.consulta_ia t
UNION ALL SELECT 'casos',count(*),md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.id_caso)::text,'[]')) FROM sistema_riego.caso_planta t
UNION ALL SELECT 'bitacoras',count(*),md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.id_seguimiento)::text,'[]')) FROM sistema_riego.seguimiento_caso t
UNION ALL SELECT 'recordatorios',count(*),md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.id_recordatorio)::text,'[]')) FROM sistema_riego.recordatorio_caso t;
```

Guardar resultados y evitar escrituras concurrentes durante comparación. Detenerse
si las claves no son INTEGER o el rol no es propietario/miembro con permiso DDL.

## 3. Aplicar las dos migraciones, en este orden

SQL Editor: abrir el archivo local, copiar TODO el SQL y ejecutar el bloque entero
incluidos BEGIN/COMMIT, primero conversaciones y después archivado. No ejecutar
otras migraciones. Ante error: guardar SQLSTATE/MESSAGE/DETAIL, ejecutar
`ROLLBACK;` y detenerse. Alternativa PowerShell sobre el host de PRUEBAS:

```powershell
$env:PGHOST = Read-Host 'Host directo de la RAMA DE PRUEBAS'
$env:PGDATABASE = Read-Host 'Base en la RAMA DE PRUEBAS'
$env:PGUSER = Read-Host 'Propietario para migraciones'
& "$pgBin\psql.exe" -W -v ON_ERROR_STOP=1 -f "$repo\Backend\migrations\2026_add_conversacion_ia.sql"
if ($LASTEXITCODE -ne 0) { throw 'Falló conversaciones: detenerse' }
& "$pgBin\psql.exe" -W -v ON_ERROR_STOP=1 -f "$repo\Backend\migrations\2026_add_planta_archivada.sql"
if ($LASTEXITCODE -ne 0) { throw 'Falló archivado: detenerse' }
```

Repetir ambos archivos una vez para validar idempotencia en la rama. Repetir
snapshot anterior: conteos y hashes deben coincidir. La nueva tabla debe estar
vacía y todas las plantas anteriores tener fecha_eliminacion NULL.

```sql
SELECT count(*) FROM sistema_riego.conversacion_ia;
SELECT count(*) FILTER(WHERE fecha_eliminacion IS NOT NULL) AS archivadas FROM sistema_riego.planta;
SELECT conname,convalidated,pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid='sistema_riego.conversacion_ia'::regclass;
SELECT pg_get_indexdef(indexrelid) FROM pg_index WHERE indrelid='sistema_riego.conversacion_ia'::regclass;
```

## 4. Permisos del backend

Actualización confirmada por el usuario el 5 de noviembre de 2026: ambas
migraciones ya se aplicaron en Neon Primary y Render utiliza `neondb_owner`.
No crear `app_user` ni ejecutar el bloque siguiente en esa instalación: solo
corresponde a instalaciones que usan ese rol limitado. Confirmar que
`neondb_owner` conserva propiedad o privilegios efectivos sobre los objetos.
Las migraciones son archivos de referencia/manuales; `npm start` no las ejecuta.

Después de confirmar que Render usa `app_user`, aplicar manualmente como propietario:

```sql
GRANT USAGE ON SCHEMA sistema_riego TO app_user;
GRANT SELECT,INSERT,UPDATE ON sistema_riego.conversacion_ia TO app_user;
GRANT UPDATE(fecha_eliminacion) ON sistema_riego.planta TO app_user;
SELECT has_table_privilege('app_user','sistema_riego.conversacion_ia','SELECT') AS lectura,
 has_table_privilege('app_user','sistema_riego.conversacion_ia','INSERT') AS crear,
 has_table_privilege('app_user','sistema_riego.conversacion_ia','UPDATE') AS actualizar,
 has_column_privilege('app_user','sistema_riego.planta','fecha_eliminacion','UPDATE') AS archivar;
```

Conservar SELECT y los permisos previos de las demás tablas. No necesita DELETE
físico ni secuencia para conversaciones. No conceder superusuario ni propiedad a
app_user. Si Render usa otro rol, sustituirlo tras verificarlo, no crear roles a ciegas.

## 5. Actualizar Render (solo después de autorización)

Primero probar el backend nuevo LOCAL contra la rama de pruebas con variables
de entorno temporales, sin cambiar el .env compartido ni apuntarlo a producción.
Render actual continúa apuntando a su base actual: una migración en una rama de
pruebas no cambia esa base. Antes de desplegar la versión productiva, repetir
respaldo/migraciones/verificación/permisos en su base destino, con autorización.
No cambiar el Render productivo a la rama de pruebas para validar.

En Render revisar servicio, Root Directory `Backend`, Build Command `npm ci`,
Start Command `npm start`; conservar JWT_SECRET y credenciales existentes.
Verificar DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD y `DB_SSL=true` para Neon;
el backend verifica el certificado TLS. No cambiar JWT_SECRET: invalidaría sesiones.
Después de preparar y aprobar un commit separado, publicar el código autorizado
y seleccionar Manual Deploy del commit exacto. Esta tarea no hace commit/push/deploy.
Verificar `/` y llamadas JWT a conversaciones y plantas; revisar logs sin imprimir tokens.

## 6. APK y prueba Android

Generar solo después de validar backend y recibir autorización para el APK:

```powershell
Set-Location "$repo\systema_riego_app"
& 'C:\flutter\bin\flutter.bat' pub get
& 'C:\flutter\bin\flutter.bat' analyze --no-pub
# Revisar advertencias conocidas; detenerse si hay errores nuevos.
& 'C:\flutter\bin\flutter.bat' test --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Pruebas fallidas' }
& 'C:\flutter\bin\flutter.bat' build apk --release --dart-define=API_BASE_URL=https://sistema-riego-api.onrender.com
if ($LASTEXITCODE -ne 0) { throw 'Falló APK' }
# APK: build\app\outputs\flutter-apk\app-release.apk
```

Instalar conservando datos con firma compatible. No desinstalar antes del backup
del historial local. En Android pequeño probar con dos cuentas de PRUEBA:

1. Chat: inicio frío vacío; enviar texto/foto; abrir historial sin crear filas;
   volver desde otra pantalla mantiene activa; nueva, renombrar, eliminar y reabrir
   app. Otra cuenta no ve ni altera la conversación. Probar pérdida de red y reintento.
2. Chat visual: Markdown largo, teclado abierto, scroll y error visible sin tapar envío.
3. Texto: cuatro tamaños y escalado Android grande, reiniciar app y revisar formularios,
   navegación, catálogo y grid de plantas. Iconos/gráficos conservan tamaño.
4. Casos/plantas: cerrar un caso de prueba con resultado; no poder reabrirlo.
   Archivar una planta de prueba con caso, fotografía y recordatorio; desaparece del
   inventario, pero caso, bitácora, diagnóstico y recordatorio conservan IDs/contenido.
   Otra cuenta obtiene 404 al intentar archivarla.
5. Brotecita: ocultar/mostrar, movimiento reducido, teclado y progreso no disponible;
   al regresar de capacitación y tocarla refresca progreso confirmado, sin generar XP.

No utilizar registros reales para estas pruebas destructivas lógicas.

## Validación local realizada y reversión

`Backend/scripts/verificar-movil-postgres.js` usa únicamente loopback:55433,
requiere esquema ausente y no toma el destino de .env. Crea fixture desde DB y
relaciones de casos. Se probó en clúster PostgreSQL 18.4 desechable: migraciones
dos veces, OID/constraints sin cambios, snapshots idénticos, HTTP real con JWT,
rol SQL limitado, protección por usuario, archivo y conservación de consultas,
casos, tareas, recordatorios, fotos de bitácora e identificaciones. También se
probó que una conversación borrada no se resucita con PUT. No es una verificación
del catálogo ni permisos de Neon. El clúster de prueba se detiene al terminar.

Reversión: conservar tabla y columna; volver al backend anterior no exige DROP.
No restaurar backup sobre una base con nuevas escrituras sin conciliación. El
backend anterior puede volver a mostrar archivadas y no tiene conversaciones:
documentar ese límite antes de revertir. Preferir corrección compatible hacia delante.
