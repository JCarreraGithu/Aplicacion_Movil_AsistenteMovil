const pool = require('../config/database');
const { puedeEncender, transicionComandoValida } = require('./device-protocol');

const envPositiveInt = (name, fallback) => {
    const value = Number(process.env[name]);
    return Number.isInteger(value) && value > 0 ? value : fallback;
};

const crearComando = async (idUsuario, idActuador, accion, duracionSegundos) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const actuatorResult = await client.query(`
            SELECT a.id_actuador, a.id_sector, a.estado
            FROM SISTEMA_RIEGO.actuador a
            JOIN SISTEMA_RIEGO.sector s ON s.id_sector = a.id_sector
            JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
            WHERE a.id_actuador = $1 AND j.id_usuario = $2
            FOR UPDATE OF a
        `, [idActuador, idUsuario]);
        const actuator = actuatorResult.rows[0];
        if (!actuator) {
            await client.query('ROLLBACK');
            return { tipo: 'no_encontrado' };
        }

        const online = await client.query(`
            SELECT 1 FROM SISTEMA_RIEGO.dispositivo
            WHERE id_sector = $1 AND activo = TRUE
              AND ultimo_contacto >= CURRENT_TIMESTAMP - ($2 * INTERVAL '1 second')
            LIMIT 1
        `, [actuator.id_sector, envPositiveInt('DISPOSITIVO_ONLINE_SEGUNDOS', 120)]);
        if (!online.rows.length) {
            await client.query('ROLLBACK');
            return { tipo: 'sin_conexion' };
        }

        await client.query(`
            UPDATE SISTEMA_RIEGO.comando_actuador
            SET estado = 'EXPIRADO'
            WHERE id_actuador = $1 AND estado IN ('PENDIENTE', 'ENVIADO')
              AND fecha_expira <= CURRENT_TIMESTAMP
        `, [idActuador]);

        let vigente = false;
        if (accion === 'ENCENDER') {
            const existing = await client.query(`
                SELECT 1 FROM SISTEMA_RIEGO.comando_actuador
                WHERE id_actuador = $1 AND estado IN ('PENDIENTE', 'ENVIADO')
                  AND fecha_expira > CURRENT_TIMESTAMP
                LIMIT 1
            `, [idActuador]);
            vigente = existing.rows.length > 0;
            if (!puedeEncender({ estadoActuador: actuator.estado, comandoVigente: vigente })) {
                await client.query('ROLLBACK');
                return { tipo: 'ya_encendido_o_pendiente' };
            }
        }

        const ttl = envPositiveInt('COMANDO_TTL_SEGUNDOS', 120);
        const created = await client.query(`
            INSERT INTO SISTEMA_RIEGO.comando_actuador
                (id_actuador, accion, duracion_segundos, id_usuario, fecha_expira)
            VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP + ($5 * INTERVAL '1 second'))
            RETURNING id_comando, id_actuador, accion, duracion_segundos, estado, fecha_creacion, fecha_expira
        `, [idActuador, accion, accion === 'ENCENDER' ? duracionSegundos : null, idUsuario, ttl]);
        await client.query('COMMIT');
        return { tipo: 'creado', comando: created.rows[0] };
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
};

