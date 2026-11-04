-- Seed idempotente y verificable. Crea SOLO una ruta sucesora en borrador.
-- Requiere 2026_add_capacitacion_minijuegos_extensibles.sql ya aplicada.
-- No publica contenido ni cambia las seis actividades de la ruta 1.
BEGIN;

-- Evita carreras entre dos ejecuciones simultáneas de este mismo seed.
SELECT pg_advisory_xact_lock(943714, 1);

CREATE TEMPORARY TABLE capacitacion_minijuegos_seed_esperado (
    orden INTEGER PRIMARY KEY,
    tipo VARCHAR(24) NOT NULL,
    titulo VARCHAR(140) NOT NULL,
    enunciado TEXT NOT NULL,
    icono VARCHAR(60) NOT NULL,
    opciones JSONB NOT NULL,
    respuesta_correcta JSONB NOT NULL,
    explicacion TEXT NOT NULL,
    xp INTEGER NOT NULL,
    configuracion JSONB NOT NULL
) ON COMMIT DROP;

INSERT INTO pg_temp.capacitacion_minijuegos_seed_esperado
    (orden, tipo, titulo, enunciado, icono, opciones,
     respuesta_correcta, explicacion, xp, configuracion)
VALUES
(1, 'simulacion_riego', 'Riego perfecto',
 'Aplica dosis virtuales pequeñas y detente cuando el indicador llegue al intervalo del escenario.',
 'water_drop', '[]'::jsonb,
 '{"version":1,"criterio":"humedad_objetivo"}'::jsonb,
 'El objetivo de este juego es practicar el equilibrio dentro de un escenario. No representa una medición real ni una receta para todas las plantas.',
 10,
 '{"version":1,"humedad_inicial":20,"objetivo_min":45,"objetivo_max":65,"incremento_por_unidad":2,"agua_max_por_accion":15,"agua_max_total":40,"max_acciones":8}'::jsonb),
(2, 'minijuego_luz', 'Sol o sombra',
 '¿Qué ubicación sigue la indicación de esta ficha?',
 'sunny',
 '[{"clave":"indirecta","texto":"Un lugar luminoso con luz filtrada"},{"clave":"directa","texto":"Sol directo intenso durante todo el día"},{"clave":"oscuro","texto":"Un sitio sin entrada de luz"}]'::jsonb,
 '"indirecta"'::jsonb,
 'En este escenario seguimos la indicación de la ficha. Las necesidades de luz cambian según la especie y el lugar; no hay una ubicación universal.',
 10,
 '{"version":1,"pista":"La tarjeta ficticia de cuidados indica luz brillante indirecta."}'::jsonb),
(3, 'diagnostico_interactivo', 'Detective de plantas',
 'Una hoja está caída y el sustrato sigue muy húmedo. ¿Qué paso es más cuidadoso?',
 'search',
 '[{"clave":"observar","texto":"Revisar drenaje y reunir más observaciones antes de concluir"},{"clave":"regar","texto":"Añadir agua inmediatamente"},{"clave":"diagnosticar","texto":"Afirmar una enfermedad específica solo por la hoja caída"}]'::jsonb,
 '"observar"'::jsonb,
 'Una señal aislada no confirma una causa. Revisa drenaje y reúne observaciones antes de decidir.',
 10,
 '{"version":1,"situacion":"En este caso ficticio, una hoja está caída y el sustrato continúa húmedo.","observaciones":["No se registran otras señales.","No se conoce la especie ni la historia reciente de cuidados."]}'::jsonb),
(4, 'simulacion_jardin', 'Jardín inteligente',
 'Elige una acción educativa para cada ficha virtual A–D.',
 'grid_view',
 '[{"clave":"regar","texto":"Regar virtual"},{"clave":"observar","texto":"Esperar y observar"},{"clave":"drenaje","texto":"Revisar drenaje"},{"clave":"lectura","texto":"Revisar lectura"}]'::jsonb,
 '{"A":"regar","B":"observar","C":"drenaje","D":"lectura"}'::jsonb,
 'Decide según cada pista. Son escenarios ficticios y no representan datos de sensores ni controlan actuadores.',
 10,
 '{"version":1,"sectores":[{"id":"A","pista":"La ficha ficticia indica humedad por debajo de su intervalo objetivo.","estado_dato":"baja"},{"id":"B","pista":"La lectura ficticia está dentro del intervalo indicado en esta ficha.","estado_dato":"objetivo"},{"id":"C","pista":"La lectura ficticia supera el intervalo de esta ficha.","estado_dato":"alta"},{"id":"D","pista":"Esta ficha no contiene una lectura para analizar.","estado_dato":"sin_lectura"}]}'::jsonb);

DO $seed$
DECLARE
    id_ruta_padre INTEGER;
    id_version INTEGER;
    id_ruta_nueva INTEGER;
    existentes INTEGER;
