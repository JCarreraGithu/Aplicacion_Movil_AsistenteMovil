-- PROPUESTA PARA UNA ETAPA FUTURA. NO APLICADA.
-- Revisar el nombre real de las restricciones en la base antes de ejecutar.
-- Amplía el formato de configuración sin reescribir filas ni intentos actuales.
BEGIN;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    ADD COLUMN IF NOT EXISTS configuracion JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    DROP CONSTRAINT IF EXISTS capacitacion_actividad_tipo_check,
    DROP CONSTRAINT IF EXISTS chk_capacitacion_actividad_tipo;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    ADD CONSTRAINT chk_capacitacion_actividad_tipo
    CHECK (tipo IN (
        'opcion_multiple',
        'verdadero_falso',
        'ordenar_pasos',
        'simulacion_riego',
        'minijuego_riego',
        'minijuego_luz',
        'diagnostico_interactivo'
    )) NOT VALID;

ALTER TABLE SISTEMA_RIEGO.capacitacion_actividad
    VALIDATE CONSTRAINT chk_capacitacion_actividad_tipo;

COMMIT;
