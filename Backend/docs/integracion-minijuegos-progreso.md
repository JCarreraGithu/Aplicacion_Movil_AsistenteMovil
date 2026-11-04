# Incorporación segura de minijuegos a la capacitación

## Compatibilidad revisada con Neon

Esta revisión usa los hallazgos de esquema que el usuario confirmó para Neon; no se abrió conexión a producción ni se ejecutó SQL.

- `sistema_riego.capacitacion_ruta` conserva la ruta publicada `id_ruta=1`, `id_leccion_version=1`, `slug=fundamentos-del-riego-v1` y sus seis actividades.
- La restricción actual `uq_capacitacion_ruta_version UNIQUE (id_leccion_version)` impide una segunda ruta para la misma versión. La migración la sustituye por `UNIQUE (id_leccion_version, orden)`: el tramo existente queda en orden 1 por el valor predeterminado y el nuevo se crea en orden 2.
- Se agregan `capacitacion_ruta.orden`, `capacitacion_ruta.id_ruta_previa` y `capacitacion_actividad.configuracion`. La migración verifica tipo, nullabilidad y default de las columnas para detenerse ante una forma incompatible.
- Las restricciones nuevas de orden y autorreferencia se crean si faltan; si ya existe una con el mismo nombre y definición distinta, la migración aborta en vez de reemplazarla. La restricción única antigua se reemplaza solo tras verificar que tiene la forma confirmada por Neon.
- El CHECK de `capacitacion_actividad.tipo` se detecta por su columna en el catálogo de PostgreSQL, sin asumir el nombre que Neon le asignó. Se reemplaza por una lista validada que conserva los tipos originales y admite `simulacion_riego`, `minijuego_riego`, `minijuego_luz`, `diagnostico_interactivo` y `simulacion_jardin`.
- La migración **no crea, reemplaza ni elimina** `proteger_capacitacion_ruta_publicada()` ni sus triggers. El preflight inspecciona la función existente y exige que contenga la protección del estado publicado y `FOR UPDATE`; después exige un trigger **BEFORE ROW por separado para cada operación** requerida en ruta/actividad. Así, un trigger AFTER de otra operación no puede completar accidentalmente el conjunto de flags. La publicación posterior es una transición borrador → publicada, permitida por el comportamiento actual; una ruta ya publicada sigue inmutable.
- No se actualizan actividades publicadas, respuestas, intentos, progreso ni XP. La segunda ruta usa cuatro IDs de actividad nuevos.

El SQL usa transacciones, bloques `DO`, `to_regclass`, `pg_catalog`, `JSONB`, advisory transaction locks e índices/constraints de PostgreSQL. Son construcciones compatibles con PostgreSQL administrado por Neon; aun así, el preflight sobre Neon y las verificaciones posteriores son obligatorios. No se certifica una versión específica del servidor porque no se consultó `server_version`.

## Orden de actividades y contratos comprobados

El seed conserva los contratos que esperan los calificadores actuales:

1. `simulacion_riego` / Riego perfecto: configuración v1 con humedad inicial 20, objetivo 45–65, incremento 2, dosis máxima 15, total 40 y 8 acciones. Respuesta `{ "version": 1, "acciones": [{"tipo":"regar","agua":15}] }`. El calificador vuelve a simular las dosis en backend.
2. `minijuego_luz` / Sol o sombra: configuración exacta `{version,pista}`, opciones con claves únicas y respuesta `{ "version": 1, "seleccion": "indirecta" }`.
3. `diagnostico_interactivo` / Detective de plantas: configuración exacta `{version,situacion,observaciones}` con observaciones breves; la respuesta es `{ "version": 1, "accion": "observar" }`.
4. `simulacion_jardin` / Jardín inteligente: cuatro sectores virtuales A–D, estados `baja`, `objetivo`, `alta`, `sin_lectura`; respuesta con una acción permitida por sector. La combinación de pistas y respuesta correcta coincide con `calificarJardinInteligente`.

