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
            e.nombre_cientifico,
            hp.estado AS estado_salud,
            hp.fecha AS fecha_estado_salud
        FROM SISTEMA_RIEGO.planta p
        LEFT JOIN SISTEMA_RIEGO.especie_planta e
            ON p.id_especie = e.id_especie
        LEFT JOIN LATERAL (
            SELECT h.estado, h.fecha
            FROM SISTEMA_RIEGO.historial_planta h
            WHERE h.id_planta = p.id_planta
            ORDER BY h.fecha DESC
            LIMIT 1
        ) hp ON TRUE
        WHERE p.id_sector = $1
          AND (to_jsonb(p)->>'fecha_eliminacion') IS NULL
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
            e.nombre_cientifico,
            hp.estado AS estado_salud,
            hp.fecha AS fecha_estado_salud
        FROM SISTEMA_RIEGO.planta p
        LEFT JOIN SISTEMA_RIEGO.especie_planta e
            ON p.id_especie = e.id_especie
        LEFT JOIN LATERAL (
            SELECT h.estado, h.fecha
            FROM SISTEMA_RIEGO.historial_planta h
            WHERE h.id_planta = p.id_planta
            ORDER BY h.fecha DESC
            LIMIT 1
        ) hp ON TRUE
        WHERE p.id_planta = $1
        AND p.id_sector = $2
    `, [
        idPlanta,
        idSector
    ]);

    return result.rows[0];
};

module.exports = {
    archivarPlanta: async (idUsuario, idSector, idPlanta) => {
        const result = await pool.query(`
          UPDATE SISTEMA_RIEGO.planta p SET fecha_eliminacion = COALESCE(p.fecha_eliminacion, NOW())
          FROM SISTEMA_RIEGO.sector s JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
          WHERE p.id_sector = s.id_sector AND p.id_sector = $1
            AND p.id_planta = $2 AND j.id_usuario = $3
          RETURNING p.id_planta
        `, [idSector, idPlanta, idUsuario]);
        return result.rows[0] ?? null;
    },
    crearPlanta,
    obtenerPlantas,
    obtenerPlantaPorId
};
