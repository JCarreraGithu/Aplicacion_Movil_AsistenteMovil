const pool = require('../config/database');

// ============================================================
// VERIFICAR QUE LA PLANTA PERTENECE AL USUARIO
// (mismo patrón usado en planta.service.js)
// ============================================================

const verificarPlantaUsuario = async (idPlanta, idUsuario) => {

    const result = await pool.query(`
        SELECT p.id_planta
        FROM SISTEMA_RIEGO.planta p
        INNER JOIN SISTEMA_RIEGO.sector s
            ON p.id_sector = s.id_sector
        INNER JOIN SISTEMA_RIEGO.jardin j
            ON s.id_jardin = j.id_jardin
        WHERE p.id_planta = $1
        AND j.id_usuario = $2
    `, [idPlanta, idUsuario]);

    return result.rows[0];
};

// ============================================================
// CREAR CASO
// ============================================================

const crearCaso = async (idUsuario, datos) => {

    const {
        id_planta,
        id_consulta,
        titulo,
        diagnostico,
        plan_trabajo
    } = datos;

    if (id_planta) {
        const planta = await verificarPlantaUsuario(
            id_planta,
            idUsuario
        );

        if (!planta) {
            return null;
        }
    }

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.caso_planta
        (
            id_usuario,
            id_planta,
            id_consulta,
            titulo,
            diagnostico,
            plan_trabajo
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
    `, [
        idUsuario,
        id_planta || null,
        id_consulta || null,
        titulo,
        diagnostico,
        plan_trabajo
    ]);

    return result.rows[0];
};

// ============================================================
// OBTENER CASOS DEL USUARIO (con filtro opcional de estado)
// ============================================================

const obtenerCasos = async (idUsuario, estado) => {

    const params = [idUsuario];
    let filtroEstado = '';

    if (estado) {
        params.push(estado);
        filtroEstado = `AND c.estado = $${params.length}`;
    }

    const result = await pool.query(`
        SELECT
            c.id_caso,
            c.id_planta,
            c.id_consulta,
            c.titulo,
            c.diagnostico,
            c.plan_trabajo,
            c.estado,
            c.fecha_apertura,
            c.fecha_cierre,
            p.nombre AS nombre_planta,
            p.foto_url AS foto_planta
        FROM SISTEMA_RIEGO.caso_planta c
        LEFT JOIN SISTEMA_RIEGO.planta p
            ON c.id_planta = p.id_planta
        WHERE c.id_usuario = $1
        ${filtroEstado}
        ORDER BY
            CASE c.estado
                WHEN 'abierto' THEN 1
                WHEN 'en_progreso' THEN 2
                WHEN 'resuelto' THEN 3
                WHEN 'abandonado' THEN 4
            END,
            c.fecha_apertura DESC
    `, params);

    return result.rows;
};

// ============================================================
// CONTAR CASOS ACTIVOS (para el badge del dashboard)
// ============================================================

const contarCasosActivos = async (idUsuario) => {

    const result = await pool.query(`
        SELECT COUNT(*)::int AS total
        FROM SISTEMA_RIEGO.caso_planta
        WHERE id_usuario = $1
        AND estado IN ('abierto', 'en_progreso')
    `, [idUsuario]);

    return result.rows[0].total;
};

// ============================================================
// OBTENER UN CASO POR ID (con su bitácora de seguimientos)
// ============================================================

const obtenerCasoPorId = async (idUsuario, idCaso) => {

    const caso = await pool.query(`
        SELECT
            c.*,
            p.nombre AS nombre_planta,
            p.foto_url AS foto_planta
        FROM SISTEMA_RIEGO.caso_planta c
        LEFT JOIN SISTEMA_RIEGO.planta p
            ON c.id_planta = p.id_planta
        WHERE c.id_caso = $1
        AND c.id_usuario = $2
    `, [idCaso, idUsuario]);

    if (!caso.rows[0]) {
        return null;
    }

    const seguimientos = await pool.query(`
        SELECT *
        FROM SISTEMA_RIEGO.seguimiento_caso
        WHERE id_caso = $1
        ORDER BY fecha ASC
    `, [idCaso]);

    return {
        ...caso.rows[0],
        seguimientos: seguimientos.rows
    };
};

// ============================================================
// AGREGAR UNA ENTRADA DE SEGUIMIENTO A UN CASO
// ============================================================

const agregarSeguimiento = async (
    idUsuario,
    idCaso,
    nota,
    imagenUrl
) => {

    const caso = await pool.query(`
        SELECT id_caso
        FROM SISTEMA_RIEGO.caso_planta
        WHERE id_caso = $1
        AND id_usuario = $2
    `, [idCaso, idUsuario]);

    if (!caso.rows[0]) {
        return null;
    }

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.seguimiento_caso
        (
            id_caso,
            nota,
            imagen_url
        )
        VALUES ($1, $2, $3)
        RETURNING *
    `, [idCaso, nota, imagenUrl || null]);

    return result.rows[0];
};

// ============================================================
// CAMBIAR ESTADO DE UN CASO (en_progreso / resuelto / abandonado)
// ============================================================

const cambiarEstadoCaso = async (idUsuario, idCaso, estado) => {

    const estadosValidos = [
        'abierto',
        'en_progreso',
        'resuelto',
        'abandonado'
    ];

    if (!estadosValidos.includes(estado)) {
        return 'estado_invalido';
    }

    const cierraCaso =
        estado === 'resuelto' || estado === 'abandonado';

    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.caso_planta
        SET
            estado = $1,
            fecha_cierre = CASE
                WHEN $2::boolean THEN CURRENT_TIMESTAMP
                ELSE fecha_cierre
            END
        WHERE id_caso = $3
        AND id_usuario = $4
        RETURNING *
    `, [estado, cierraCaso, idCaso, idUsuario]);

    return result.rows[0] || null;
};

module.exports = {
    crearCaso,
    obtenerCasos,
    contarCasosActivos,
    obtenerCasoPorId,
    agregarSeguimiento,
    cambiarEstadoCaso
};