No se envían `correcto`, XP ni claves correctas desde Flutter. No se consultan sensores ni se llaman endpoints de dispositivos/actuadores. El contenido del seed sigue requiriendo revisión editorial antes de publicar.

## Idempotencia del seed y control de conflictos

`docs/capacitacion-minijuegos-seed.sql` valida que la ruta real 1/version 1 publicada aún tenga seis actividades. Usa un advisory lock para serializar dos ejecuciones del seed. Si la ruta sucesora ya existe, exige que coincidan su versión, padre, orden, slug, título, descripción y estado borrador. Compara cada actividad por orden y por todos sus campos JSON/texto/XP; un conflicto produce `RAISE EXCEPTION` y revierte la transacción.

Si el borrador está vacío o incompleto, inserta únicamente las actividades faltantes. Al final exige exactamente cuatro actividades. No usa `ON CONFLICT DO NOTHING`, no reemplaza contenido y nunca publica la ruta.

## Consultas de verificación

Ejecutar primero las consultas de solo lectura en Neon y guardar sus resultados para comparar después.

### Antes de la migración

```sql
SELECT current_database() AS base, current_user, session_user,
       current_setting('server_version') AS version_postgresql,
       current_schema();

SELECT r.id_ruta, r.id_leccion_version, r.slug, r.estado,
       COUNT(a.id_actividad) AS actividades,
       ARRAY_AGG(a.id_actividad ORDER BY a.orden) AS ids_actividad
FROM sistema_riego.capacitacion_ruta r
LEFT JOIN sistema_riego.capacitacion_actividad a ON a.id_ruta = r.id_ruta
WHERE r.id_ruta = 1
GROUP BY r.id_ruta, r.id_leccion_version, r.slug, r.estado;

SELECT c.conname, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
WHERE c.conrelid IN (
    'sistema_riego.capacitacion_ruta'::regclass,
    'sistema_riego.capacitacion_actividad'::regclass
)
ORDER BY c.conrelid::regclass::text, c.conname;

SELECT t.tgrelid::regclass AS tabla, t.tgname,
       pg_get_triggerdef(t.oid) AS trigger_sql,
       n.nspname AS esquema_funcion, p.proname AS funcion,
       MD5(pg_get_functiondef(p.oid)) AS hash_funcion
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE t.tgrelid IN (
    'sistema_riego.capacitacion_ruta'::regclass,
    'sistema_riego.capacitacion_actividad'::regclass
) AND NOT t.tgisinternal
ORDER BY tabla, t.tgname;

SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'sistema_riego'
  AND table_name IN ('capacitacion_ruta', 'capacitacion_actividad')
  AND column_name IN ('orden', 'id_ruta_previa', 'configuracion')
ORDER BY table_name, ordinal_position;

SELECT COUNT(*) AS intentos_ruta_1
FROM sistema_riego.capacitacion_actividad_intento
WHERE id_ruta = 1;
SELECT COUNT(*) AS filas_progreso_ruta_1,
       COALESCE(SUM(xp_ganado), 0) AS xp_ruta_1
FROM sistema_riego.capacitacion_actividad_progreso
WHERE id_ruta = 1;
```

Confirma base/schema, una fila de ruta 1 con seis actividades, las restricciones/triggers que compartió el propietario del sistema y el estado original de intentos/progreso. `orden`, `id_ruta_previa` y `configuracion` deben estar ausentes antes de aplicar esta versión.

### Después de la migración estructural y antes del seed

