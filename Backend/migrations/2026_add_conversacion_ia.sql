BEGIN;
CREATE TABLE IF NOT EXISTS sistema_riego.conversacion_ia (
  id_usuario INTEGER NOT NULL REFERENCES sistema_riego.usuario(id_usuario) ON DELETE RESTRICT,
  id VARCHAR(100) NOT NULL,
  titulo VARCHAR(200) NOT NULL CHECK (length(trim(titulo)) > 0),
  mensajes JSONB NOT NULL CHECK (jsonb_typeof(mensajes) = 'array' AND jsonb_array_length(mensajes) > 0),
  contexto TEXT,
  id_planta INTEGER REFERENCES sistema_riego.planta(id_planta) ON DELETE RESTRICT,
  actualizada TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  eliminada TIMESTAMPTZ,
  PRIMARY KEY (id_usuario, id)
);
CREATE INDEX IF NOT EXISTS idx_conversacion_ia_reciente ON sistema_riego.conversacion_ia(id_usuario, actualizada DESC) WHERE eliminada IS NULL;
-- IF NOT EXISTS no valida la forma de objetos preexistentes. Abortamos ante
-- una tabla incompleta/incompatible en vez de ocultar una instalación parcial.
DO $$
DECLARE campo RECORD;
BEGIN
  FOR campo IN SELECT * FROM (VALUES
    ('id_usuario','integer'::regtype,true), ('id','varchar'::regtype,true),
    ('titulo','varchar'::regtype,true), ('mensajes','jsonb'::regtype,true),
    ('contexto','text'::regtype,false), ('id_planta','integer'::regtype,false),
    ('actualizada','timestamptz'::regtype,true), ('eliminada','timestamptz'::regtype,false)
  ) AS esperado(nombre,tipo,requerido) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE
      attrelid='sistema_riego.conversacion_ia'::regclass AND attname=campo.nombre
      AND NOT attisdropped AND atttypid=campo.tipo AND attnotnull=campo.requerido) THEN
      RAISE EXCEPTION 'conversacion_ia: columna incompatible %',campo.nombre;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE
    c.conrelid='sistema_riego.conversacion_ia'::regclass AND c.contype='p'
    AND c.conkey=ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid=c.conrelid AND attname='id_usuario'),
                       (SELECT attnum FROM pg_attribute WHERE attrelid=c.conrelid AND attname='id')]::smallint[]) THEN
    RAISE EXCEPTION 'conversacion_ia: clave primaria incompatible';
  END IF;
END $$;
COMMIT;
