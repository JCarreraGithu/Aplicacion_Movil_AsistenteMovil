const pool = require('../config/database');

const verificarSectorUsuario = async (idSector, idUsuario) => {
    const result = await pool.query(`
        SELECT s.id_sector
        FROM SISTEMA_RIEGO.sector s
        INNER JOIN SISTEMA_RIEGO.jardin j
            ON s.id_jardin = j.id_jardin
        WHERE s.id_sector = $1
        AND j.id_usuario = $2
    `, [idSector, idUsuario]);

    return result.rows[0];
};

const crearConfiguracion = async (
    idUsuario,
    idSector,
    configuracion
) => {

    const sector = await verificarSectorUsuario(
        idSector,
        idUsuario
    );

    if (!sector) {
        return null;
    }

    const {
        humedad_minima,
        humedad_maxima,
        frecuencia_dias,
        horario,
        modo_automatico
    } = configuracion;

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.configuracion_riego
        (
            id_sector,
            humedad_minima,
            humedad_maxima,
            frecuencia_dias,
            horario,
            modo_automatico
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING
            id_configuracion,
            id_sector,
            humedad_minima,
            humedad_maxima,
            frecuencia_dias,
            horario,
            modo_automatico
    `, [
        idSector,
        humedad_minima,
        humedad_maxima,
        frecuencia_dias,
        horario,
        modo_automatico
    ]);

    return result.rows[0];
};

const obtenerConfiguracion = async (
    idUsuario,
    idSector
) => {

    const sector = await verificarSectorUsuario(
        idSector,
        idUsuario
    );

    if (!sector) {
        return null;
    }

    const result = await pool.query(`
        SELECT
            id_configuracion,
            id_sector,
            humedad_minima,
            humedad_maxima,
            frecuencia_dias,
            horario,
            modo_automatico
        FROM SISTEMA_RIEGO.configuracion_riego
        WHERE id_sector = $1
        ORDER BY id_configuracion DESC
        LIMIT 1
    `, [idSector]);

    return result.rows[0];
};

module.exports = {
    crearConfiguracion,
    obtenerConfiguracion
};