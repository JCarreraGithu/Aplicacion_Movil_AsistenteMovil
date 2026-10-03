-- Run against the database that contains the SISTEMA_RIEGO schema.
ALTER TABLE SISTEMA_RIEGO.caso_planta
    ADD COLUMN IF NOT EXISTS id_sector INTEGER
        REFERENCES SISTEMA_RIEGO.sector(id_sector);

UPDATE SISTEMA_RIEGO.caso_planta c
SET id_sector = p.id_sector
FROM SISTEMA_RIEGO.planta p
WHERE c.id_planta = p.id_planta
  AND c.id_sector IS NULL;

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.caso_tarea (
    id_tarea SERIAL PRIMARY KEY,
    id_caso INTEGER NOT NULL REFERENCES SISTEMA_RIEGO.caso_planta(id_caso) ON DELETE CASCADE,
    descripcion TEXT NOT NULL,
    fecha_limite TIMESTAMPTZ,
    completada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_completada TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.recordatorio_caso (
    id_recordatorio SERIAL PRIMARY KEY,
    id_caso INTEGER NOT NULL REFERENCES SISTEMA_RIEGO.caso_planta(id_caso) ON DELETE CASCADE,
    id_tarea INTEGER REFERENCES SISTEMA_RIEGO.caso_tarea(id_tarea) ON DELETE SET NULL,
    mensaje TEXT NOT NULL,
    fecha_recordatorio TIMESTAMPTZ NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_caso_tarea_caso
    ON SISTEMA_RIEGO.caso_tarea(id_caso, fecha_creacion);
CREATE INDEX IF NOT EXISTS idx_recordatorio_caso_vencimiento
    ON SISTEMA_RIEGO.recordatorio_caso(fecha_recordatorio)
    WHERE activo = TRUE;
