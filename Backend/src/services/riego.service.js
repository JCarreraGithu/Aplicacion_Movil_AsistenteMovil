const pool = require('../config/database');

const crearRiego = async (
    idUsuario,
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
        SELECT $1, $3, $4, $5, $6
        WHERE EXISTS (
            SELECT 1
            FROM SISTEMA_RIEGO.sector s
            JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
            WHERE s.id_sector = $1 AND j.id_usuario = $2
        )
        RETURNING
            id_riego,
            id_sector,
            fecha_hora,
            duracion_segundos,
            cantidad_agua,
            modo
    `, [
        idSector,
        idUsuario,
        fechaHora,
        duracionSegundos,
        cantidadAgua,
        modo
    ]);

    return result.rows[0];
};

const obtenerRiegosPorSector = async (idSector, idUsuario, dias = 15, periodo = 'actual') => {

    const result = await pool.query(`
        SELECT
            r.id_riego,
            r.id_sector,
            r.fecha_hora,
            r.duracion_segundos,
            r.cantidad_agua,
            r.modo
        FROM SISTEMA_RIEGO.riego r
        INNER JOIN SISTEMA_RIEGO.sector s ON s.id_sector = r.id_sector
        INNER JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE r.id_sector = $1
        AND j.id_usuario = $2
        AND r.fecha_hora >= CURRENT_TIMESTAMP -
            (($3::int * CASE WHEN $4 = 'anterior' THEN 2 ELSE 1 END) * INTERVAL '1 day')
        AND r.fecha_hora < CURRENT_TIMESTAMP -
            (($3::int * CASE WHEN $4 = 'anterior' THEN 1 ELSE 0 END) * INTERVAL '1 day')
        ORDER BY r.fecha_hora ASC
    `, [idSector, idUsuario, dias, periodo]);

    return result.rows;
};

const obtenerResumenPorSector = async (idSector, idUsuario) => {
    const result = await pool.query(`
        WITH sector_usuario AS (
            SELECT s.id_sector
            FROM SISTEMA_RIEGO.sector s
            INNER JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
            WHERE s.id_sector = $1 AND j.id_usuario = $2
        )
        SELECT
            su.id_sector,
            COUNT(r.id_riego)::int AS cantidad_riegos,
            COALESCE(SUM(r.cantidad_agua), 0)::numeric AS consumo_total,
            COUNT(r.id_riego) FILTER (WHERE r.cantidad_agua IS NULL)::int AS cantidades_desconocidas,
            MAX(r.fecha_hora) AS fecha_ultimo_riego,
            COALESCE(SUM(r.cantidad_agua) FILTER (
                WHERE r.fecha_hora >= CURRENT_TIMESTAMP - INTERVAL '7 days'
                  AND r.fecha_hora < CURRENT_TIMESTAMP
            ), 0)::numeric AS consumo_ultimos_7_dias,
            COUNT(r.id_riego) FILTER (
                WHERE r.fecha_hora >= CURRENT_TIMESTAMP - INTERVAL '7 days'
                  AND r.fecha_hora < CURRENT_TIMESTAMP
            )::int AS riegos_ultimos_7_dias,
            COUNT(r.id_riego) FILTER (
                WHERE r.fecha_hora >= CURRENT_TIMESTAMP - INTERVAL '7 days'
                  AND r.fecha_hora < CURRENT_TIMESTAMP
                  AND r.cantidad_agua IS NULL
            )::int AS cantidades_desconocidas_ultimos_7_dias
        FROM sector_usuario su
        LEFT JOIN SISTEMA_RIEGO.riego r ON r.id_sector = su.id_sector
        GROUP BY su.id_sector
    `, [idSector, idUsuario]);

    return result.rows[0] || null;
};

module.exports = {
    crearRiego,
    obtenerRiegosPorSector,
    obtenerResumenPorSector
};
