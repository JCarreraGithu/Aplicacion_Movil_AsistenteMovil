-- Extiende la ruta publicada sin editarla ni reemplazar la protección existente.
-- Aplicar manualmente como propietario del esquema; no publica ni inserta juegos.
BEGIN;

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
BEGIN
    IF ruta_table IS NULL OR actividad_table IS NULL THEN
        RAISE EXCEPTION 'No existen las tablas de capacitación esperadas en sistema_riego';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sistema_riego.capacitacion_ruta r
        WHERE r.id_ruta = 1
          AND r.id_leccion_version = 1
          AND r.slug = 'fundamentos-del-riego-v1'
          AND r.estado = 'publicada'
          AND (SELECT COUNT(*) FROM sistema_riego.capacitacion_actividad a
               WHERE a.id_ruta = r.id_ruta) = 6
    ) THEN
        RAISE EXCEPTION 'Preflight detenido: la ruta publicada 1/version 1 no coincide o no conserva seis actividades';
    END IF;

    SELECT attnum INTO version_att
    FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'id_leccion_version' AND NOT attisdropped;
    SELECT attnum INTO orden_att
    FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'orden' AND NOT attisdropped;
    SELECT attnum INTO tipo_att
    FROM pg_attribute
    WHERE attrelid = actividad_table AND attname = 'tipo' AND NOT attisdropped;

    SELECT COUNT(*) INTO checks_tipo
    FROM pg_constraint c
    WHERE c.conrelid = actividad_table
      AND c.contype = 'c'
      AND tipo_att = ANY(c.conkey);
    IF checks_tipo <> 1 THEN
        RAISE EXCEPTION 'Preflight detenido: se esperaba exactamente una restricción CHECK sobre capacitacion_actividad.tipo; se encontraron %', checks_tipo;
    END IF;

    IF orden_att IS NULL AND NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table AND c.conname = 'uq_capacitacion_ruta_version'
          AND c.contype = 'u' AND CARDINALITY(c.conkey) = 1
          AND c.conkey[1] = version_att
    ) THEN
        RAISE EXCEPTION 'Preflight detenido: no coincide uq_capacitacion_ruta_version';
    ELSIF orden_att IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table
          AND c.conname IN ('uq_capacitacion_ruta_version', 'uq_capacitacion_ruta_version_orden')
          AND c.contype = 'u'
          AND ((CARDINALITY(c.conkey) = 1 AND c.conkey[1] = version_att)
            OR (CARDINALITY(c.conkey) = 2 AND c.conkey[1] = version_att AND c.conkey[2] = orden_att))
    ) THEN
        RAISE EXCEPTION 'Preflight detenido: no coincide la restricción única de ruta por versión/orden';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table AND c.contype = 'c'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%borrador%'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%publicada%'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%retirada%'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table AND c.contype = 'c'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%fecha_publicacion%'
          AND LOWER(pg_get_constraintdef(c.oid)) LIKE '%publicada%'
    ) THEN
        RAISE EXCEPTION 'Preflight detenido: los CHECK de estado/publicación no corresponden al esquema esperado';
    END IF;

    protection_function := TO_REGPROCEDURE('sistema_riego.proteger_capacitacion_ruta_publicada()');
    IF protection_function IS NULL THEN
        RAISE EXCEPTION 'Preflight detenido: no existe la función actual de protección de rutas';
    END IF;
    SELECT PG_GET_FUNCTIONDEF(protection_function::OID) INTO protection_definition;
    IF UPPER(protection_definition) NOT LIKE '%OLD.ESTADO%'
       OR UPPER(protection_definition) NOT LIKE '%FOR UPDATE%' THEN
        RAISE EXCEPTION 'Preflight detenido: la función no demuestra bloqueo de ruta y protección de estado publicado';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = ruta_table AND NOT t.tgisinternal
          AND t.tgfoid = protection_function::OID
          AND (t.tgtype & 1) = 1 AND (t.tgtype & 2) = 2 AND (t.tgtype & 16) = 16
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = ruta_table AND NOT t.tgisinternal
          AND t.tgfoid = protection_function::OID
          AND (t.tgtype & 1) = 1 AND (t.tgtype & 2) = 2 AND (t.tgtype & 8) = 8
    ) THEN
        RAISE EXCEPTION 'Preflight detenido: falta un trigger BEFORE ROW de protección para UPDATE o DELETE de rutas';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = actividad_table AND NOT t.tgisinternal
          AND t.tgfoid = protection_function::OID
          AND (t.tgtype & 1) = 1 AND (t.tgtype & 2) = 2 AND (t.tgtype & 4) = 4
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = actividad_table AND NOT t.tgisinternal
          AND t.tgfoid = protection_function::OID
          AND (t.tgtype & 1) = 1 AND (t.tgtype & 2) = 2 AND (t.tgtype & 16) = 16
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = actividad_table AND NOT t.tgisinternal
          AND t.tgfoid = protection_function::OID
          AND (t.tgtype & 1) = 1 AND (t.tgtype & 2) = 2 AND (t.tgtype & 8) = 8
    ) THEN
        RAISE EXCEPTION 'Preflight detenido: falta un trigger BEFORE ROW de protección para INSERT, UPDATE o DELETE de actividades';
    END IF;
