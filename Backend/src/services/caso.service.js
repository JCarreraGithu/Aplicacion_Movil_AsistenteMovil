const pool = require('../config/database');

// ============================================================
// CREAR CASO
// ============================================================

const crearCaso = async (idUsuario, datos) => {

    const {
        id_planta,
        id_consulta,
        titulo,
        diagnostico,
        plan_trabajo,
        id_sector
    } = datos;

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        if (id_consulta) {
            const consulta = await client.query(`
                SELECT id_consulta FROM SISTEMA_RIEGO.consulta_ia
                WHERE id_consulta = $1 AND id_usuario = $2
            `, [id_consulta, idUsuario]);
            if (!consulta.rows[0]) {
                await client.query('ROLLBACK');
                return null;
            }
        }

        let idSectorFinal = id_sector || null;
        if (id_planta) {
            const planta = await client.query(`
                SELECT p.id_planta, p.id_sector
                FROM SISTEMA_RIEGO.planta p
                INNER JOIN SISTEMA_RIEGO.sector s ON s.id_sector = p.id_sector
                INNER JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
                WHERE p.id_planta = $1 AND j.id_usuario = $2
            `, [id_planta, idUsuario]);
            if (!planta.rows[0] || (idSectorFinal && Number(idSectorFinal) !== Number(planta.rows[0].id_sector))) {
                await client.query('ROLLBACK');
                return null;
            }
            idSectorFinal = planta.rows[0].id_sector;
        } else if (idSectorFinal) {
            const sector = await client.query(`
                SELECT s.id_sector
                FROM SISTEMA_RIEGO.sector s
                INNER JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
                WHERE s.id_sector = $1 AND j.id_usuario = $2
            `, [idSectorFinal, idUsuario]);
            if (!sector.rows[0]) {
                await client.query('ROLLBACK');
                return null;
            }
        }

        const result = await client.query(`
            INSERT INTO SISTEMA_RIEGO.caso_planta
            (id_usuario, id_planta, id_sector, id_consulta, titulo, diagnostico, plan_trabajo)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *
        `, [idUsuario, id_planta || null, idSectorFinal, id_consulta || null, titulo, diagnostico, plan_trabajo]);

        const caso = result.rows[0];
        const pasos = String(plan_trabajo)
            .split(/\r?\n/)
            .map((linea) => linea.replace(/^\s*(?:[-*•]+|\d+[.)])\s*/, '').trim())
            .filter((linea) => linea.length > 2 && !/no se requiere ningún plan|definir seguimiento y tratamiento recomendado/i.test(linea));
        for (const descripcion of pasos) {
            await client.query(`
                INSERT INTO SISTEMA_RIEGO.caso_tarea (id_caso, descripcion)
                VALUES ($1, $2)
            `, [caso.id_caso, descripcion]);
        }

        await client.query('COMMIT');
        return caso;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
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
            c.id_sector,
            c.id_consulta,
            c.titulo,
            c.diagnostico,
            c.plan_trabajo,
            c.estado,
            c.fecha_apertura,
            c.fecha_cierre,
            p.nombre AS nombre_planta,
            p.foto_url AS foto_planta,
            s.nombre AS nombre_sector
        FROM SISTEMA_RIEGO.caso_planta c
        LEFT JOIN SISTEMA_RIEGO.planta p
            ON c.id_planta = p.id_planta
        LEFT JOIN SISTEMA_RIEGO.sector s ON s.id_sector = COALESCE(c.id_sector, p.id_sector)
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
            p.foto_url AS foto_planta,
            COALESCE(c.id_sector, p.id_sector) AS id_sector,
            s.nombre AS nombre_sector,
            j.nombre AS nombre_jardin
        FROM SISTEMA_RIEGO.caso_planta c
        LEFT JOIN SISTEMA_RIEGO.planta p
            ON c.id_planta = p.id_planta
        LEFT JOIN SISTEMA_RIEGO.sector s ON s.id_sector = COALESCE(c.id_sector, p.id_sector)
        LEFT JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
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
        seguimientos: seguimientos.rows,
        tareas: (await obtenerTareas(idUsuario, idCaso)) || [],
        recordatorios: (await obtenerRecordatorios(idUsuario, idCaso)) || []
    };
};

