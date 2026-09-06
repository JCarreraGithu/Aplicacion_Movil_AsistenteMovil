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

const crearPlanta = async (idUsuario, idSector, planta) => {

    const sector = await verificarSectorUsuario(
        idSector,
        idUsuario
    );

    if (!sector) {
        return null;
    }

    const {
        id_especie,
        nombre,
        fecha_registro,
        descripcion,
        foto_url
    } = planta;

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.planta
        (
            id_sector,
            id_especie,
            nombre,
            fecha_registro,
            descripcion,
            foto_url
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING
            id_planta,
            id_sector,
            id_especie,
            nombre,
            fecha_registro,
            descripcion,
            foto_url
    `, [
        idSector,
        id_especie,
        nombre,
        fecha_registro,
        descripcion,
        foto_url
    ]);

    return result.rows[0];
};

const obtenerPlantas = async (idUsuario, idSector) => {

    const sector = await verificarSectorUsuario(
        idSector,
        idUsuario
    );

    if (!sector) {
        return null;
    }

    const result = await pool.query(`
        SELECT
            p.id_planta,
            p.id_sector,
            p.id_especie,
            p.nombre,
            p.fecha_registro,
            p.descripcion,
            p.foto_url,
            e.nombre_comun,
            e.nombre_cientifico
        FROM SISTEMA_RIEGO.planta p
        INNER JOIN SISTEMA_RIEGO.especie_planta e
            ON p.id_especie = e.id_especie
        WHERE p.id_sector = $1
        ORDER BY p.id_planta
    `, [idSector]);

    return result.rows;
};

const obtenerPlantaPorId = async (
    idUsuario,
    idSector,
    idPlanta
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
            p.id_planta,
            p.id_sector,
            p.id_especie,
            p.nombre,
            p.fecha_registro,
            p.descripcion,
            p.foto_url,
            e.nombre_comun,
            e.nombre_cientifico
        FROM SISTEMA_RIEGO.planta p
        INNER JOIN SISTEMA_RIEGO.especie_planta e
            ON p.id_especie = e.id_especie
        WHERE p.id_planta = $1
        AND p.id_sector = $2
    `, [
        idPlanta,
        idSector
    ]);

    return result.rows[0];
};

module.exports = {
    crearPlanta,
    obtenerPlantas,
    obtenerPlantaPorId
};