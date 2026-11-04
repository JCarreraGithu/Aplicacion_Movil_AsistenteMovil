-- Diagnóstico de SOLO LECTURA del preflight de
-- migrations/2026_add_capacitacion_minijuegos_extensibles.sql.
-- Ejecutar manualmente en el SQL Editor de la rama de PRUEBAS de Neon.
-- Sin transacción explícita: BEGIN/END dentro del DO son sintaxis PL/pgSQL,
-- no instrucciones para abrir/cerrar una transacción SQL.
-- No ejecuta la migración, el seed, DDL, DML ni bloqueos FOR UPDATE.
-- Conserva los criterios del preflight; solo separa sus errores y añade datos.
-- Un error identifica la primera comprobación que falla. No demuestra que
-- el fallo anterior ocurriera aquí: si todo pasa, pudo ocurrir después.

DO $preflight$
DECLARE
    ruta_table REGCLASS := TO_REGCLASS('sistema_riego.capacitacion_ruta');
    actividad_table REGCLASS := TO_REGCLASS('sistema_riego.capacitacion_actividad');
    version_att SMALLINT;
    orden_att SMALLINT;
    tipo_att SMALLINT;
    checks_tipo INTEGER;
    protection_function REGPROCEDURE;
    protection_definition TEXT;
    ruta_actual JSONB;
    actividades_actuales BIGINT;
    metadata TEXT;
    requerido RECORD;
    paso TEXT := 'PF00: resolución de tablas';
    error_estado TEXT;
    error_mensaje TEXT;
    error_detalle TEXT;
    error_pista TEXT;
