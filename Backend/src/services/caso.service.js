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
        id_sector,
        pasos
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
        const pasosPersistibles = Array.isArray(pasos)
            ? pasos
            : String(plan_trabajo)
                .split(/\r?\n/)
                .map((linea) => ({ descripcion: linea.replace(/^\s*(?:[-*•]+|\d+[.)])\s*/, '').trim() }));
        const recordatoriosVistos = new Set();
        for (const paso of pasosPersistibles) {
            const descripcion = String(paso.descripcion).trim();
            if (descripcion.length < 3 || /sin pasos de tratamiento registrados|no se requiere ningún plan|definir seguimiento y tratamiento recomendado/i.test(descripcion)) continue;
            const tarea = await client.query(`
                INSERT INTO SISTEMA_RIEGO.caso_tarea (id_caso, descripcion, fecha_limite)
                VALUES ($1, $2, $3)
                RETURNING id_tarea
            `, [caso.id_caso, descripcion, paso.fecha_limite || null]);

            if (paso.recordatorio_fecha && paso.recordatorio_mensaje) {
                const mensaje = String(paso.recordatorio_mensaje).trim();
                const fecha = new Date(paso.recordatorio_fecha);
                if (mensaje && !Number.isNaN(fecha.getTime()) && fecha.getTime() > Date.now()) {
                    const clave = `${mensaje.toLowerCase()}|${fecha.toISOString()}`;
                    if (!recordatoriosVistos.has(clave)) {
                        recordatoriosVistos.add(clave);
                        await client.query(`
                            INSERT INTO SISTEMA_RIEGO.recordatorio_caso
                                (id_caso, id_tarea, mensaje, fecha_recordatorio)
                            VALUES ($1, $2, $3, $4)
                        `, [caso.id_caso, tarea.rows[0].id_tarea, mensaje, fecha.toISOString()]);
                    }
                }
            }
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
            to_jsonb(p)->>'foto_url' AS foto_planta,
            ep.nombre_comun AS especie_nombre_comun,
            ep.nombre_cientifico AS especie_nombre_cientifico,
            s.nombre AS nombre_sector
        FROM SISTEMA_RIEGO.caso_planta c
        LEFT JOIN SISTEMA_RIEGO.planta p
            ON c.id_planta = p.id_planta
        LEFT JOIN SISTEMA_RIEGO.especie_planta ep ON ep.id_especie = p.id_especie
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
            to_jsonb(p)->>'foto_url' AS foto_planta,
            ep.nombre_comun AS especie_nombre_comun,
            ep.nombre_cientifico AS especie_nombre_cientifico,
            COALESCE(c.id_sector, p.id_sector) AS id_sector,
            s.nombre AS nombre_sector,
            j.nombre AS nombre_jardin
        FROM SISTEMA_RIEGO.caso_planta c
        LEFT JOIN SISTEMA_RIEGO.planta p
            ON c.id_planta = p.id_planta
        LEFT JOIN SISTEMA_RIEGO.especie_planta ep ON ep.id_especie = p.id_especie
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
        SELECT r.*, t.descripcion AS tarea_descripcion
        FROM SISTEMA_RIEGO.recordatorio_caso r
        LEFT JOIN SISTEMA_RIEGO.caso_tarea t ON t.id_tarea = r.id_tarea
        WHERE r.id_caso = $1 ORDER BY r.fecha_recordatorio
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
            s.nombre AS nombre_sector,
            t.descripcion AS tarea_descripcion,
            ep.nombre_comun AS especie_nombre_comun,
            ep.nombre_cientifico AS especie_nombre_cientifico
        FROM SISTEMA_RIEGO.recordatorio_caso r
        INNER JOIN SISTEMA_RIEGO.caso_planta c ON c.id_caso = r.id_caso
        LEFT JOIN SISTEMA_RIEGO.planta p ON p.id_planta = c.id_planta
        LEFT JOIN SISTEMA_RIEGO.especie_planta ep ON ep.id_especie = p.id_especie
        LEFT JOIN SISTEMA_RIEGO.sector s ON s.id_sector = COALESCE(c.id_sector, p.id_sector)
        LEFT JOIN SISTEMA_RIEGO.caso_tarea t ON t.id_tarea = r.id_tarea
        WHERE c.id_usuario = $1 AND r.activo = TRUE
          AND c.estado NOT IN ('resuelto', 'abandonado')
        ORDER BY r.fecha_recordatorio ASC
    `, [idUsuario]);
    return result.rows;
};

const crearRecordatorio = async (idUsuario, idCaso, mensaje, fechaRecordatorio, idTarea) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const caso = await client.query(`
            SELECT id_caso FROM SISTEMA_RIEGO.caso_planta
            WHERE id_caso = $1 AND id_usuario = $2 FOR UPDATE
        `, [idCaso, idUsuario]);
        if (!caso.rows[0]) {
            await client.query('ROLLBACK');
            return null;
        }
        if (idTarea) {
            const tarea = await client.query(
                'SELECT id_tarea FROM SISTEMA_RIEGO.caso_tarea WHERE id_tarea = $1 AND id_caso = $2',
                [idTarea, idCaso]
            );
            if (!tarea.rows[0]) {
                await client.query('ROLLBACK');
                return null;
            }
        }
        const existente = await client.query(`
            SELECT * FROM SISTEMA_RIEGO.recordatorio_caso
            WHERE id_caso = $1 AND id_tarea IS NOT DISTINCT FROM $2
              AND LOWER(mensaje) = LOWER($3) AND fecha_recordatorio = $4
              AND activo = TRUE
            LIMIT 1
        `, [idCaso, idTarea || null, mensaje, fechaRecordatorio]);
        if (existente.rows[0]) {
            await client.query('COMMIT');
            return existente.rows[0];
        }
        const result = await client.query(`
            INSERT INTO SISTEMA_RIEGO.recordatorio_caso
                (id_caso, id_tarea, mensaje, fecha_recordatorio)
            VALUES ($1, $2, $3, $4) RETURNING *
        `, [idCaso, idTarea || null, mensaje, fechaRecordatorio]);
        await client.query('COMMIT');
        return result.rows[0];
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
};

const actualizarRecordatorio = async (idUsuario, idCaso, idRecordatorio, mensaje, fechaRecordatorio) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const caso = await client.query(`
            SELECT id_caso FROM SISTEMA_RIEGO.caso_planta
            WHERE id_caso = $1 AND id_usuario = $2 FOR UPDATE
        `, [idCaso, idUsuario]);
        if (!caso.rows[0]) {
            await client.query('ROLLBACK');
            return null;
        }
        const existente = await client.query(`
            SELECT id_recordatorio FROM SISTEMA_RIEGO.recordatorio_caso
            WHERE id_caso = $1 AND id_recordatorio = $2 AND activo = TRUE
            FOR UPDATE
        `, [idCaso, idRecordatorio]);
        if (!existente.rows[0]) {
            await client.query('ROLLBACK');
            return null;
        }
        const duplicado = await client.query(`
            SELECT id_recordatorio FROM SISTEMA_RIEGO.recordatorio_caso
            WHERE id_caso = $1 AND id_recordatorio <> $2 AND activo = TRUE
              AND LOWER(mensaje) = LOWER($3) AND fecha_recordatorio = $4
            LIMIT 1
        `, [idCaso, idRecordatorio, mensaje, fechaRecordatorio]);
        if (duplicado.rows[0]) {
            await client.query('ROLLBACK');
            return 'recordatorio_duplicado';
        }
        const actualizado = await client.query(`
            UPDATE SISTEMA_RIEGO.recordatorio_caso
            SET mensaje = $1, fecha_recordatorio = $2
            WHERE id_recordatorio = $3 AND id_caso = $4 RETURNING *
        `, [mensaje, fechaRecordatorio, idRecordatorio, idCaso]);
        await client.query('COMMIT');
        return actualizado.rows[0] || null;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
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
    imagenUrl,
    idRecordatorio = null
) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const caso = await client.query(`
            SELECT id_caso
            FROM SISTEMA_RIEGO.caso_planta
            WHERE id_caso = $1 AND id_usuario = $2
            FOR UPDATE
        `, [idCaso, idUsuario]);
        if (!caso.rows[0]) {
            await client.query('ROLLBACK');
            return null;
        }

        if (idRecordatorio != null) {
            const recordatorio = await client.query(`
                SELECT id_recordatorio
                FROM SISTEMA_RIEGO.recordatorio_caso
                WHERE id_recordatorio = $1 AND id_caso = $2 AND activo = TRUE
                FOR UPDATE
            `, [idRecordatorio, idCaso]);
            if (!recordatorio.rows[0]) {
                await client.query('ROLLBACK');
                return 'recordatorio_no_encontrado';
            }
        }

        const result = await client.query(`
            INSERT INTO SISTEMA_RIEGO.seguimiento_caso
                (id_caso, nota, imagen_url, id_recordatorio)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `, [idCaso, nota, imagenUrl || null, idRecordatorio]);
        if (idRecordatorio != null) {
            await client.query(`
                UPDATE SISTEMA_RIEGO.recordatorio_caso
                SET activo = FALSE
                WHERE id_recordatorio = $1 AND id_caso = $2
            `, [idRecordatorio, idCaso]);
        }
        await client.query('COMMIT');
        return result.rows[0];
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
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

// Cerrar un caso y registrar el resultado en la bitácora de forma atómica.
const cerrarCasoConResultado = async (idUsuario, idCaso, resultado) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const caso = await client.query(`
            SELECT id_caso, estado FROM SISTEMA_RIEGO.caso_planta
            WHERE id_caso = $1 AND id_usuario = $2 FOR UPDATE
        `, [idCaso, idUsuario]);
        if (!caso.rows[0]) {
            await client.query('ROLLBACK');
            return null;
        }
        if (['resuelto', 'abandonado'].includes(caso.rows[0].estado)) {
            await client.query('ROLLBACK');
            return 'caso_cerrado';
        }

        const seguimiento = await client.query(`
            INSERT INTO SISTEMA_RIEGO.seguimiento_caso (id_caso, nota)
            VALUES ($1, $2) RETURNING *
        `, [idCaso, `Resultado final: ${resultado}`]);
        const actualizado = await client.query(`
            UPDATE SISTEMA_RIEGO.caso_planta
            SET estado = 'resuelto', fecha_cierre = CURRENT_TIMESTAMP
            WHERE id_caso = $1 AND id_usuario = $2 RETURNING *
        `, [idCaso, idUsuario]);
        await client.query('COMMIT');
        return { ...actualizado.rows[0], resultado_final: seguimiento.rows[0] };
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
};

module.exports = {
    crearCaso,
    obtenerCasos,
    contarCasosActivos,
    obtenerCasoPorId,
    agregarSeguimiento,
    cambiarEstadoCaso,
    cerrarCasoConResultado,
    obtenerTareas,
    crearTarea,
    actualizarTarea,
    obtenerRecordatorios,
    obtenerRecordatoriosUsuario,
    crearRecordatorio,
    actualizarRecordatorio,
    completarRecordatorio
};
