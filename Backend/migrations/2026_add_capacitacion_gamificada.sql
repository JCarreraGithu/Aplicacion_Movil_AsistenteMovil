-- Ruta gamificada aditiva. Ejecutar manualmente y revisar antes de publicar.
-- Esta migración NO publica la ruta ni modifica lecciones, preguntas, progreso
-- o intentos existentes del módulo tradicional.
BEGIN;

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_ruta (
    id_ruta SERIAL PRIMARY KEY,
    id_leccion_version INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_leccion_version(id_leccion_version)
        ON DELETE RESTRICT,
    slug VARCHAR(140) NOT NULL UNIQUE,
    titulo VARCHAR(180) NOT NULL,
    descripcion TEXT NOT NULL,
    estado VARCHAR(12) NOT NULL DEFAULT 'borrador'
        CHECK (estado IN ('borrador', 'publicada', 'retirada')),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_publicacion TIMESTAMPTZ,
    CONSTRAINT uq_capacitacion_ruta_version UNIQUE (id_leccion_version),
    CONSTRAINT chk_capacitacion_ruta_publicacion CHECK (
        (estado = 'publicada' AND fecha_publicacion IS NOT NULL)
        OR (estado <> 'publicada' AND fecha_publicacion IS NULL)
    )
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_actividad (
    id_actividad SERIAL PRIMARY KEY,
    id_ruta INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.capacitacion_ruta(id_ruta) ON DELETE RESTRICT,
    orden INTEGER NOT NULL CHECK (orden > 0),
    tipo VARCHAR(24) NOT NULL
        CHECK (tipo IN ('opcion_multiple', 'verdadero_falso', 'ordenar_pasos')),
    titulo VARCHAR(140) NOT NULL,
    enunciado TEXT NOT NULL,
    icono VARCHAR(60) NOT NULL DEFAULT 'eco',
    opciones JSONB NOT NULL CHECK (jsonb_typeof(opciones) = 'array'),
    respuesta_correcta JSONB NOT NULL,
    explicacion TEXT NOT NULL,
    xp INTEGER NOT NULL DEFAULT 10 CHECK (xp BETWEEN 1 AND 100),
    CONSTRAINT uq_capacitacion_actividad_orden UNIQUE (id_ruta, orden),
    CONSTRAINT uq_capacitacion_actividad_ruta_id UNIQUE (id_ruta, id_actividad)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_actividad_intento (
    id_intento BIGSERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.usuario(id_usuario) ON DELETE CASCADE,
    id_ruta INTEGER NOT NULL,
    id_actividad INTEGER NOT NULL,
    clave_idempotencia VARCHAR(128) NOT NULL,
    huella_solicitud CHAR(64) NOT NULL,
    respuesta_usuario JSONB NOT NULL,
    correcta BOOLEAN NOT NULL,
    xp_otorgado INTEGER NOT NULL DEFAULT 0 CHECK (xp_otorgado >= 0),
    fecha_intento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_capacitacion_actividad_intento
        FOREIGN KEY (id_ruta, id_actividad)
        REFERENCES SISTEMA_RIEGO.capacitacion_actividad(id_ruta, id_actividad)
        ON DELETE RESTRICT,
    CONSTRAINT uq_capacitacion_actividad_idempotencia
        UNIQUE (id_usuario, clave_idempotencia)
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.capacitacion_actividad_progreso (
    id_usuario INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.usuario(id_usuario) ON DELETE CASCADE,
    id_ruta INTEGER NOT NULL,
    id_actividad INTEGER NOT NULL,
    intentos INTEGER NOT NULL DEFAULT 0 CHECK (intentos >= 0),
    completada BOOLEAN NOT NULL DEFAULT FALSE,
    xp_ganado INTEGER NOT NULL DEFAULT 0 CHECK (xp_ganado >= 0),
    fecha_completado TIMESTAMPTZ,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_actividad),
    CONSTRAINT fk_capacitacion_actividad_progreso
        FOREIGN KEY (id_ruta, id_actividad)
        REFERENCES SISTEMA_RIEGO.capacitacion_actividad(id_ruta, id_actividad)
        ON DELETE RESTRICT,
    CONSTRAINT chk_capacitacion_actividad_completada CHECK (
        (completada AND fecha_completado IS NOT NULL)
        OR (NOT completada AND fecha_completado IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_capacitacion_ruta_leccion
    ON SISTEMA_RIEGO.capacitacion_ruta(id_leccion_version, estado);
CREATE INDEX IF NOT EXISTS idx_capacitacion_actividad_ruta_orden
    ON SISTEMA_RIEGO.capacitacion_actividad(id_ruta, orden);
CREATE INDEX IF NOT EXISTS idx_capacitacion_actividad_intento_usuario
    ON SISTEMA_RIEGO.capacitacion_actividad_intento(id_usuario, fecha_intento DESC);
CREATE INDEX IF NOT EXISTS idx_capacitacion_actividad_progreso_usuario_ruta
    ON SISTEMA_RIEGO.capacitacion_actividad_progreso(id_usuario, id_ruta);

-- Bloquea modificaciones de etapas y actividades publicadas. La fila de ruta
-- serializa los cambios de actividades con el cambio borrador -> publicada.
CREATE OR REPLACE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_ruta_publicada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    id_ruta_objetivo INTEGER;
    estado_ruta VARCHAR(12);
BEGIN
    IF TG_TABLE_NAME = 'capacitacion_ruta' THEN
        IF OLD.estado = 'publicada' THEN
            RAISE EXCEPTION 'Las rutas publicadas son inmutables';
        END IF;
        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        id_ruta_objetivo := NEW.id_ruta;
    ELSIF TG_OP = 'DELETE' THEN
        id_ruta_objetivo := OLD.id_ruta;
    ELSE
        IF OLD.id_ruta <> NEW.id_ruta THEN
            RAISE EXCEPTION 'No se puede mover una actividad entre rutas';
        END IF;
        id_ruta_objetivo := OLD.id_ruta;
    END IF;

    SELECT estado INTO estado_ruta
    FROM SISTEMA_RIEGO.capacitacion_ruta
    WHERE id_ruta = id_ruta_objetivo
    FOR UPDATE;

    IF estado_ruta = 'publicada' THEN
        RAISE EXCEPTION 'No se pueden modificar actividades de una ruta publicada';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_capacitacion_ruta_inmutable' AND tgrelid = 'SISTEMA_RIEGO.capacitacion_ruta'::regclass) THEN
        CREATE TRIGGER trg_capacitacion_ruta_inmutable
        BEFORE UPDATE OR DELETE ON SISTEMA_RIEGO.capacitacion_ruta
        FOR EACH ROW EXECUTE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_ruta_publicada();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_capacitacion_actividad_inmutable' AND tgrelid = 'SISTEMA_RIEGO.capacitacion_actividad'::regclass) THEN
        CREATE TRIGGER trg_capacitacion_actividad_inmutable
        BEFORE INSERT OR UPDATE OR DELETE ON SISTEMA_RIEGO.capacitacion_actividad
        FOR EACH ROW EXECUTE FUNCTION SISTEMA_RIEGO.proteger_capacitacion_ruta_publicada();
    END IF;
END;
$$;

-- Ruta piloto en borrador, ligada únicamente a la versión publicada vigente.
-- Si todavía no existe una versión publicada, no se inserta contenido.
WITH leccion_publicada AS (
    SELECT v.id_leccion_version, v.numero_version
    FROM SISTEMA_RIEGO.capacitacion_leccion l
    JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
    JOIN LATERAL (
        SELECT v1.id_leccion_version, v1.numero_version
        FROM SISTEMA_RIEGO.capacitacion_leccion_version v1
        WHERE v1.id_leccion = l.id_leccion AND v1.estado = 'publicada'
        ORDER BY v1.numero_version DESC LIMIT 1
    ) v ON TRUE
    WHERE l.slug = 'cuando-debemos-regar-una-planta'
      AND m.slug = 'fundamentos-del-riego' AND m.publicado = TRUE
)
INSERT INTO SISTEMA_RIEGO.capacitacion_ruta
    (id_leccion_version, slug, titulo, descripcion, estado)
SELECT id_leccion_version,
       'fundamentos-del-riego-v' || numero_version,
       'Camino del riego consciente',
       'Desafíos cortos para observar el suelo y el contexto antes de decidir.',
       'borrador'
FROM leccion_publicada
ON CONFLICT (id_leccion_version) DO NOTHING;

WITH ruta AS (
    SELECT r.id_ruta
    FROM SISTEMA_RIEGO.capacitacion_ruta r
    JOIN SISTEMA_RIEGO.capacitacion_leccion_version v
      ON v.id_leccion_version = r.id_leccion_version
    JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_leccion = v.id_leccion
    WHERE l.slug = 'cuando-debemos-regar-una-planta'
      AND r.estado = 'borrador'
    ORDER BY v.numero_version DESC LIMIT 1
), actividades(orden, tipo, titulo, enunciado, icono, opciones, respuesta_correcta, explicacion, xp) AS (
    VALUES
    (1, 'opcion_multiple', 'Observa antes de actuar',
     'Antes de regar por rutina, ¿qué conviene comprobar?', 'search',
     '[{"clave":"a","texto":"La humedad en la zona de raíces y el contexto de la planta"},{"clave":"b","texto":"Regar todas las plantas cada día"},{"clave":"c","texto":"Guiarse solo por una hoja marchita"}]'::jsonb,
     '"a"'::jsonb,
     'No hay una frecuencia universal: observa el suelo y considera especie, raíces y condiciones de cultivo.', 10),
    (2, 'verdadero_falso', 'Lee la humedad',
     'Una lectura aislada del sensor describe por sí sola toda la zona de raíces.', 'water_drop',
     '[{"clave":"verdadero","texto":"Verdadero"},{"clave":"falso","texto":"Falso"}]'::jsonb,
     '"falso"'::jsonb,
     'La ubicación y calibración del sensor y la profundidad de raíces importan; una lectura puntual no representa necesariamente todo el suelo.', 10),
    (3, 'opcion_multiple', 'Detecta el exceso',
     'La tierra permanece saturada. ¿Qué efecto puede ocurrir en las raíces?', 'air',
     '[{"clave":"a","texto":"Menos oxígeno disponible"},{"clave":"b","texto":"Más luz en las hojas"},{"clave":"c","texto":"Un aumento automático de nutrientes"}]'::jsonb,
     '"a"'::jsonb,
     'Cuando los poros permanecen llenos de agua, disminuye el aire disponible para las raíces; revisa también el drenaje.', 10),
    (4, 'ordenar_pasos', 'Arma una decisión cuidadosa',
     'Ordena estos pasos antes de decidir si hace falta agua.', 'sort',
     '[{"clave":"contexto","texto":"Considerar especie, raíces y ambiente"},{"clave":"suelo","texto":"Comprobar la humedad del suelo"},{"clave":"decidir","texto":"Decidir si corresponde regar"}]'::jsonb,
     '["suelo","contexto","decidir"]'::jsonb,
     'Primero observa el suelo; después interpreta esa señal con el contexto de la planta y entonces decide. El orden sirve como guía, no como regla universal.', 15),
    (5, 'opcion_multiple', 'Responde a la falta de agua',
     'Una planta está marchita, pero la tierra sigue húmeda. ¿Qué haces?', 'eco',
     '[{"clave":"a","texto":"Añado agua inmediatamente"},{"clave":"b","texto":"Reviso drenaje y otras condiciones antes de concluir"},{"clave":"c","texto":"Concluyo que el sensor está averiado"}]'::jsonb,
     '"b"'::jsonb,
     'La marchitez sola no confirma falta de agua. El calor puede causar síntomas temporales y el exceso también afecta las raíces.', 10),
    (6, 'verdadero_falso', 'Mira el ambiente',
     'Temperatura, viento, radiación y lluvia reciente pueden cambiar la rapidez con que se pierde o queda disponible el agua.', 'sunny',
     '[{"clave":"verdadero","texto":"Verdadero"},{"clave":"falso","texto":"Falso"}]'::jsonb,
     '"verdadero"'::jsonb,
     'Las condiciones ambientales influyen junto con suelo, recipiente, especie, tamaño y etapa de crecimiento.', 10)
)
INSERT INTO SISTEMA_RIEGO.capacitacion_actividad
    (id_ruta, orden, tipo, titulo, enunciado, icono, opciones,
     respuesta_correcta, explicacion, xp)
SELECT ruta.id_ruta, a.orden, a.tipo, a.titulo, a.enunciado, a.icono,
       a.opciones, a.respuesta_correcta, a.explicacion, a.xp
FROM ruta CROSS JOIN actividades a
ON CONFLICT (id_ruta, orden) DO NOTHING;

COMMIT;