END;
$preflight$;

ALTER TABLE sistema_riego.capacitacion_actividad
    ADD COLUMN IF NOT EXISTS configuracion JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE sistema_riego.capacitacion_ruta
    ADD COLUMN IF NOT EXISTS orden INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS id_ruta_previa INTEGER NULL;

DO $column_shape$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_attribute
        WHERE attrelid = 'sistema_riego.capacitacion_actividad'::REGCLASS
          AND attname = 'configuracion' AND NOT attisdropped
          AND atttypid = 'JSONB'::REGTYPE AND attnotnull AND atthasdef
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_attribute
        WHERE attrelid = 'sistema_riego.capacitacion_ruta'::REGCLASS
          AND attname = 'orden' AND NOT attisdropped
          AND atttypid = 'INTEGER'::REGTYPE AND attnotnull AND atthasdef
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_attribute
        WHERE attrelid = 'sistema_riego.capacitacion_ruta'::REGCLASS
          AND attname = 'id_ruta_previa' AND NOT attisdropped
          AND atttypid = 'INTEGER'::REGTYPE AND NOT attnotnull
    ) THEN
        RAISE EXCEPTION 'Columnas de capacitación con forma incompatible; no se continúa';
    END IF;
END;
$column_shape$;

-- La unicidad por versión se convierte en unicidad por versión y tramo.
-- La ruta existente recibe orden=1; su id y actividades no se actualizan.
ALTER TABLE sistema_riego.capacitacion_ruta
    DROP CONSTRAINT IF EXISTS uq_capacitacion_ruta_version;

DO $ruta_constraints$
DECLARE
    ruta_table REGCLASS := 'sistema_riego.capacitacion_ruta'::REGCLASS;
    version_att SMALLINT;
    orden_att SMALLINT;
    unique_def TEXT;
    id_ruta_att SMALLINT;
    fk_referenced_table OID;
    fk_columns SMALLINT;
    fk_source_att SMALLINT;
    fk_target_att SMALLINT;
    fk_delete_action "char";
    orden_check_def TEXT;
    predecessor_check_def TEXT;