```sql
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'sistema_riego'
  AND table_name IN ('capacitacion_ruta', 'capacitacion_actividad')
  AND column_name IN ('orden', 'id_ruta_previa', 'configuracion')
ORDER BY table_name, ordinal_position;

SELECT c.conname, pg_get_constraintdef(c.oid) AS definicion, c.convalidated
FROM pg_constraint c
WHERE c.conrelid IN (
    'sistema_riego.capacitacion_ruta'::regclass,
    'sistema_riego.capacitacion_actividad'::regclass
)
ORDER BY c.conrelid::regclass::text, c.conname;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'sistema_riego'
  AND tablename = 'capacitacion_ruta'
ORDER BY indexname;

SELECT r.id_ruta, r.id_leccion_version, r.orden, r.id_ruta_previa,
       r.slug, r.estado, COUNT(a.id_actividad) AS actividades,
       ARRAY_AGG(a.id_actividad ORDER BY a.orden) FILTER (WHERE a.id_actividad IS NOT NULL) AS ids_actividad
FROM sistema_riego.capacitacion_ruta r
LEFT JOIN sistema_riego.capacitacion_actividad a ON a.id_ruta = r.id_ruta
WHERE r.id_ruta = 1
GROUP BY r.id_ruta;

SELECT MD5(pg_get_functiondef(p.oid)) AS hash_funcion
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'sistema_riego'
  AND p.proname = 'proteger_capacitacion_ruta_publicada';
```

Compara los IDs de actividad, el hash de la función, conteos de intentos/progreso y XP contra los resultados previos. La migración no debe haber cambiado ninguno. Debe existir `uq_capacitacion_ruta_version_orden`, el FK `id_ruta_previa`, los CHECK nuevos y los mismos triggers/función.

### Después del seed, todavía en borrador

```sql
SELECT r.id_ruta, r.id_leccion_version, r.orden, r.id_ruta_previa,
       r.slug, r.estado, r.fecha_publicacion,
       COUNT(a.id_actividad) AS actividades,
       ARRAY_AGG(a.id_actividad ORDER BY a.orden) FILTER (WHERE a.id_actividad IS NOT NULL) AS ids_actividad
FROM sistema_riego.capacitacion_ruta r
LEFT JOIN sistema_riego.capacitacion_actividad a ON a.id_ruta = r.id_ruta
WHERE r.id_ruta IN (1, (SELECT id_ruta FROM sistema_riego.capacitacion_ruta
                         WHERE slug = 'fundamentos-riego-minijuegos-v1'))
GROUP BY r.id_ruta
ORDER BY r.orden;

SELECT a.id_actividad, a.id_ruta, a.orden, a.tipo, a.titulo, a.xp,
       a.opciones, a.respuesta_correcta, a.configuracion
FROM sistema_riego.capacitacion_actividad a
JOIN sistema_riego.capacitacion_ruta r ON r.id_ruta = a.id_ruta
WHERE r.slug = 'fundamentos-riego-minijuegos-v1'
ORDER BY a.orden;

SELECT COUNT(*) AS cantidad, ARRAY_AGG(tipo ORDER BY orden) AS tipos
FROM sistema_riego.capacitacion_actividad
WHERE id_ruta = (SELECT id_ruta FROM sistema_riego.capacitacion_ruta
                 WHERE slug = 'fundamentos-riego-minijuegos-v1');

SELECT COUNT(*) AS intentos_ruta_1
FROM sistema_riego.capacitacion_actividad_intento WHERE id_ruta = 1;
SELECT COUNT(*) AS filas_progreso_ruta_1,
       COALESCE(SUM(xp_ganado), 0) AS xp_ruta_1
FROM sistema_riego.capacitacion_actividad_progreso WHERE id_ruta = 1;
```

La ruta 1 debe seguir con seis IDs originales; la sucesora debe tener `id_leccion_version=1`, `id_ruta_previa=1`, `orden=2`, estado `borrador`, fecha de publicación NULL y exactamente cuatro actividades en este orden: `simulacion_riego`, `minijuego_luz`, `diagnostico_interactivo`, `simulacion_jardin`. Repite el seed: debe terminar sin cambios si el contenido coincide. Si cualquier valor difiere, el seed debe abortar, no repararlo a ciegas.

## Backend, desbloqueo y crecimiento de Brotecita

