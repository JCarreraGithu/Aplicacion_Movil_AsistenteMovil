-- Aplicación manual como propietario. Conserva todas las relaciones e historial.
BEGIN;
ALTER TABLE sistema_riego.planta ADD COLUMN IF NOT EXISTS fecha_eliminacion TIMESTAMPTZ;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute
    WHERE attrelid='sistema_riego.planta'::regclass AND attname='fecha_eliminacion'
      AND NOT attisdropped AND atttypid='timestamptz'::regtype
      AND NOT attnotnull AND NOT atthasdef) THEN
    RAISE EXCEPTION 'fecha_eliminacion existe con tipo, nullabilidad o default incompatible';
  END IF;
END $$;
COMMIT;