BEGIN
    SELECT attnum INTO version_att FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'id_leccion_version' AND NOT attisdropped;
    SELECT attnum INTO orden_att FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'orden' AND NOT attisdropped;
    SELECT attnum INTO id_ruta_att FROM pg_attribute
    WHERE attrelid = ruta_table AND attname = 'id_ruta' AND NOT attisdropped;

    SELECT pg_get_constraintdef(oid) INTO unique_def
    FROM pg_constraint
    WHERE conrelid = ruta_table AND conname = 'uq_capacitacion_ruta_version_orden';
    IF unique_def IS NULL THEN
        ALTER TABLE sistema_riego.capacitacion_ruta
            ADD CONSTRAINT uq_capacitacion_ruta_version_orden
            UNIQUE (id_leccion_version, orden);
    ELSIF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = ruta_table AND c.conname = 'uq_capacitacion_ruta_version_orden'
          AND c.contype = 'u' AND CARDINALITY(c.conkey) = 2
          AND c.conkey[1] = version_att AND c.conkey[2] = orden_att
    ) THEN
        RAISE EXCEPTION 'La restricción uq_capacitacion_ruta_version_orden existe con otra definición';
    END IF;

    SELECT REGEXP_REPLACE(
             REGEXP_REPLACE(LOWER(pg_get_expr(c.conbin, c.conrelid)), '[[:space:]()"]', '', 'g'),
             '!=', '<>', 'g'
           )
      INTO orden_check_def
    FROM pg_constraint c
    WHERE c.conrelid = ruta_table AND c.conname = 'chk_capacitacion_ruta_orden_positivo';
    IF orden_check_def IS NULL THEN
        ALTER TABLE sistema_riego.capacitacion_ruta
            ADD CONSTRAINT chk_capacitacion_ruta_orden_positivo CHECK (orden > 0);
    ELSIF orden_check_def <> 'orden>0' THEN
        RAISE EXCEPTION 'La restricción chk_capacitacion_ruta_orden_positivo existe con otra definición';
    END IF;

    SELECT REGEXP_REPLACE(
             REGEXP_REPLACE(LOWER(pg_get_expr(c.conbin, c.conrelid)), '[[:space:]()"]', '', 'g'),
             '!=', '<>', 'g'
           )
      INTO predecessor_check_def
    FROM pg_constraint c
    WHERE c.conrelid = ruta_table AND c.conname = 'chk_capacitacion_ruta_no_autoprevia';
    IF predecessor_check_def IS NULL THEN
        ALTER TABLE sistema_riego.capacitacion_ruta
            ADD CONSTRAINT chk_capacitacion_ruta_no_autoprevia
            CHECK (id_ruta_previa IS NULL OR id_ruta_previa <> id_ruta);
    ELSIF predecessor_check_def <> 'id_ruta_previaisnullorid_ruta_previa<>id_ruta' THEN
        RAISE EXCEPTION 'La restricción chk_capacitacion_ruta_no_autoprevia existe con otra definición';
    END IF;

    -- No compares pg_get_constraintdef() textualmente: PostgreSQL puede
    -- omitir el nombre del esquema según search_path. Verifica la forma
    -- mediante el catálogo para que una segunda ejecución sea idempotente.
    SELECT c.confrelid, CARDINALITY(c.conkey), c.conkey[1], c.confkey[1],
           c.confdeltype
      INTO fk_referenced_table, fk_columns, fk_source_att, fk_target_att,
           fk_delete_action
    FROM pg_constraint c
    WHERE c.conrelid = ruta_table
      AND c.conname = 'fk_capacitacion_ruta_previa'
      AND c.contype = 'f';
    IF fk_referenced_table IS NOT NULL THEN
        IF fk_referenced_table <> ruta_table
           OR fk_columns IS DISTINCT FROM 1
           OR fk_source_att IS DISTINCT FROM (SELECT attnum FROM pg_attribute
                                              WHERE attrelid = ruta_table
                                                AND attname = 'id_ruta_previa'
                                                AND NOT attisdropped)
           OR fk_target_att IS DISTINCT FROM id_ruta_att
           OR fk_delete_action IS DISTINCT FROM 'r' THEN
            RAISE EXCEPTION 'La FK fk_capacitacion_ruta_previa existe con otra definición';
        END IF;
    ELSE
        ALTER TABLE sistema_riego.capacitacion_ruta
            ADD CONSTRAINT fk_capacitacion_ruta_previa
            FOREIGN KEY (id_ruta_previa)
            REFERENCES sistema_riego.capacitacion_ruta(id_ruta)
            ON DELETE RESTRICT NOT VALID;
    END IF;
    ALTER TABLE sistema_riego.capacitacion_ruta
        VALIDATE CONSTRAINT fk_capacitacion_ruta_previa;
END;
$ruta_constraints$;

