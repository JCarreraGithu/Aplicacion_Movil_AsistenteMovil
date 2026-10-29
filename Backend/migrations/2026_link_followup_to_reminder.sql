-- Ejecutar solo en la base que contiene el esquema SISTEMA_RIEGO.
-- Mantiene el historial existente: los seguimientos antiguos quedan sin recordatorio asociado.
ALTER TABLE SISTEMA_RIEGO.seguimiento_caso
    ADD COLUMN IF NOT EXISTS id_recordatorio INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguimiento_caso_recordatorio'
          AND conrelid = 'SISTEMA_RIEGO.seguimiento_caso'::regclass
    ) THEN
        ALTER TABLE SISTEMA_RIEGO.seguimiento_caso
            ADD CONSTRAINT fk_seguimiento_caso_recordatorio
            FOREIGN KEY (id_recordatorio)
            REFERENCES SISTEMA_RIEGO.recordatorio_caso(id_recordatorio)
            ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_seguimiento_caso_recordatorio
    ON SISTEMA_RIEGO.seguimiento_caso(id_recordatorio)
    WHERE id_recordatorio IS NOT NULL;
