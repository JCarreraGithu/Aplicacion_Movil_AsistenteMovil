-- Infraestructura inicial para el módulo educativo.
-- Aditiva e idempotente. No ejecutar automáticamente ni contra producción.
-- El contenido piloto se inserta como borrador y requiere revisión editorial.
BEGIN;

CREATE SCHEMA IF NOT EXISTS SISTEMA_RIEGO;

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_modulo (
    id_modulo SERIAL PRIMARY KEY,
    slug VARCHAR(100) NOT NULL UNIQUE,
    titulo VARCHAR(180) NOT NULL,
    descripcion TEXT NOT NULL,
    orden INTEGER NOT NULL CHECK (orden > 0),
    publicado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_leccion (
    id_leccion SERIAL PRIMARY KEY,
    id_modulo INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_modulo(id_modulo) ON DELETE RESTRICT,
    slug VARCHAR(120) NOT NULL UNIQUE,
    orden INTEGER NOT NULL CHECK (orden > 0),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_capacitacion_leccion_modulo_orden UNIQUE (id_modulo, orden),
    CONSTRAINT uq_capacitacion_leccion_modulo_id UNIQUE (id_modulo, id_leccion)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_leccion_version (
    id_leccion_version SERIAL PRIMARY KEY,
    id_leccion INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion(id_leccion) ON DELETE RESTRICT,
    numero_version INTEGER NOT NULL CHECK (numero_version > 0),
    titulo VARCHAR(180) NOT NULL,
    objetivo TEXT NOT NULL,
    contenido JSONB NOT NULL CHECK (jsonb_typeof(contenido) = 'object'),
    calificacion_aprobacion NUMERIC(5,2) NOT NULL DEFAULT 70
        CHECK (calificacion_aprobacion BETWEEN 0 AND 100),
    estado VARCHAR(12) NOT NULL DEFAULT 'borrador'
        CHECK (estado IN ('borrador', 'publicada', 'retirada')),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_publicacion TIMESTAMPTZ,
    CONSTRAINT uq_capacitacion_version_numero UNIQUE (id_leccion, numero_version),
    CONSTRAINT uq_capacitacion_version_leccion_id UNIQUE (id_leccion, id_leccion_version),
    CONSTRAINT chk_capacitacion_fecha_publicacion CHECK (
        (estado = 'publicada' AND fecha_publicacion IS NOT NULL)
        OR (estado <> 'publicada')
    )
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_pregunta_version (
    id_pregunta_version SERIAL PRIMARY KEY,
    id_leccion_version INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion_version(id_leccion_version) ON DELETE RESTRICT,
    orden INTEGER NOT NULL CHECK (orden > 0),
    enunciado TEXT NOT NULL,
    tipo VARCHAR(30) NOT NULL DEFAULT 'opcion_multiple'
        CHECK (tipo IN ('opcion_multiple', 'verdadero_falso')),
    opciones JSONB NOT NULL CHECK (jsonb_typeof(opciones) = 'array'),
    respuesta_correcta JSONB NOT NULL,
    explicacion TEXT NOT NULL,
    CONSTRAINT uq_capacitacion_pregunta_orden UNIQUE (id_leccion_version, orden),
    CONSTRAINT uq_capacitacion_pregunta_version_id UNIQUE (id_leccion_version, id_pregunta_version)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_fuente (
    id_fuente SERIAL PRIMARY KEY,
    id_leccion_version INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion_version(id_leccion_version) ON DELETE RESTRICT,
    titulo VARCHAR(250) NOT NULL,
    entidad VARCHAR(180) NOT NULL,
    url TEXT NOT NULL,
    fecha_consulta DATE,
    nota_editorial TEXT,
    CONSTRAINT uq_capacitacion_fuente_url UNIQUE (id_leccion_version, url)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_intento (
    id_intento BIGSERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.usuario(id_usuario) ON DELETE CASCADE,
    id_leccion INTEGER NOT NULL,
    id_leccion_version INTEGER NOT NULL,
    clave_idempotencia VARCHAR(128) NOT NULL,
    huella_solicitud CHAR(64) NOT NULL,
    respuestas_correctas INTEGER NOT NULL CHECK (respuestas_correctas >= 0),
    total_preguntas INTEGER NOT NULL CHECK (total_preguntas > 0),
    calificacion NUMERIC(5,2) NOT NULL CHECK (calificacion BETWEEN 0 AND 100),
    aprobado BOOLEAN NOT NULL,
    fecha_intento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_capacitacion_intento_version
        FOREIGN KEY (id_leccion, id_leccion_version)
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion_version(id_leccion, id_leccion_version)
        ON DELETE RESTRICT,
    CONSTRAINT uq_capacitacion_intento_idempotencia UNIQUE (id_usuario, clave_idempotencia),
    CONSTRAINT uq_capacitacion_intento_version_id UNIQUE (id_intento, id_leccion_version)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_respuesta (
    id_respuesta BIGSERIAL PRIMARY KEY,
    id_intento BIGINT NOT NULL,
    id_leccion_version INTEGER NOT NULL,
    id_pregunta_version INTEGER NOT NULL,
    respuesta_usuario JSONB NOT NULL,
    correcta BOOLEAN NOT NULL,
    CONSTRAINT fk_capacitacion_respuesta_intento
        FOREIGN KEY (id_intento, id_leccion_version)
        REFERENCES SISTEMA_RIEGO.capacitacion_intento(id_intento, id_leccion_version)
        ON DELETE CASCADE,
    CONSTRAINT fk_capacitacion_respuesta_pregunta
        FOREIGN KEY (id_leccion_version, id_pregunta_version)
        REFERENCES SISTEMA_RIEGO.capacitacion_pregunta_version(id_leccion_version, id_pregunta_version)
        ON DELETE RESTRICT,
    CONSTRAINT uq_capacitacion_respuesta_pregunta UNIQUE (id_intento, id_pregunta_version)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_progreso (
    id_progreso BIGSERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.usuario(id_usuario) ON DELETE CASCADE,
    id_leccion INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion(id_leccion) ON DELETE CASCADE,
    id_leccion_version INTEGER NOT NULL,
    estado VARCHAR(14) NOT NULL DEFAULT 'no_iniciado'
        CHECK (estado IN ('no_iniciado', 'en_progreso', 'completado')),
    ultima_calificacion NUMERIC(5,2)
        CHECK (ultima_calificacion BETWEEN 0 AND 100),
    fecha_inicio TIMESTAMPTZ,
    fecha_completado TIMESTAMPTZ,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_capacitacion_progreso_version
        FOREIGN KEY (id_leccion, id_leccion_version)
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion_version(id_leccion, id_leccion_version)
        ON DELETE RESTRICT,
    CONSTRAINT uq_capacitacion_progreso_usuario_leccion UNIQUE (id_usuario, id_leccion),
    CONSTRAINT chk_capacitacion_progreso_completado CHECK (
        (estado = 'completado' AND fecha_completado IS NOT NULL)
        OR estado <> 'completado'
    )
);

CREATE INDEX IF NOT EXISTS idx_capacitacion_leccion_modulo_orden
    ON SISTEMA_RIEGO.capacitacion_leccion(id_modulo, orden);
CREATE INDEX IF NOT EXISTS idx_capacitacion_version_publicada
    ON SISTEMA_RIEGO.capacitacion_leccion_version(id_leccion, numero_version DESC)
    WHERE estado = 'publicada';
CREATE INDEX IF NOT EXISTS idx_capacitacion_pregunta_version_orden
    ON SISTEMA_RIEGO.capacitacion_pregunta_version(id_leccion_version, orden);
CREATE INDEX IF NOT EXISTS idx_capacitacion_intento_usuario_fecha
    ON SISTEMA_RIEGO.capacitacion_intento(id_usuario, fecha_intento DESC);
CREATE INDEX IF NOT EXISTS idx_capacitacion_intento_leccion_version
    ON SISTEMA_RIEGO.capacitacion_intento(id_leccion, id_leccion_version);
CREATE INDEX IF NOT EXISTS idx_capacitacion_respuesta_intento
    ON SISTEMA_RIEGO.capacitacion_respuesta(id_intento);
CREATE INDEX IF NOT EXISTS idx_capacitacion_progreso_usuario_estado
    ON SISTEMA_RIEGO.capacitacion_progreso(id_usuario, estado);

-- Impide modificar/eliminar una versión publicada y modificar sus preguntas/fuentes.
CREATE OR REPLACE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_publicada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    ids_version INTEGER[];
    version_bloqueada RECORD;
BEGIN
    IF TG_TABLE_NAME = 'capacitacion_leccion_version' THEN
        IF OLD.estado = 'publicada' THEN
            RAISE EXCEPTION 'Las versiones publicadas de capacitación son inmutables';
        END IF;
        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        ids_version := ARRAY[NEW.id_leccion_version];
    ELSIF TG_OP = 'DELETE' THEN
        ids_version := ARRAY[OLD.id_leccion_version];
    ELSE
        ids_version := ARRAY[OLD.id_leccion_version, NEW.id_leccion_version];
    END IF;

    -- El mismo bloqueo usado al publicar una versión serializa cualquier cambio
    -- de sus preguntas/fuentes. El orden determinista evita deadlocks al mover filas.
    SELECT array_agg(DISTINCT id_version ORDER BY id_version)
    INTO ids_version
    FROM unnest(ids_version) AS versiones(id_version);

    FOR version_bloqueada IN
        SELECT id_leccion_version, estado
        FROM SISTEMA_RIEGO.capacitacion_leccion_version
        WHERE id_leccion_version = ANY(ids_version)
        ORDER BY id_leccion_version
        FOR UPDATE
    LOOP
        IF version_bloqueada.estado = 'publicada' THEN
            RAISE EXCEPTION 'No se pueden modificar preguntas o fuentes de una versión publicada';
        END IF;
    END LOOP;

    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_capacitacion_version_inmutable' AND tgrelid = 'SISTEMA_RIEGO.capacitacion_leccion_version'::regclass) THEN
        CREATE TRIGGER trg_capacitacion_version_inmutable
        BEFORE UPDATE OR DELETE ON SISTEMA_RIEGO.capacitacion_leccion_version
        FOR EACH ROW EXECUTE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_publicada();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_capacitacion_pregunta_inmutable' AND tgrelid = 'SISTEMA_RIEGO.capacitacion_pregunta_version'::regclass) THEN
        CREATE TRIGGER trg_capacitacion_pregunta_inmutable
        BEFORE INSERT OR UPDATE OR DELETE ON SISTEMA_RIEGO.capacitacion_pregunta_version
        FOR EACH ROW EXECUTE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_publicada();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_capacitacion_fuente_inmutable' AND tgrelid = 'SISTEMA_RIEGO.capacitacion_fuente'::regclass) THEN
        CREATE TRIGGER trg_capacitacion_fuente_inmutable
        BEFORE INSERT OR UPDATE OR DELETE ON SISTEMA_RIEGO.capacitacion_fuente
        FOR EACH ROW EXECUTE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_publicada();
    END IF;
END;
$$;

-- Piloto editorial. Se inserta como borrador: no aparece en los endpoints públicos.
INSERT INTO SISTEMA_RIEGO.capacitacion_modulo
    (slug, titulo, descripcion, orden, publicado)
VALUES
    ('fundamentos-del-riego', 'Fundamentos del riego',
     'Principios para observar el suelo y decidir cuándo revisar la necesidad de agua.', 1, FALSE)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO SISTEMA_RIEGO.capacitacion_leccion (id_modulo, slug, orden)
SELECT id_modulo, 'cuando-debemos-regar-una-planta', 1
FROM SISTEMA_RIEGO.capacitacion_modulo
WHERE slug = 'fundamentos-del-riego'
ON CONFLICT (slug) DO NOTHING;

INSERT INTO SISTEMA_RIEGO.capacitacion_leccion_version
    (id_leccion, numero_version, titulo, objetivo, contenido, estado)
SELECT l.id_leccion, 1, '¿Cuándo debemos regar una planta?',
       'Relacionar la observación del suelo y las condiciones de cultivo con la necesidad de revisar el riego.',
       '{
         "secciones": [
           {"titulo":"Observar antes de regar","texto":"No existe una frecuencia universal. Revisa la humedad cerca de la zona de raíces y observa la especie, su etapa de crecimiento, el tipo y profundidad del suelo, el tamaño de la maceta, el drenaje y el clima reciente. Las hojas por sí solas no confirman falta de agua."},
           {"titulo":"Interpretar la humedad del suelo","texto":"El suelo almacena agua en sus poros. Una comprobación manual superficial puede orientar en macetas, pero debe interpretarse según el sustrato y la profundidad de las raíces. Un sensor también requiere conocer qué mide, dónde está instalado y si está calibrado para ese suelo; una lectura aislada no describe necesariamente toda la zona radicular."},
           {"titulo":"Factores que cambian la frecuencia","texto":"Textura y estructura del suelo, drenaje, volumen de la maceta, especie, tamaño y etapa de la planta, raíces, temperatura, viento, radiación, humedad ambiental y lluvia modifican la pérdida o disponibilidad de agua. Arena suele drenar más rápido; arcilla retiene agua por más tiempo y puede requerir aplicación lenta."},
           {"titulo":"Exceso y falta de agua","texto":"El encharcamiento reduce el aire disponible para las raíces y puede dañarlas; amarillamiento o marchitez también pueden tener otras causas. La falta de agua reduce el agua disponible y puede causar marchitez, pero el calor puede producir síntomas temporales. Comprueba la humedad del suelo y el drenaje antes de atribuir una causa."},
           {"titulo":"Ejemplos prácticos","texto":"Ejemplo 1: una maceta pequeña en un día cálido y ventoso puede secarse antes que una maceta grande a la sombra; comprueba el sustrato antes de decidir. Ejemplo 2: si el suelo permanece saturado, revisa drenaje y frecuencia en vez de añadir agua por rutina. Ejemplo 3: ante una planta marchita con suelo húmedo, no concluyas automáticamente que necesita más riego; revisa otras condiciones y busca orientación específica para la especie."}
         ],
         "estado_editorial":"BORRADOR_REQUIERE_REVISION_TECNICA"
       }'::jsonb, 'borrador'
FROM SISTEMA_RIEGO.capacitacion_leccion l
WHERE l.slug = 'cuando-debemos-regar-una-planta'
ON CONFLICT (id_leccion, numero_version) DO NOTHING;

INSERT INTO SISTEMA_RIEGO.capacitacion_pregunta_version
    (id_leccion_version, orden, enunciado, tipo, opciones, respuesta_correcta, explicacion)
SELECT v.id_leccion_version, q.orden, q.enunciado, q.tipo, q.opciones::jsonb,
       q.respuesta_correcta::jsonb, q.explicacion
FROM SISTEMA_RIEGO.capacitacion_leccion_version v
CROSS JOIN (VALUES
 (1, '¿Qué conviene hacer antes de regar por rutina?', 'opcion_multiple',
  '[{"clave":"a","texto":"Comprobar la humedad en la zona de raíces y considerar el contexto de la planta"},{"clave":"b","texto":"Regar todas las plantas cada día a la misma hora"},{"clave":"c","texto":"Usar únicamente el color de una hoja"}]',
  '"a"', 'La observación del suelo y las condiciones de cultivo ofrecen más contexto que un horario universal o un síntoma aislado.'),
 (2, '¿La frecuencia de riego depende solamente de la especie?', 'verdadero_falso',
  '[{"clave":"verdadero","texto":"Verdadero"},{"clave":"falso","texto":"Falso"}]',
  '"falso"', 'También influyen el suelo, drenaje, raíces, recipiente y clima.'),
 (3, 'Un suelo que permanece saturado puede reducir principalmente…', 'opcion_multiple',
  '[{"clave":"a","texto":"El oxígeno disponible para las raíces"},{"clave":"b","texto":"La cantidad de luz que recibe la planta"},{"clave":"c","texto":"La temperatura del aire"}]',
  '"a"', 'Al llenarse los poros de agua, queda menos aire disponible en la zona radicular.'),
 (4, 'Una planta marchita con suelo húmedo demuestra que necesita más agua.', 'verdadero_falso',
  '[{"clave":"verdadero","texto":"Verdadero"},{"clave":"falso","texto":"Falso"}]',
  '"falso"', 'La marchitez no identifica por sí sola la causa; se debe revisar humedad, drenaje y otras condiciones.')
) AS q(orden, enunciado, tipo, opciones, respuesta_correcta, explicacion)
WHERE v.numero_version = 1
  AND v.estado = 'borrador'
  AND v.id_leccion = (SELECT id_leccion FROM SISTEMA_RIEGO.capacitacion_leccion WHERE slug = 'cuando-debemos-regar-una-planta')
ON CONFLICT (id_leccion_version, orden) DO NOTHING;

INSERT INTO SISTEMA_RIEGO.capacitacion_fuente
    (id_leccion_version, titulo, entidad, url, nota_editorial)
SELECT v.id_leccion_version, f.titulo, f.entidad, f.url, f.nota
FROM SISTEMA_RIEGO.capacitacion_leccion_version v
CROSS JOIN (VALUES
 ('Watering Basics', 'Oregon State University Extension Service', 'https://extension.oregonstate.edu/imported-publication/watering-basics', 'Referencia práctica para observar humedad, diferencias entre sustratos y señales no concluyentes.'),
 ('Soil moisture monitoring to support irrigation scheduling', 'Oregon State University Extension Service', 'https://extension.oregonstate.edu/catalog/em-9868-soil-moisture-monitoring-support-irrigation-scheduling', 'Guía técnica revisada sobre medición de humedad, zona radicular, suelo y clima.'),
 ('Overwatering', 'Utah State University Extension', 'https://extension.usu.edu/planthealth/ipm/ornamental-pest-guide/abiotic/overwatering', 'Referencia sobre saturación, oxígeno radicular y síntomas que requieren interpretación contextual.')
) AS f(titulo, entidad, url, nota)
WHERE v.numero_version = 1
  AND v.id_leccion = (SELECT id_leccion FROM SISTEMA_RIEGO.capacitacion_leccion WHERE slug = 'cuando-debemos-regar-una-planta')
ON CONFLICT (id_leccion_version, url) DO NOTHING;

COMMIT;