CREATE INDEX IF NOT EXISTS idx_capacitacion_ruta_previa
    ON sistema_riego.capacitacion_ruta(id_ruta_previa)
    WHERE id_ruta_previa IS NOT NULL;

DO $index_shape$
DECLARE
    previous_att SMALLINT;
    index_valid BOOLEAN;
    index_ready BOOLEAN;
    index_unique BOOLEAN;
    index_columns SMALLINT;
    first_att SMALLINT;
    index_predicate TEXT;
BEGIN
    SELECT attnum INTO previous_att FROM pg_attribute
    WHERE attrelid = 'sistema_riego.capacitacion_ruta'::REGCLASS
      AND attname = 'id_ruta_previa' AND NOT attisdropped;
    SELECT i.indisvalid, i.indisready, i.indisunique, i.indnatts,
           i.indkey[0],
           REGEXP_REPLACE(
               REGEXP_REPLACE(LOWER(pg_get_expr(i.indpred, i.indrelid)), '[[:space:]()"]', '', 'g'),
               '!=', '<>', 'g'
           )
      INTO index_valid, index_ready, index_unique, index_columns,
           first_att, index_predicate
    FROM pg_index i
    WHERE i.indexrelid = TO_REGCLASS('sistema_riego.idx_capacitacion_ruta_previa');
    IF index_valid IS DISTINCT FROM TRUE OR index_ready IS DISTINCT FROM TRUE
       OR index_unique IS DISTINCT FROM FALSE OR index_columns IS DISTINCT FROM 1
       OR first_att IS DISTINCT FROM previous_att
       OR index_predicate IS DISTINCT FROM 'id_ruta_previaisnotnull' THEN
        RAISE EXCEPTION 'El índice idx_capacitacion_ruta_previa existe con una definición incompatible';
    END IF;
END;
$index_shape$;

-- Reemplaza solo el CHECK de tipo detectado por su columna, sin depender del
-- nombre que PostgreSQL asignó en Neon. La validación aborta y revierte todo si
-- alguna fila contiene un tipo distinto de los ocho soportados.
DO $tipo_constraint$
DECLARE
    actividad_table REGCLASS := 'sistema_riego.capacitacion_actividad'::REGCLASS;
    tipo_att SMALLINT;
    nombre_constraint TEXT;
    cantidad INTEGER;
    validada BOOLEAN;
    definicion TEXT;
    array_match TEXT[];
    literal_item TEXT;
    literal_match TEXT[];
    expression_shape TEXT;
    valores_tipo TEXT[];
    columnas_tipo_exactas BOOLEAN;
    tipos_legados TEXT[] := ARRAY['opcion_multiple', 'ordenar_pasos', 'verdadero_falso']::TEXT[];
    tipos_extensibles TEXT[] := ARRAY[
        'diagnostico_interactivo', 'minijuego_luz', 'minijuego_riego',
        'opcion_multiple', 'ordenar_pasos', 'simulacion_jardin',
        'simulacion_riego', 'verdadero_falso'
    ]::TEXT[];
