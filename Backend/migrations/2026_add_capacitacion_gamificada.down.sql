-- Reversión manual de 2026_add_capacitacion_gamificada.sql.
-- ADVERTENCIA: elimina intentos, XP y progreso de la ruta gamificada.
-- No ejecutar si esos datos deben conservarse.
BEGIN;

DROP TRIGGER IF EXISTS trg_capacitacion_actividad_inmutable
    ON SISTEMA_RIEGO.capacitacion_actividad;
DROP TRIGGER IF EXISTS trg_capacitacion_ruta_inmutable
    ON SISTEMA_RIEGO.capacitacion_ruta;
DROP FUNCTION IF EXISTS SISTEMA_RIEGO.proteger_capacitacion_ruta_publicada();

DROP TABLE IF EXISTS SISTEMA_RIEGO.capacitacion_actividad_progreso;
DROP TABLE IF EXISTS SISTEMA_RIEGO.capacitacion_actividad_intento;
DROP TABLE IF EXISTS SISTEMA_RIEGO.capacitacion_actividad;
DROP TABLE IF EXISTS SISTEMA_RIEGO.capacitacion_ruta;

COMMIT;