const verificarCasoUsuario = async (idUsuario, idCaso) => {
    const result = await pool.query(
        'SELECT id_caso FROM SISTEMA_RIEGO.caso_planta WHERE id_caso = $1 AND id_usuario = $2',
        [idCaso, idUsuario]
    );
    return result.rows[0];
};

const obtenerTareas = async (idUsuario, idCaso) => {
    if (!await verificarCasoUsuario(idUsuario, idCaso)) return null;
    const result = await pool.query(`
        SELECT * FROM SISTEMA_RIEGO.caso_tarea
        WHERE id_caso = $1 ORDER BY fecha_creacion, id_tarea
    `, [idCaso]);
    return result.rows;
};

const crearTarea = async (idUsuario, idCaso, descripcion, fechaLimite) => {
    if (!await verificarCasoUsuario(idUsuario, idCaso)) return null;
    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.caso_tarea (id_caso, descripcion, fecha_limite)
        VALUES ($1, $2, $3) RETURNING *
    `, [idCaso, descripcion, fechaLimite || null]);
    return result.rows[0];
};

const actualizarTarea = async (idUsuario, idCaso, idTarea, completada) => {
    if (!await verificarCasoUsuario(idUsuario, idCaso)) return null;
    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.caso_tarea
        SET completada = $1, fecha_completada = CASE WHEN $1 THEN CURRENT_TIMESTAMP ELSE NULL END
        WHERE id_tarea = $2 AND id_caso = $3 RETURNING *
    `, [completada, idTarea, idCaso]);
    return result.rows[0] || null;
};

const obtenerRecordatorios = async (idUsuario, idCaso) => {
    if (!await verificarCasoUsuario(idUsuario, idCaso)) return null;
    const result = await pool.query(`
        SELECT * FROM SISTEMA_RIEGO.recordatorio_caso
        WHERE id_caso = $1 ORDER BY fecha_recordatorio
    `, [idCaso]);
    return result.rows;
};

const obtenerRecordatoriosUsuario = async (idUsuario) => {
    const result = await pool.query(`
        SELECT
            r.id_recordatorio,
            r.id_caso,
            r.id_tarea,
            r.mensaje,
            r.fecha_recordatorio,
            r.activo,
            c.titulo AS titulo_caso,
            c.estado AS estado_caso,
            p.nombre AS nombre_planta,
            s.nombre AS nombre_sector
        FROM SISTEMA_RIEGO.recordatorio_caso r
        INNER JOIN SISTEMA_RIEGO.caso_planta c ON c.id_caso = r.id_caso
        LEFT JOIN SISTEMA_RIEGO.planta p ON p.id_planta = c.id_planta
        LEFT JOIN SISTEMA_RIEGO.sector s ON s.id_sector = COALESCE(c.id_sector, p.id_sector)
        WHERE c.id_usuario = $1 AND r.activo = TRUE
        ORDER BY r.fecha_recordatorio ASC
    `, [idUsuario]);
    return result.rows;
};

const crearRecordatorio = async (idUsuario, idCaso, mensaje, fechaRecordatorio, idTarea) => {
    if (!await verificarCasoUsuario(idUsuario, idCaso)) return null;
    if (idTarea) {
        const tarea = await pool.query(
            'SELECT id_tarea FROM SISTEMA_RIEGO.caso_tarea WHERE id_tarea = $1 AND id_caso = $2',
            [idTarea, idCaso]
        );
        if (!tarea.rows[0]) return null;
    }
    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.recordatorio_caso
            (id_caso, id_tarea, mensaje, fecha_recordatorio)
        VALUES ($1, $2, $3, $4) RETURNING *
    `, [idCaso, idTarea || null, mensaje, fechaRecordatorio]);
    return result.rows[0];
};

const completarRecordatorio = async (idUsuario, idCaso, idRecordatorio) => {
    if (!await verificarCasoUsuario(idUsuario, idCaso)) return null;
    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.recordatorio_caso
        SET activo = false
        WHERE id_recordatorio = $1 AND id_caso = $2 RETURNING *
    `, [idRecordatorio, idCaso]);
    return result.rows[0] || null;
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
    cambiarEstadoCaso,
    obtenerTareas,
    crearTarea,
    actualizarTarea,
    obtenerRecordatorios,
    obtenerRecordatoriosUsuario,
    crearRecordatorio,
    completarRecordatorio
};
