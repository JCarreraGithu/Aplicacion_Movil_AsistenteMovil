const pool = require('../config/database');

const crearActuador = async (
    idSector,
    idTipoActuador,
    codigo,
    estado
) => {

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.actuador
        (
            id_sector,
            id_tipo_actuador,
            codigo,
            estado
        )
        VALUES ($1, $2, $3, $4)
        RETURNING
            id_actuador,
            id_sector,
            id_tipo_actuador,
            codigo,
            estado
    `, [
        idSector,
        idTipoActuador,
        codigo,
        estado
    ]);

    return result.rows[0];
};

const obtenerActuadoresPorSector = async (idSector) => {

    const result = await pool.query(`
        SELECT
            a.id_actuador,
            a.id_sector,
            a.id_tipo_actuador,
            ta.nombre AS tipo_actuador,
            a.codigo,
            a.estado
        FROM SISTEMA_RIEGO.actuador a
        INNER JOIN SISTEMA_RIEGO.tipo_actuador ta
            ON a.id_tipo_actuador = ta.id_tipo_actuador
        WHERE a.id_sector = $1
        ORDER BY a.id_actuador
    `, [idSector]);

    return result.rows;
};

const actualizarEstadoActuador = async (idActuador, idUsuario, estado) => {
    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.actuador a
        SET estado = $3
        FROM SISTEMA_RIEGO.sector s
        INNER JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE a.id_sector = s.id_sector
        AND a.id_actuador = $1
        AND j.id_usuario = $2
        RETURNING a.id_actuador, a.id_sector, a.id_tipo_actuador,
                  a.codigo, a.estado
    `, [idActuador, idUsuario, estado]);

    return result.rows[0];
};

module.exports = {
    crearActuador,
    obtenerActuadoresPorSector,
    actualizarEstadoActuador
};
