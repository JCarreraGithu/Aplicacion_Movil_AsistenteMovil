-- Ejecutar en la base que contiene el esquema SISTEMA_RIEGO.
-- Mantiene `actuador.estado` como estado operativo (ACTIVO/INACTIVO).
ALTER TABLE SISTEMA_RIEGO.actuador
    ADD COLUMN IF NOT EXISTS encendido BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE SISTEMA_RIEGO.actuador
    ADD COLUMN IF NOT EXISTS fecha_ultimo_cambio TIMESTAMPTZ;
