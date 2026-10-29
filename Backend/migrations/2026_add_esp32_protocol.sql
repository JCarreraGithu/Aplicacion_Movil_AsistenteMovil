-- Esquema para dispositivos ESP32 y comandos manuales de actuador.
CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.dispositivo (
    id_dispositivo SERIAL PRIMARY KEY,
    id_sector INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.sector(id_sector) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    api_key_hash CHAR(64) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    ultimo_contacto TIMESTAMPTZ,
    fecha_creacion TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO.comando_actuador (
    id_comando SERIAL PRIMARY KEY,
    id_actuador INTEGER NOT NULL
        REFERENCES SISTEMA_RIEGO.actuador(id_actuador) ON DELETE CASCADE,
    accion VARCHAR(10) NOT NULL CHECK (accion IN ('ENCENDER', 'APAGAR')),
    duracion_segundos INTEGER,
    id_usuario INTEGER
        REFERENCES SISTEMA_RIEGO.usuario(id_usuario),
    estado VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'ENVIADO', 'EJECUTADO', 'FALLIDO', 'EXPIRADO')),
    fecha_creacion TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    fecha_expira TIMESTAMPTZ NOT NULL,
    fecha_ack TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_comando_actuador_estado
    ON SISTEMA_RIEGO.comando_actuador(id_actuador, estado);

ALTER TABLE SISTEMA_RIEGO.lectura_sensor
    ADD COLUMN IF NOT EXISTS uid_externo VARCHAR(40);

ALTER TABLE SISTEMA_RIEGO.riego
    ADD COLUMN IF NOT EXISTS uid_externo VARCHAR(40);

CREATE UNIQUE INDEX IF NOT EXISTS uq_lectura_sensor_uid_externo
    ON SISTEMA_RIEGO.lectura_sensor(id_sensor, uid_externo)
    WHERE uid_externo IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_riego_uid_externo
    ON SISTEMA_RIEGO.riego(id_sector, uid_externo)
    WHERE uid_externo IS NOT NULL;
