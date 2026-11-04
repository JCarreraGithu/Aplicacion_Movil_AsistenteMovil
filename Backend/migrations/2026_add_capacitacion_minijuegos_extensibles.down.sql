-- Reversión ESTRUCTURAL solo si la ruta sucesora nunca se creó y no hay tipos
-- ni configuración de minijuegos. Nunca elimina intentos/progreso ni reemplaza
-- la función/triggers de inmutabilidad existentes.
-- La columna configuracion se conserva intencionalmente: tras una migración
-- aplicada no se puede distinguir con seguridad si otro cambio ya la utiliza.
BEGIN;

DO $preflight_down$
BEGIN
    IF EXISTS (
        SELECT 1 FROM sistema_riego.capacitacion_ruta
        WHERE id_ruta_previa IS NOT NULL OR orden <> 1
    ) OR EXISTS (
        SELECT 1 FROM sistema_riego.capacitacion_ruta
        GROUP BY id_leccion_version HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Reversión detenida: hay rutas sucesoras; conserve esquema, intentos y progreso y revierta solo código';
    END IF;

    IF EXISTS (
        SELECT 1 FROM sistema_riego.capacitacion_actividad
        WHERE tipo NOT IN ('opcion_multiple', 'verdadero_falso', 'ordenar_pasos')
           OR configuracion IS DISTINCT FROM '{}'::JSONB
    ) THEN
        RAISE EXCEPTION 'Reversión detenida: existe contenido de minijuego o configuración que no debe descartarse';
    END IF;
END;
$preflight_down$;

ALTER TABLE sistema_riego.capacitacion_ruta
    DROP CONSTRAINT IF EXISTS fk_capacitacion_ruta_previa,
    DROP CONSTRAINT IF EXISTS chk_capacitacion_ruta_no_autoprevia,
    DROP CONSTRAINT IF EXISTS chk_capacitacion_ruta_orden_positivo;

DROP INDEX IF EXISTS sistema_riego.idx_capacitacion_ruta_previa;

ALTER TABLE sistema_riego.capacitacion_ruta
    DROP CONSTRAINT IF EXISTS uq_capacitacion_ruta_version_orden,
    ADD CONSTRAINT uq_capacitacion_ruta_version UNIQUE (id_leccion_version),
    DROP COLUMN IF EXISTS id_ruta_previa,
    DROP COLUMN IF EXISTS orden;

ALTER TABLE sistema_riego.capacitacion_actividad
    DROP CONSTRAINT IF EXISTS chk_capacitacion_actividad_tipo_extensible,
    ADD CONSTRAINT chk_capacitacion_actividad_tipo
    CHECK (tipo IN ('opcion_multiple', 'verdadero_falso', 'ordenar_pasos'));

COMMIT;