BEGIN
    SELECT attnum INTO tipo_att FROM pg_attribute
    WHERE attrelid = actividad_table AND attname = 'tipo' AND NOT attisdropped;
    SELECT COUNT(*), MIN(c.conname::TEXT) INTO cantidad, nombre_constraint
    FROM pg_constraint c
    WHERE c.conrelid = actividad_table AND c.contype = 'c'
      AND tipo_att = ANY(c.conkey);
    IF cantidad <> 1 THEN
        RAISE EXCEPTION 'Se esperaba un único CHECK de tipo; se encontraron %', cantidad;
    END IF;

    SELECT c.convalidated, pg_get_expr(c.conbin, c.conrelid),
           CARDINALITY(c.conkey) = 1 AND c.conkey[1] = tipo_att
      INTO validada, definicion, columnas_tipo_exactas
    FROM pg_constraint c
    WHERE c.conrelid = actividad_table AND c.conname = nombre_constraint;
    IF columnas_tipo_exactas IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'El CHECK del tipo también depende de columnas inesperadas';
    END IF;
    -- Acepta solo la forma canónica tipo = ANY(ARRAY[...]). Separa el
    -- contenido del ARRAY antes de leer sus constantes; los casts SQL nunca
    -- se interpretan como valores permitidos. También rechaza AND/OR u otras
    -- expresiones que una extracción global de literales no distinguiría.
    array_match := REGEXP_MATCH(definicion, 'ARRAY\[([^][]*)\]');
    IF array_match IS NULL THEN
        RAISE EXCEPTION 'El CHECK de tipo no tiene la forma esperada tipo = ANY(ARRAY[...])';
    END IF;
    expression_shape := REPLACE(definicion, array_match[1], '__VALORES__');
    expression_shape := REGEXP_REPLACE(expression_shape,
        '::[[:space:]]*(pg_catalog\.)?(character varying|text)(\[\])?', '', 'gi');
    expression_shape := REGEXP_REPLACE(LOWER(expression_shape), '[[:space:]()"]', '', 'g');
    IF expression_shape <> 'tipo=anyarray[__valores__]' THEN
        RAISE EXCEPTION 'El CHECK de tipo contiene una expresión distinta de la lista permitida';
    END IF;
    valores_tipo := ARRAY[]::TEXT[];
    FOREACH literal_item IN ARRAY STRING_TO_ARRAY(array_match[1], ',') LOOP
        literal_match := REGEXP_MATCH(literal_item,
            '^[[:space:]]*''([a-z_]+)''[[:space:]]*(::[[:space:]]*(pg_catalog\.)?(character varying|text))?[[:space:]]*$');
        IF literal_match IS NULL THEN
            RAISE EXCEPTION 'El ARRAY del CHECK de tipo contiene un valor o cast inesperado';
        END IF;
        valores_tipo := ARRAY_APPEND(valores_tipo, literal_match[1]);
    END LOOP;
    SELECT ARRAY_AGG(valor ORDER BY valor COLLATE "C") INTO valores_tipo
    FROM UNNEST(valores_tipo) AS valores(valor);

    IF valores_tipo = tipos_extensibles THEN
        IF NOT validada OR nombre_constraint <> 'chk_capacitacion_actividad_tipo_extensible' THEN
            RAISE EXCEPTION 'El CHECK extensible de tipo existe con nombre inesperado o sin validar';
        END IF;
        -- Ya está aplicada: no se elimina ni se vuelve a crear al repetir la migración.
        RETURN;
    END IF;

    IF valores_tipo IS DISTINCT FROM tipos_legados THEN
        RAISE EXCEPTION 'El CHECK existente de tipo no coincide con el conjunto legado de tres tipos';
    END IF;
    IF nombre_constraint = 'chk_capacitacion_actividad_tipo_extensible' OR EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = actividad_table
          AND c.conname = 'chk_capacitacion_actividad_tipo_extensible'
          AND NOT (c.contype = 'c' AND tipo_att = ANY(c.conkey))
    ) THEN
        RAISE EXCEPTION 'El nombre chk_capacitacion_actividad_tipo_extensible ya está ocupado por una definición incompatible';
    END IF;

    EXECUTE FORMAT('ALTER TABLE sistema_riego.capacitacion_actividad DROP CONSTRAINT %I', nombre_constraint);
    ALTER TABLE sistema_riego.capacitacion_actividad
        ADD CONSTRAINT chk_capacitacion_actividad_tipo_extensible
        CHECK (tipo IN (
            'opcion_multiple', 'verdadero_falso', 'ordenar_pasos',
            'simulacion_riego', 'minijuego_riego', 'minijuego_luz',
            'diagnostico_interactivo', 'simulacion_jardin'
        )) NOT VALID;
    ALTER TABLE sistema_riego.capacitacion_actividad
        VALIDATE CONSTRAINT chk_capacitacion_actividad_tipo_extensible;
END;
$tipo_constraint$;

-- Se conservan sin cambios la función existente, los triggers y las seis
-- actividades publicadas. Insertar actividades en una ruta borrador sigue
-- serializándose con la publicación mediante la función actual.
COMMIT;