- El backend actualizado selecciona rutas publicadas por `orden` y `id_ruta`, y consulta progreso por `id_usuario` autenticado. Una ruta en borrador no aparece en `GET /api/capacitacion/modulos/:idModulo/rutas`.
- Después de publicar la segunda ruta, la respuesta debe incluir ambas. Para un usuario que no terminó la ruta 1, `disponible=false` en la sucesora y un POST directo recibe 409. Al completar las seis actividades anteriores, el backend confirma la ruta 2 como disponible.
- El POST vuelve a validar el prerrequisito en backend dentro de la transacción. Cada intento usa el contrato JWT e `Idempotency-Key` actual; los nuevos IDs separan progreso antiguo y nuevo. El XP histórico de la ruta 1 no se recalcula.
- Brotecita suma IDs de actividad distintos de todas las rutas publicadas. Una vez activa la ruta de cuatro, un usuario que tenga las seis anteriores completas y ninguna nueva verá `6/10 = 60 %`; actualmente ese porcentaje corresponde a la etapa `planta`, frente a `floración` cuando las seis anteriores eran todo el catálogo. Esto es un cambio visual por ampliación del denominador, no pérdida de filas, XP ni intentos. El test Flutter cubre exactamente 6/10. Si se desea que la etapa nunca retroceda al añadir contenido, se requiere acordar un sistema de hitos persistentes/monótonos antes de cambiar ese cálculo; esta entrega conserva el porcentaje real.
- Progreso no disponible sigue siendo `null` en Flutter. El cliente no debe inferir desbloqueos ni XP. Las cuatro vistas previas no se cuentan porque no están en rutas publicadas y no acceden a hardware.

## Procedimiento de aplicación en el orden correcto

No se aplicó ninguno de estos pasos en esta tarea.

1. Ejecutar las consultas “Antes de la migración”; confirmar que Neon es la base/schema correctos y guardar IDs, hashes, conteos de intentos/progreso y XP.
2. Como propietario de `sistema_riego`, ejecutar **solo** `Backend/migrations/2026_add_capacitacion_minijuegos_extensibles.sql` (por el SQL Editor de Neon o `psql -v ON_ERROR_STOP=1 -f <archivo>`). El archivo abre su propia transacción. Si el preflight o cualquier sentencia falla, debe quedar en rollback; no continuar con seed.
3. Ejecutar las consultas “Después de la migración”. Comparar ruta1, IDs, función, triggers, intentos, progreso y XP con el snapshot anterior. Si algo cambió, detenerse y no desplegar.
4. Desplegar el backend compatible con `orden`/`id_ruta_previa`. Estas consultas ya dependen de las nuevas columnas.
5. Revisar el contenido educativo; entonces ejecutar **solo** `Backend/docs/capacitacion-minijuegos-seed.sql`. El seed es transaccional e idempotente para contenido idéntico. Si detecta diferencias, detenerse y revisar manualmente; no cambiar a `ON CONFLICT DO NOTHING`.
6. Ejecutar las consultas “Después del seed”. Confirmar estado borrador, cuatro actividades, parent/order/version y conservación de los seis IDs/progreso/XP anteriores.
7. Desplegar Flutter con renderizadores para los cuatro tipos. Las rutas borrador siguen ocultas y las vistas previas no otorgan XP.
8. Probar autenticado el endpoint de rutas mientras el seed está en borrador: debe mostrarse solo la ruta 1. No ejecutar aún el SQL de publicación.
9. **Solo tras aprobación editorial y autorización de publicación**, aplicar el bloque de publicación siguiente. El trigger actual recibe `OLD.estado='borrador'` y permite la transición a publicada; el CHECK de `fecha_publicacion` queda satisfecho. No se reemplaza ni desactiva la función.
10. Verificar el endpoint con un usuario incompleto y otro que ya completó ruta1. Confirmar que la segunda ruta queda bloqueada/disponible respectivamente y que el backend solo recompensa el primer acierto.

