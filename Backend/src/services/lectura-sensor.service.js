const pool = require('../config/database');

const crearLectura = async (idUsuario, idSensor, valor, unidad, fechaHora = null) => {
    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.lectura_sensor
            (id_sensor, valor, unidad, fecha_hora)
        SELECT s.id_sensor, $3, $4, COALESCE($5::timestamp, CURRENT_TIMESTAMP)
        FROM SISTEMA_RIEGO.sensor s
        JOIN SISTEMA_RIEGO.sector sec ON sec.id_sector = s.id_sector
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = sec.id_jardin
        WHERE s.id_sensor = $1 AND j.id_usuario = $2
        RETURNING id_lectura, id_sensor, valor, unidad, fecha_hora
    `, [idSensor, idUsuario, valor, unidad, fechaHora]);

    return result.rows[0] || null;
};

const obtenerLecturasPorSensor = async (idUsuario, idSensor) => {
    const result = await pool.query(`
        SELECT ls.id_lectura, ls.id_sensor, ls.valor, ls.unidad, ls.fecha_hora
        FROM SISTEMA_RIEGO.lectura_sensor ls
        JOIN SISTEMA_RIEGO.sensor s ON s.id_sensor = ls.id_sensor
        JOIN SISTEMA_RIEGO.sector sec ON sec.id_sector = s.id_sector
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = sec.id_jardin
        WHERE ls.id_sensor = $1 AND j.id_usuario = $2
        ORDER BY ls.fecha_hora DESC
    `, [idSensor, idUsuario]);
    if (result.rows.length === 0) {
        const owner = await pool.query(`
            SELECT 1 FROM SISTEMA_RIEGO.sensor s
            JOIN SISTEMA_RIEGO.sector sec ON sec.id_sector = s.id_sector
            JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = sec.id_jardin
            WHERE s.id_sensor = $1 AND j.id_usuario = $2
        `, [idSensor, idUsuario]);
        if (owner.rows.length === 0) return null;
    }
    return result.rows;
};

const obtenerUltimasLecturasPorSector = async (idUsuario, idSector) => {
    const result = await pool.query(`
        SELECT DISTINCT ON (s.id_sensor)
            s.id_sensor, s.codigo, ts.nombre AS tipo_sensor,
            ls.valor, ls.unidad, ls.fecha_hora
        FROM SISTEMA_RIEGO.sensor s
        JOIN SISTEMA_RIEGO.tipo_sensor ts ON ts.id_tipo_sensor = s.id_tipo_sensor
        JOIN SISTEMA_RIEGO.lectura_sensor ls ON ls.id_sensor = s.id_sensor
        JOIN SISTEMA_RIEGO.sector sec ON sec.id_sector = s.id_sector
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = sec.id_jardin
        WHERE s.id_sector = $1 AND j.id_usuario = $2 AND s.estado = 'ACTIVO'
        ORDER BY s.id_sensor, ls.fecha_hora DESC
    `, [idSector, idUsuario]);

    const owner = await pool.query(`
        SELECT 1 FROM SISTEMA_RIEGO.sector sec
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = sec.id_jardin
        WHERE sec.id_sector = $1 AND j.id_usuario = $2
    `, [idSector, idUsuario]);
    return owner.rows.length ? result.rows : null;
};

module.exports = {
    crearLectura,
    obtenerLecturasPorSensor,
    obtenerUltimasLecturasPorSector
};
