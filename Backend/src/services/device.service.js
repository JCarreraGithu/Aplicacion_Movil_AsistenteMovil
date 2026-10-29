const pool = require('../config/database');
const { fechaDesdeHaceSegundos } = require('./device-protocol');

const registrarLote = async (dispositivo, lecturas, actuadores) => {
    const client = await pool.connect();
    const omitidas = [];
    let guardadas = 0;
    let duplicadas = 0;
    try {
        await client.query('BEGIN');
        for (const lectura of lecturas) {
            const sensor = await client.query(`
                SELECT id_sensor FROM SISTEMA_RIEGO.sensor
                WHERE id_sector = $1 AND codigo = $2
            `, [dispositivo.id_sector, lectura.codigo]);
            if (!sensor.rows[0]) {
                omitidas.push({ uid: lectura.uid, codigo: lectura.codigo, motivo: 'Sensor desconocido para el sector' });
                continue;
            }
            const fecha = fechaDesdeHaceSegundos(lectura.hace_segundos);
            const insertada = await client.query(`
                INSERT INTO SISTEMA_RIEGO.lectura_sensor
                    (id_sensor, valor, unidad, fecha_hora, uid_externo)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (id_sensor, uid_externo)
                    WHERE uid_externo IS NOT NULL DO NOTHING
                RETURNING id_lectura
            `, [sensor.rows[0].id_sensor, lectura.valor, lectura.unidad.trim(), fecha, lectura.uid.trim()]);
            if (insertada.rows.length) guardadas++;
            else duplicadas++;
        }

        for (const actuador of actuadores) {
            const updated = await client.query(`
                UPDATE SISTEMA_RIEGO.actuador
                SET fecha_ultimo_cambio = CASE
                        WHEN estado IS DISTINCT FROM $3 THEN CURRENT_TIMESTAMP
                        ELSE fecha_ultimo_cambio
                    END,
                    estado = $3
                WHERE id_sector = $1 AND codigo = $2
                RETURNING id_actuador
            `, [dispositivo.id_sector, actuador.codigo, actuador.estado]);
            if (!updated.rows.length) {
                omitidas.push({ codigo: actuador.codigo, motivo: 'Actuador desconocido para el sector' });
            }
        }
        await client.query('COMMIT');
        return { ok: true, guardadas, duplicadas, omitidas };
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
};

const registrarRiego = async (dispositivo, { uid, hace_segundos, duracion_segundos, modo, cantidad_agua }) => {
    const fecha = fechaDesdeHaceSegundos(hace_segundos);
    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.riego
            (id_sector, fecha_hora, duracion_segundos, cantidad_agua, modo, uid_externo)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (id_sector, uid_externo)
            WHERE uid_externo IS NOT NULL DO NOTHING
        RETURNING id_riego, id_sector, fecha_hora, duracion_segundos, cantidad_agua, modo, uid_externo
    `, [dispositivo.id_sector, fecha, duracion_segundos, cantidad_agua, modo, uid.trim()]);
    if (!result.rows.length) return { ok: true, duplicado: true };
    return { ok: true, duplicado: false, riego: result.rows[0] };
};

module.exports = { registrarLote, registrarRiego };
