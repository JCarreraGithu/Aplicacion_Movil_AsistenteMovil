const pool = require('../config/database');

const crearSensor = async (
    idSector,
    idTipoSensor,
    codigo,
    estado,
    fechaInstalacion
) => {

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.sensor
        (
            id_sector,
            id_tipo_sensor,
            codigo,
            estado,
            fecha_instalacion
        )
        VALUES ($1, $2, $3, $4, $5)
        RETURNING
            id_sensor,
            id_sector,
            id_tipo_sensor,
            codigo,
            estado,
            fecha_instalacion
    `, [
        idSector,
        idTipoSensor,
        codigo,
        estado,
        fechaInstalacion
    ]);

    return result.rows[0];
};

const obtenerSensoresPorSector = async (idSector) => {

    const result = await pool.query(`
        SELECT
            s.id_sensor,
            s.id_sector,
            s.id_tipo_sensor,
            ts.nombre AS tipo_sensor,
            s.codigo,
            s.estado,
            s.fecha_instalacion
        FROM SISTEMA_RIEGO.sensor s
        INNER JOIN SISTEMA_RIEGO.tipo_sensor ts
            ON s.id_tipo_sensor = ts.id_tipo_sensor
        WHERE s.id_sector = $1
        ORDER BY s.id_sensor
    `, [idSector]);

    return result.rows;
};

module.exports = {
    crearSensor,
    obtenerSensoresPorSector
};