### Publicación manual futura (no ejecutar todavía)

```sql
BEGIN;
DO $$
DECLARE
    id_nueva INTEGER;
    id_previa INTEGER;
    version_nueva INTEGER;
    orden_nueva INTEGER;
    actividades INTEGER;
    tipos TEXT[];
BEGIN
    SELECT id_ruta, id_ruta_previa, id_leccion_version, orden
      INTO id_nueva, id_previa, version_nueva, orden_nueva
    FROM sistema_riego.capacitacion_ruta
    WHERE slug = 'fundamentos-riego-minijuegos-v1'
      AND estado = 'borrador'
    FOR UPDATE;
    IF id_nueva IS NULL OR id_previa IS DISTINCT FROM 1
       OR version_nueva IS DISTINCT FROM 1 OR orden_nueva IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION 'Publicación detenida: la sucesora no coincide con ruta1/version1/orden2';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM sistema_riego.capacitacion_ruta
        WHERE id_ruta = 1 AND estado = 'publicada'
          AND id_leccion_version = version_nueva
    ) THEN
        RAISE EXCEPTION 'Publicación detenida: la ruta previa ya no está publicada';
    END IF;
    SELECT COUNT(*), ARRAY_AGG(tipo::TEXT ORDER BY orden)
      INTO actividades, tipos
    FROM sistema_riego.capacitacion_actividad
    WHERE id_ruta = id_nueva;
    IF actividades <> 4 OR tipos <> ARRAY[
        'simulacion_riego', 'minijuego_luz',
        'diagnostico_interactivo', 'simulacion_jardin'
    ]::TEXT[] THEN
        RAISE EXCEPTION 'Publicación detenida: actividades/tipos no coinciden con el seed revisado';
    END IF;
    UPDATE sistema_riego.capacitacion_ruta
       SET estado = 'publicada', fecha_publicacion = CURRENT_TIMESTAMP
     WHERE id_ruta = id_nueva AND estado = 'borrador';
END;
$$;
COMMIT;
```

## Reversión sin borrar progreso

- **Solo se aplicó la migración estructural; no se ejecutó el seed:** `Backend/migrations/2026_add_capacitacion_minijuegos_extensibles.down.sql` puede restaurar la unicidad antigua y los tipos originales si su preflight confirma que no hay rutas sucesoras, tipos nuevos ni configuraciones usadas. Conserva `configuracion` vacía para no eliminar una columna que otro cambio pudiera usar. No toca intentos/progreso ni la función/triggers.
- **El seed creó el borrador o se publicó la sucesora:** no ejecutar el `.down.sql`; se detiene deliberadamente. No borrar/retirar la ruta ni eliminar actividades porque el trigger existente protege lo publicado y pueden existir nuevos IDs de progreso. Mantener el esquema y los datos, volver atrás solo Flutter si hiciera falta y desplegar una corrección compatible de backend. No revertir el backend a una versión que desconozca el nuevo esquema sin verificar sus consultas.
- La función existente impide cambiar una ruta ya publicada a `retirada`. No se preparó ni recomienda un `UPDATE` para despublicarla. Tras publicar, la reversión segura es conservar datos y corregir hacia delante.

## Pruebas y límites de esta preparación

- Backend: `npm test`, incluyendo validadores deterministas, XP único, idempotencia, desbloqueo servidor, seis actividades antiguas intactas y guardas del SQL.
- Flutter: pruebas pertinentes de capacitación, renderizadores, vista previa, Brotecita y escenario 6/10; `flutter analyze --no-pub` y `flutter test --no-pub`.
- No se ejecutó la migración, seed ni consultas en Neon; no hay verificación real de permisos o ejecución PostgreSQL en vivo. La consulta de triggers/constraints de esta guía debe ser el gate antes de aplicar.
- No se publicó la ruta, desplegó Render, generó APK ni se hizo commit/push.