BEGIN
    SELECT r.id_ruta, r.id_leccion_version
      INTO id_ruta_padre, id_version
    FROM sistema_riego.capacitacion_ruta r
    WHERE r.id_ruta = 1
      AND r.id_leccion_version = 1
      AND r.slug = 'fundamentos-del-riego-v1'
      AND r.estado = 'publicada'
    FOR UPDATE;
    IF id_ruta_padre IS NULL THEN
        RAISE EXCEPTION 'Seed detenido: la ruta publicada 1/version 1 no coincide con lo verificado en Neon';
    END IF;

    SELECT COUNT(*) INTO existentes
    FROM sistema_riego.capacitacion_actividad
    WHERE id_ruta = id_ruta_padre;
    IF existentes <> 6 THEN
        RAISE EXCEPTION 'Seed detenido: la ruta previa debe conservar seis actividades; se encontraron %', existentes;
    END IF;

    SELECT r.id_ruta INTO id_ruta_nueva
    FROM sistema_riego.capacitacion_ruta r
    WHERE r.slug = 'fundamentos-riego-minijuegos-v1'
    FOR UPDATE;

    IF id_ruta_nueva IS NULL THEN
        IF EXISTS (
            SELECT 1 FROM sistema_riego.capacitacion_ruta r
            WHERE r.id_leccion_version = id_version AND r.orden = 2
        ) THEN
            RAISE EXCEPTION 'Seed detenido: ya existe otra ruta en el orden 2 de la versión 1';
        END IF;
        INSERT INTO sistema_riego.capacitacion_ruta
            (id_leccion_version, id_ruta_previa, orden, slug,
             titulo, descripcion, estado)
        VALUES
            (id_version, id_ruta_padre, 2, 'fundamentos-riego-minijuegos-v1',
             'Retos de jardinería inteligente',
             'Ruta de cuatro minijuegos virtuales; contenido pendiente de revisión editorial.',
             'borrador')
        RETURNING id_ruta INTO id_ruta_nueva;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM sistema_riego.capacitacion_ruta r
            WHERE r.id_ruta = id_ruta_nueva
              AND r.id_leccion_version = id_version
              AND r.id_ruta_previa = id_ruta_padre
              AND r.orden = 2
              AND r.slug = 'fundamentos-riego-minijuegos-v1'
              AND r.titulo = 'Retos de jardinería inteligente'
              AND r.descripcion = 'Ruta de cuatro minijuegos virtuales; contenido pendiente de revisión editorial.'
              AND r.estado = 'borrador'
              AND r.fecha_publicacion IS NULL
        ) THEN
            RAISE EXCEPTION 'Seed detenido: el slug esperado ya existe con relación, orden, contenido o estado diferente';
        END IF;
        IF EXISTS (
            SELECT 1 FROM sistema_riego.capacitacion_ruta r
            WHERE r.id_leccion_version = id_version AND r.orden = 2
              AND r.id_ruta <> id_ruta_nueva
        ) THEN
            RAISE EXCEPTION 'Seed detenido: hay una segunda ruta en conflicto para el orden 2';
        END IF;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM sistema_riego.capacitacion_actividad a
        LEFT JOIN pg_temp.capacitacion_minijuegos_seed_esperado e ON e.orden = a.orden
        WHERE a.id_ruta = id_ruta_nueva AND e.orden IS NULL
    ) THEN
        RAISE EXCEPTION 'Seed detenido: el borrador ya contiene actividades fuera de las cuatro esperadas';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM sistema_riego.capacitacion_actividad a
        JOIN pg_temp.capacitacion_minijuegos_seed_esperado e ON e.orden = a.orden
        WHERE a.id_ruta = id_ruta_nueva
          AND (a.tipo IS DISTINCT FROM e.tipo
            OR a.titulo IS DISTINCT FROM e.titulo
            OR a.enunciado IS DISTINCT FROM e.enunciado
            OR a.icono IS DISTINCT FROM e.icono
            OR a.opciones IS DISTINCT FROM e.opciones
            OR a.respuesta_correcta IS DISTINCT FROM e.respuesta_correcta
            OR a.explicacion IS DISTINCT FROM e.explicacion
            OR a.xp IS DISTINCT FROM e.xp
            OR a.configuracion IS DISTINCT FROM e.configuracion)
    ) THEN
        RAISE EXCEPTION 'Seed detenido: una actividad existente tiene contenido distinto al contrato esperado';
    END IF;

    -- Inserta solamente órdenes ausentes. Si ya existen, arriba se comparó todo
    -- el contenido para detenerse ante cualquier divergencia.
    INSERT INTO sistema_riego.capacitacion_actividad
        (id_ruta, orden, tipo, titulo, enunciado, icono, opciones,
         respuesta_correcta, explicacion, xp, configuracion)
    SELECT id_ruta_nueva, e.orden, e.tipo, e.titulo, e.enunciado, e.icono,
           e.opciones, e.respuesta_correcta, e.explicacion, e.xp, e.configuracion
    FROM pg_temp.capacitacion_minijuegos_seed_esperado e
    WHERE NOT EXISTS (
        SELECT 1 FROM sistema_riego.capacitacion_actividad a
        WHERE a.id_ruta = id_ruta_nueva AND a.orden = e.orden
    )
    ORDER BY e.orden;

    SELECT COUNT(*) INTO existentes
    FROM sistema_riego.capacitacion_actividad
    WHERE id_ruta = id_ruta_nueva;
    IF existentes <> 4 OR EXISTS (
        SELECT 1 FROM pg_temp.capacitacion_minijuegos_seed_esperado e
        WHERE NOT EXISTS (
            SELECT 1 FROM sistema_riego.capacitacion_actividad a
            WHERE a.id_ruta = id_ruta_nueva AND a.orden = e.orden
        )
    ) THEN
        RAISE EXCEPTION 'Seed detenido: la ruta borrador no terminó con exactamente cuatro actividades';
    END IF;

    IF (SELECT COUNT(*) FROM sistema_riego.capacitacion_actividad
        WHERE id_ruta = id_ruta_padre) <> 6 THEN
        RAISE EXCEPTION 'Seed detenido: cambió el número de actividades de la ruta publicada';
    END IF;
END;
$seed$;

-- Se deja el tramo y sus cuatro actividades en borrador.
COMMIT;