const obtenerComandoUsuario = async (idUsuario, idActuador, idComando) => {
    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.comando_actuador c
        SET estado = 'EXPIRADO'
        FROM SISTEMA_RIEGO.actuador a
        JOIN SISTEMA_RIEGO.sector s ON s.id_sector = a.id_sector
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE c.id_actuador = a.id_actuador AND c.id_actuador = $1
          AND c.id_comando = $2 AND j.id_usuario = $3
          AND c.estado IN ('PENDIENTE', 'ENVIADO') AND c.fecha_expira <= CURRENT_TIMESTAMP
    `, [idActuador, idComando, idUsuario]);
    const command = await pool.query(`
        SELECT c.id_comando, c.id_actuador, c.accion, c.duracion_segundos, c.estado,
               c.fecha_creacion, c.fecha_expira, c.fecha_ack
        FROM SISTEMA_RIEGO.comando_actuador c
        JOIN SISTEMA_RIEGO.actuador a ON a.id_actuador = c.id_actuador
        JOIN SISTEMA_RIEGO.sector s ON s.id_sector = a.id_sector
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE c.id_actuador = $1 AND c.id_comando = $2 AND j.id_usuario = $3
    `, [idActuador, idComando, idUsuario]);
    return command.rows[0] || null;
};

const comandosPendientesDispositivo = async (dispositivo) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query(`
            UPDATE SISTEMA_RIEGO.comando_actuador c
            SET estado = 'EXPIRADO'
            FROM SISTEMA_RIEGO.actuador a
            WHERE c.id_actuador = a.id_actuador AND a.id_sector = $1
              AND c.estado IN ('PENDIENTE', 'ENVIADO') AND c.fecha_expira <= CURRENT_TIMESTAMP
        `, [dispositivo.id_sector]);

        const pending = await client.query(`
            SELECT c.id_comando, a.codigo AS codigo_actuador, c.accion,
                   c.duracion_segundos, c.fecha_expira
            FROM SISTEMA_RIEGO.comando_actuador c
            JOIN SISTEMA_RIEGO.actuador a ON a.id_actuador = c.id_actuador
            WHERE a.id_sector = $1 AND c.estado = 'PENDIENTE'
              AND c.fecha_expira > CURRENT_TIMESTAMP
            ORDER BY c.fecha_creacion, c.id_comando
            FOR UPDATE OF c SKIP LOCKED
        `, [dispositivo.id_sector]);

        const comandos = [];
        for (const item of pending.rows) {
            const sent = await client.query(`
                UPDATE SISTEMA_RIEGO.comando_actuador
                SET estado = 'ENVIADO'
                WHERE id_comando = $1 AND estado = 'PENDIENTE'
                  AND fecha_expira > CURRENT_TIMESTAMP
                RETURNING id_comando, accion, duracion_segundos, fecha_expira,
                    GREATEST(0, CEIL(EXTRACT(EPOCH FROM (fecha_expira - CURRENT_TIMESTAMP))))::INTEGER AS expira_en_segundos
            `, [item.id_comando]);
            if (sent.rows[0]) {
                const command = sent.rows[0];
                comandos.push({
                    id_comando: command.id_comando,
                    codigo_actuador: item.codigo_actuador,
                    accion: command.accion,
                    duracion_segundos: command.duracion_segundos,
                    expira_en_segundos: command.expira_en_segundos
                });
            }
        }
        await client.query('COMMIT');
        return comandos;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally { client.release(); }
};

const ackComando = async (dispositivo, idComando, estado) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query(`
            UPDATE SISTEMA_RIEGO.comando_actuador c SET estado = 'EXPIRADO'
            FROM SISTEMA_RIEGO.actuador a
            WHERE c.id_actuador = a.id_actuador AND a.id_sector = $1
              AND c.id_comando = $2 AND c.estado IN ('PENDIENTE', 'ENVIADO')
              AND c.fecha_expira <= CURRENT_TIMESTAMP
        `, [dispositivo.id_sector, idComando]);

        const updated = await client.query(`
            UPDATE SISTEMA_RIEGO.comando_actuador c
            SET estado = $3, fecha_ack = CURRENT_TIMESTAMP
            FROM SISTEMA_RIEGO.actuador a
            WHERE c.id_actuador = a.id_actuador AND a.id_sector = $1
              AND c.id_comando = $2 AND c.estado IN ('PENDIENTE', 'ENVIADO')
              AND c.fecha_expira > CURRENT_TIMESTAMP
            RETURNING c.id_comando, c.estado, c.fecha_ack
        `, [dispositivo.id_sector, idComando, estado]);

        if (updated.rows[0]) {
            await client.query('COMMIT');
            return { tipo: 'actualizado', comando: updated.rows[0] };
        }
        const current = await client.query(`
            SELECT c.estado FROM SISTEMA_RIEGO.comando_actuador c
            JOIN SISTEMA_RIEGO.actuador a ON a.id_actuador = c.id_actuador
            WHERE c.id_comando = $1 AND a.id_sector = $2
        `, [idComando, dispositivo.id_sector]);
        await client.query('COMMIT');
        return current.rows[0]
            ? { tipo: current.rows[0].estado === 'EXPIRADO' ? 'expirado' : 'transicion_invalida', estado: current.rows[0].estado }
            : { tipo: 'no_encontrado' };
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally { client.release(); }
};

const transicionValida = (actual, siguiente) => transicionComandoValida(actual, siguiente);

module.exports = { crearComando, obtenerComandoUsuario, comandosPendientesDispositivo, ackComando, transicionValida };
