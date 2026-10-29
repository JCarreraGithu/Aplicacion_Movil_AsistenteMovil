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

const obtenerSensoresPorSector = async (idSector, idUsuario) => {

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
        INNER JOIN SISTEMA_RIEGO.sector sec
            ON sec.id_sector = s.id_sector
        INNER JOIN SISTEMA_RIEGO.jardin j
            ON j.id_jardin = sec.id_jardin
        WHERE s.id_sector = $1
        AND j.id_usuario = $2
        ORDER BY s.id_sensor
    `, [idSector, idUsuario]);

    return result.rows;
};

module.exports = {
    crearSensor,
    obtenerSensoresPorSector
};
