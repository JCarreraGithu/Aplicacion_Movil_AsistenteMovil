-- FASE 2: habilitación de esquema, SIN contenido ni publicación automática.
-- REVISAR Y APLICAR MANUALMENTE. No ejecutar la propuesta genérica de fase 1
-- como requisito: esta migración funciona directamente con el esquema original.
BEGIN;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    ADD COLUMN IF NOT EXISTS configuracion JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Estos nombres corresponden al esquema original y a la propuesta de fase 1.
-- Si el esquema usa otro nombre, detenerse y revisar, sin quitar otras reglas.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'SISTEMA_RIEGO.capacitacion_actividad'::regclass
          AND conname IN ('capacitacion_actividad_tipo_check', 'chk_capacitacion_actividad_tipo')
    ) THEN
        RAISE EXCEPTION 'No se encontró la restricción de tipo esperada; revisar el esquema';
    END IF;
END;
$$;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    DROP CONSTRAINT IF EXISTS capacitacion_actividad_tipo_check,
    DROP CONSTRAINT IF EXISTS chk_capacitacion_actividad_tipo;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    ADD CONSTRAINT chk_capacitacion_actividad_tipo CHECK (tipo IN (
        'opcion_multiple', 'verdadero_falso', 'ordenar_pasos', 'simulacion_riego',
        -- Compatibilidad si alguien aplicó la propuesta genérica de fase 1.
        'minijuego_riego', 'minijuego_luz', 'diagnostico_interactivo'
    ));

-- No se actualizan rutas, versiones publicadas, actividades, intentos ni XP.
COMMIT;