BEGIN
    RAISE NOTICE 'Base=%, current_user=%, session_user=%, PostgreSQL=%',
        CURRENT_DATABASE(), CURRENT_USER, SESSION_USER, CURRENT_SETTING('server_version');
    IF ruta_table IS NULL THEN
        RAISE EXCEPTION 'No existe sistema_riego.capacitacion_ruta';
    END IF;
    IF actividad_table IS NULL THEN
        RAISE EXCEPTION 'No existe sistema_riego.capacitacion_actividad';
    END IF;
    RAISE NOTICE 'PF00 OK: ambas tablas resuelven en sistema_riego';

    paso := 'PF01: ruta id_ruta=1';
    SELECT JSONB_BUILD_OBJECT(
        'id_ruta', r.id_ruta, 'id_leccion_version', r.id_leccion_version,
        'slug', r.slug, 'estado', r.estado
    ) INTO ruta_actual
    FROM sistema_riego.capacitacion_ruta r WHERE r.id_ruta = 1;
    IF ruta_actual IS NULL THEN
        RAISE EXCEPTION 'No existe la ruta 1';
    END IF;
    IF (ruta_actual->>'id_leccion_version')::INTEGER IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION 'La ruta 1 no referencia id_leccion_version=1'
            USING DETAIL = ruta_actual::TEXT;
    END IF;
    IF ruta_actual->>'slug' IS DISTINCT FROM 'fundamentos-del-riego-v1' THEN
        RAISE EXCEPTION 'El slug de la ruta 1 no coincide'
            USING DETAIL = ruta_actual::TEXT;
    END IF;
    IF ruta_actual->>'estado' IS DISTINCT FROM 'publicada' THEN
        RAISE EXCEPTION 'La ruta 1 no está publicada'
            USING DETAIL = ruta_actual::TEXT;
    END IF;
    SELECT COUNT(*) INTO actividades_actuales
    FROM sistema_riego.capacitacion_actividad WHERE id_ruta = 1;
    IF actividades_actuales <> 6 THEN
        RAISE EXCEPTION 'La ruta 1 tiene % actividades; se esperaban 6', actividades_actuales;
    END IF;
    RAISE NOTICE 'PF01 OK: %; actividades=%', ruta_actual, actividades_actuales;

    paso := 'PF02: atributos del catálogo';
    SELECT attnum INTO version_att FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'id_leccion_version' AND NOT attisdropped;
    SELECT attnum INTO orden_att FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'orden' AND NOT attisdropped;
    SELECT attnum INTO tipo_att FROM pg_attribute
    WHERE attrelid = actividad_table AND attname = 'tipo' AND NOT attisdropped;
    IF version_att IS NULL OR tipo_att IS NULL THEN
        RAISE EXCEPTION 'Falta una columna requerida'
            USING DETAIL = FORMAT('attnum(id_leccion_version)=%s; attnum(tipo)=%s',
                version_att, tipo_att);
    END IF;
    RAISE NOTICE 'PF02 OK: attnum versión=%, orden=%, tipo=% (orden NULL es esperado antes de migrar)',
        version_att, orden_att, tipo_att;

    paso := 'PF03: único CHECK que referencia actividad.tipo';
    SELECT COUNT(*) INTO checks_tipo FROM pg_constraint c
    WHERE c.conrelid = actividad_table AND c.contype = 'c'
      AND tipo_att = ANY(c.conkey);
    SELECT STRING_AGG(FORMAT('%s; validada=%s; conkey=%s; %s',
        c.conname, c.convalidated, c.conkey, pg_get_constraintdef(c.oid)), E'\n'
        ORDER BY c.conname) INTO metadata
    FROM pg_constraint c
    WHERE c.conrelid = actividad_table AND c.contype = 'c'
      AND tipo_att = ANY(c.conkey);
    IF checks_tipo <> 1 THEN
        RAISE EXCEPTION 'Se encontraron % CHECK sobre tipo; se esperaba exactamente 1', checks_tipo
            USING DETAIL = COALESCE(metadata, 'Ninguno encontrado');
    END IF;
    RAISE NOTICE 'PF03 OK: %', metadata;

    paso := 'PF04: unicidad de ruta por versión/orden';
    SELECT STRING_AGG(FORMAT('%s; contype=%s; conkey=%s; %s',
        c.conname, c.contype, c.conkey, pg_get_constraintdef(c.oid)), E'\n'
        ORDER BY c.conname) INTO metadata
    FROM pg_constraint c WHERE c.conrelid = ruta_table;
    IF orden_att IS NULL AND NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table AND c.conname = 'uq_capacitacion_ruta_version'
          AND c.contype = 'u' AND CARDINALITY(c.conkey) = 1
          AND c.conkey[1] = version_att
    ) THEN
        RAISE EXCEPTION 'Sin columna orden, no coincide uq_capacitacion_ruta_version UNIQUE(id_leccion_version)'
            USING DETAIL = COALESCE(metadata, 'No se encontraron restricciones');
    ELSIF orden_att IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table
          AND c.conname IN ('uq_capacitacion_ruta_version', 'uq_capacitacion_ruta_version_orden')
          AND c.contype = 'u'
          AND ((CARDINALITY(c.conkey) = 1 AND c.conkey[1] = version_att)
            OR (CARDINALITY(c.conkey) = 2 AND c.conkey[1] = version_att AND c.conkey[2] = orden_att))
    ) THEN
        RAISE EXCEPTION 'Con columna orden, no coincide ninguna de las restricciones únicas admitidas'
            USING DETAIL = COALESCE(metadata, 'No se encontraron restricciones');
    END IF;
    RAISE NOTICE 'PF04 OK: unicidad compatible';

    paso := 'PF05: CHECK de estados';
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c WHERE c.conrelid = ruta_table AND c.contype = 'c'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%borrador%'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%publicada%'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%retirada%'
    ) THEN
        RAISE EXCEPTION 'No hay un CHECK que contenga borrador, publicada y retirada'
            USING DETAIL = COALESCE(metadata, 'Sin restricciones');
    END IF;
    RAISE NOTICE 'PF05 OK: CHECK de estados encontrado';

    paso := 'PF06: CHECK de fecha de publicación';
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c WHERE c.conrelid = ruta_table AND c.contype = 'c'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%fecha_publicacion%'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%publicada%'
    ) THEN
        RAISE EXCEPTION 'No hay un CHECK que contenga fecha_publicacion y publicada'
            USING DETAIL = COALESCE(metadata, 'Sin restricciones');
    END IF;
    RAISE NOTICE 'PF06 OK: CHECK de publicación encontrado';

    paso := 'PF07: función de protección sin argumentos';
    protection_function := TO_REGPROCEDURE('sistema_riego.proteger_capacitacion_ruta_publicada()');
    IF protection_function IS NULL THEN
        SELECT STRING_AGG(p.oid::REGPROCEDURE::TEXT, ', ' ORDER BY p.oid)
          INTO metadata
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'proteger_capacitacion_ruta_publicada' AND n.nspname = 'sistema_riego';
        RAISE EXCEPTION 'No resuelve sistema_riego.proteger_capacitacion_ruta_publicada()'
            USING DETAIL = 'Firmas encontradas: ' || COALESCE(metadata, 'ninguna');
    END IF;
    SELECT PG_GET_FUNCTIONDEF(protection_function::OID) INTO protection_definition;
    RAISE NOTICE 'PF07 OK: función=%, hash=%', protection_function, MD5(protection_definition);

    paso := 'PF08: texto literal OLD.ESTADO en función';
    IF UPPER(protection_definition) NOT LIKE '%OLD.ESTADO%' THEN
        RAISE EXCEPTION 'El preflight no encuentra la secuencia literal OLD.ESTADO'
            USING DETAIL = protection_definition,
                  HINT = 'Revisar si la función es otra versión o usa comillas/espacios. No modificarla automáticamente.';
    END IF;
    RAISE NOTICE 'PF08 OK: OLD.ESTADO encontrado';

    paso := 'PF09: texto literal FOR UPDATE en función';
    IF UPPER(protection_definition) NOT LIKE '%FOR UPDATE%' THEN
        RAISE EXCEPTION 'El preflight no encuentra la secuencia literal FOR UPDATE'
            USING DETAIL = protection_definition,
                  HINT = 'Revisar bloqueo real y posibles saltos de línea entre FOR y UPDATE. No reemplazar la función.';
    END IF;
    RAISE NOTICE 'PF09 OK: FOR UPDATE encontrado';

    -- Mismos bits del preflight: ROW=1, BEFORE=2, INSERT=4, DELETE=8, UPDATE=16.
    -- El estado tgenabled se muestra, pero no se agrega al criterio original.
    SELECT STRING_AGG(FORMAT('%s; función=%s; tgtype=%s; tgenabled=%s; %s',
        t.tgname, t.tgfoid::REGPROCEDURE, t.tgtype, t.tgenabled,
        pg_get_triggerdef(t.oid)), E'\n' ORDER BY t.tgrelid, t.tgname)
      INTO metadata
    FROM pg_trigger t WHERE t.tgrelid IN (ruta_table, actividad_table) AND NOT t.tgisinternal;
    FOR requerido IN
        SELECT * FROM (VALUES
            (ruta_table, 16, 'PF10: ruta BEFORE ROW UPDATE'),
            (ruta_table, 8, 'PF11: ruta BEFORE ROW DELETE'),
            (actividad_table, 4, 'PF12: actividad BEFORE ROW INSERT'),
            (actividad_table, 16, 'PF13: actividad BEFORE ROW UPDATE'),
            (actividad_table, 8, 'PF14: actividad BEFORE ROW DELETE')
        ) AS requeridos(tabla, evento, etiqueta)
    LOOP
        paso := requerido.etiqueta;
        IF NOT EXISTS (
            SELECT 1 FROM pg_trigger t
            WHERE t.tgrelid = requerido.tabla AND NOT t.tgisinternal
              AND t.tgfoid = protection_function::OID
              AND (t.tgtype & 1) = 1 AND (t.tgtype & 2) = 2
              AND (t.tgtype & requerido.evento) = requerido.evento
        ) THEN
            RAISE EXCEPTION 'No hay trigger compatible para % usando la función OID %',
                requerido.etiqueta, protection_function::OID
                USING DETAIL = COALESCE(metadata, 'No hay triggers de usuario en estas tablas');
        END IF;
        RAISE NOTICE '% OK', paso;
    END LOOP;
    RAISE NOTICE 'PREFLIGHT COMPLETO OK. Solo se hicieron consultas. No ejecutar aún la migración: si el fallo anterior fue posterior al preflight, este diagnóstico no lo identifica.';
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        error_estado = RETURNED_SQLSTATE,
        error_mensaje = MESSAGE_TEXT,
        error_detalle = PG_EXCEPTION_DETAIL,
        error_pista = PG_EXCEPTION_HINT;
    RAISE EXCEPTION USING
        ERRCODE = error_estado,
        MESSAGE = FORMAT('[%s] %s', paso, error_mensaje),
        DETAIL = FORMAT('SQLSTATE original=%s%s%s', error_estado,
            CASE WHEN COALESCE(error_detalle, '') = '' THEN '' ELSE E'\n' || error_detalle END,
            CASE WHEN COALESCE(error_pista, '') = '' THEN '' ELSE E'\nPista: ' || error_pista END),
        HINT = 'Copiar el mensaje completo (incluidos PFxx, SQLSTATE y DETAIL). Este archivo no cambia datos ni estructura.';
END;
$preflight$;
