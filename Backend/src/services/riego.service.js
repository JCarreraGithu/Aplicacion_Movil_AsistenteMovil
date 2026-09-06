const pool = require('../config/database');

const crearRiego = async (
    idSector,
    fechaHora,
    duracionSegundos,
    cantidadAgua,
    modo
) => {

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.riego
        (
            id_sector,
            fecha_hora,
            duracion_segundos,
            cantidad_agua,
            modo
        )
        VALUES ($1, $2, $3, $4, $5)
        RETURNING
            id_riego,
            id_sector,
            fecha_hora,
            duracion_segundos,
            cantidad_agua,
            modo
    `, [
        idSector,
        fechaHora,
        duracionSegundos,
        cantidadAgua,
        modo
    ]);

    return result.rows[0];
};

const obtenerRiegosPorSector = async (idSector) => {

    const result = await pool.query(`
        SELECT
            id_riego,
            id_sector,
            fecha_hora,
            duracion_segundos,
            cantidad_agua,
            modo
        FROM SISTEMA_RIEGO.riego
        WHERE id_sector = $1
        ORDER BY fecha_hora DESC
    `, [idSector]);

    return result.rows;
};

module.exports = {
    crearRiego,
    obtenerRiegosPorSector
};