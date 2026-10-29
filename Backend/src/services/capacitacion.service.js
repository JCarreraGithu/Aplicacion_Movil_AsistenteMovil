const crypto = require('crypto');
const pool = require('../config/database');

class CapacitacionError extends Error {
    constructor(status, message) {
        super(message);
        this.status = status;
    }
}

const canonicalizar = (value) => {
    if (Array.isArray(value)) return `[${value.map(canonicalizar).join(',')}]`;
    if (value && typeof value === 'object') {
        return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalizar(value[key])}`).join(',')}}`;
    }
    return JSON.stringify(value);
};

const normalizarRespuestas = (answers) => {
    if (!Array.isArray(answers) || answers.length === 0) {
        throw new CapacitacionError(400, 'respuestas debe ser una lista no vacía');
    }
    const normalized = answers.map((item) => {
        const id = Number(item?.id_pregunta_version);
        if (!Number.isInteger(id) || id < 1 || !Object.prototype.hasOwnProperty.call(item, 'respuesta')) {
            throw new CapacitacionError(400, 'Cada respuesta debe incluir id_pregunta_version y respuesta');
        }
        if (JSON.stringify(item.respuesta) === undefined) {
            throw new CapacitacionError(400, 'El formato de la respuesta no es válido');
        }
        return { id_pregunta_version: id, respuesta: item.respuesta };
    }).sort((a, b) => a.id_pregunta_version - b.id_pregunta_version);
    if (normalized.some((item, index) => index > 0 && item.id_pregunta_version === normalized[index - 1].id_pregunta_version)) {
        throw new CapacitacionError(400, 'No se permiten respuestas duplicadas');
    }
    return normalized;
};

const huellaIntento = (idLeccion, idVersion, answers) => crypto
    .createHash('sha256')
    .update(canonicalizar({
        id_leccion: Number(idLeccion),
        id_leccion_version: Number(idVersion),
        respuestas: answers
    }))
    .digest('hex');

const huellaActividad = (idRuta, idActividad, respuesta) => crypto
    .createHash('sha256')
    .update(canonicalizar({ id_ruta: Number(idRuta), id_actividad: Number(idActividad), respuesta }))
    .digest('hex');

const normalizarRespuestaActividad = (respuesta) => {
    if (typeof respuesta === 'string' && respuesta.trim()) return respuesta.trim();
    if (Array.isArray(respuesta) && respuesta.length > 0 && respuesta.every((item) => typeof item === 'string' && item.trim())) {
        return respuesta.map((item) => item.trim());
    }
    throw new CapacitacionError(400, 'La respuesta de la actividad no es válida');
};

const obtenerActividadesRuta = async (db, idRuta, idUsuario) => {
    const result = await db.query(`
        SELECT r.id_ruta, r.slug, r.titulo, r.descripcion,
               v.numero_version, l.id_leccion, l.id_modulo,
               jsonb_agg(jsonb_build_object(
                   'id_actividad', a.id_actividad,
                   'orden', a.orden,
                   'tipo', a.tipo,
                   'titulo', a.titulo,
                   'enunciado', a.enunciado,
                   'icono', a.icono,
                   'opciones', a.opciones,
                   'xp', a.xp,
                   'completada', COALESCE(p.completada, FALSE),
                   'intentos', COALESCE(p.intentos, 0)
               ) ORDER BY a.orden) AS actividades,
               COALESCE(SUM(p.xp_ganado), 0)::int AS xp_ganado,
               COALESCE(SUM(a.xp), 0)::int AS xp_total
        FROM SISTEMA_RIEGO.capacitacion_ruta r
        JOIN SISTEMA_RIEGO.capacitacion_leccion_version v
          ON v.id_leccion_version = r.id_leccion_version
        JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_leccion = v.id_leccion
        JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
        JOIN SISTEMA_RIEGO.capacitacion_actividad a ON a.id_ruta = r.id_ruta
        LEFT JOIN SISTEMA_RIEGO.capacitacion_actividad_progreso p
          ON p.id_ruta = r.id_ruta AND p.id_actividad = a.id_actividad
         AND p.id_usuario = $2
        WHERE r.id_ruta = $1 AND r.estado = 'publicada'
          AND v.estado = 'publicada' AND m.publicado = TRUE
        GROUP BY r.id_ruta, v.numero_version, l.id_leccion, l.id_modulo
    `, [idRuta, idUsuario]);
    return result.rows[0] || null;
};

const resultadoIntento = async (db, idIntento) => {
    const result = await db.query(`
        SELECT i.id_intento, i.id_leccion, i.id_leccion_version, i.respuestas_correctas,
               i.total_preguntas, i.calificacion, i.aprobado, i.fecha_intento,
               jsonb_agg(jsonb_build_object(
                   'id_pregunta_version', q.id_pregunta_version,
                   'respuesta', r.respuesta_usuario,
                   'correcta', r.correcta,
                   'respuesta_correcta', q.respuesta_correcta,
                   'explicacion', q.explicacion
               ) ORDER BY q.orden) AS respuestas
        FROM SISTEMA_RIEGO.capacitacion_intento i
        JOIN SISTEMA_RIEGO.capacitacion_respuesta r
          ON r.id_intento = i.id_intento
        JOIN SISTEMA_RIEGO.capacitacion_pregunta_version q
          ON q.id_leccion_version = r.id_leccion_version
         AND q.id_pregunta_version = r.id_pregunta_version
        WHERE i.id_intento = $1
        GROUP BY i.id_intento
    `, [idIntento]);
    return result.rows[0] || null;
};

const createCapacitacionService = (db = pool) => ({
    async obtenerModulos() {
        const result = await db.query(`
            SELECT m.id_modulo, m.slug, m.titulo, m.descripcion, m.orden,
                   COUNT(DISTINCT l.id_leccion)::int AS total_lecciones
            FROM SISTEMA_RIEGO.capacitacion_modulo m
            JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_modulo = m.id_modulo
            JOIN SISTEMA_RIEGO.capacitacion_leccion_version v ON v.id_leccion = l.id_leccion
            WHERE m.publicado = TRUE AND v.estado = 'publicada'
              AND v.numero_version = (
                  SELECT MAX(v2.numero_version)
                  FROM SISTEMA_RIEGO.capacitacion_leccion_version v2
                  WHERE v2.id_leccion = l.id_leccion AND v2.estado = 'publicada'
              )
            GROUP BY m.id_modulo
            ORDER BY m.orden, m.id_modulo
        `);
        return result.rows;
    },

    async obtenerLeccionesModulo(idModulo, idUsuario) {
        const result = await db.query(`
            SELECT l.id_leccion, l.slug, l.orden,
                   v.id_leccion_version, v.numero_version, v.titulo, v.objetivo,
                   CASE WHEN p.id_leccion_version = v.id_leccion_version
                        THEN COALESCE(p.estado, 'no_iniciado') ELSE 'no_iniciado' END AS estado_progreso,
                   CASE WHEN p.id_leccion_version = v.id_leccion_version
                        THEN p.ultima_calificacion ELSE NULL END AS ultima_calificacion
            FROM SISTEMA_RIEGO.capacitacion_leccion l
            JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
            JOIN LATERAL (
                SELECT v1.* FROM SISTEMA_RIEGO.capacitacion_leccion_version v1
                WHERE v1.id_leccion = l.id_leccion AND v1.estado = 'publicada'
                ORDER BY v1.numero_version DESC LIMIT 1
            ) v ON TRUE
            LEFT JOIN SISTEMA_RIEGO.capacitacion_progreso p
              ON p.id_leccion = l.id_leccion AND p.id_usuario = $2
            WHERE l.id_modulo = $1 AND m.publicado = TRUE
            ORDER BY l.orden, l.id_leccion
        `, [idModulo, idUsuario]);
        return result.rows;
    },

    async obtenerLeccion(idLeccion) {
        const result = await db.query(`
            SELECT l.id_leccion, l.slug, l.orden, m.id_modulo, m.titulo AS modulo,
                   v.id_leccion_version, v.numero_version, v.titulo, v.objetivo,
                   v.contenido, v.calificacion_aprobacion
            FROM SISTEMA_RIEGO.capacitacion_leccion l
            JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
            JOIN LATERAL (
                SELECT v1.* FROM SISTEMA_RIEGO.capacitacion_leccion_version v1
                WHERE v1.id_leccion = l.id_leccion AND v1.estado = 'publicada'
                ORDER BY v1.numero_version DESC LIMIT 1
            ) v ON TRUE
            WHERE l.id_leccion = $1 AND m.publicado = TRUE
        `, [idLeccion]);
        const lesson = result.rows[0];
        if (!lesson) return null;
        const sources = await db.query(`
            SELECT titulo, entidad, url, fecha_consulta, nota_editorial
            FROM SISTEMA_RIEGO.capacitacion_fuente
            WHERE id_leccion_version = $1
            ORDER BY id_fuente
        `, [lesson.id_leccion_version]);
        return { ...lesson, fuentes: sources.rows };
    },

    async obtenerEvaluacion(idLeccion) {
        const result = await db.query(`
            SELECT v.id_leccion_version, v.numero_version, v.calificacion_aprobacion,
                   q.id_pregunta_version, q.orden, q.enunciado, q.tipo, q.opciones
            FROM SISTEMA_RIEGO.capacitacion_leccion l
            JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
            JOIN LATERAL (
                SELECT v1.* FROM SISTEMA_RIEGO.capacitacion_leccion_version v1
                WHERE v1.id_leccion = l.id_leccion AND v1.estado = 'publicada'
                ORDER BY v1.numero_version DESC LIMIT 1
            ) v ON TRUE
            JOIN SISTEMA_RIEGO.capacitacion_pregunta_version q
              ON q.id_leccion_version = v.id_leccion_version
            WHERE l.id_leccion = $1 AND m.publicado = TRUE
            ORDER BY q.orden
        `, [idLeccion]);
        if (result.rows.length === 0) return null;
        const first = result.rows[0];
        return {
            id_leccion_version: first.id_leccion_version,
            numero_version: first.numero_version,
            calificacion_aprobacion: first.calificacion_aprobacion,
            preguntas: result.rows.map(({ id_pregunta_version, orden, enunciado, tipo, opciones }) => ({
                id_pregunta_version, orden, enunciado, tipo, opciones
            }))
        };
    },

    async obtenerRutasModulo(idModulo, idUsuario) {
        const result = await db.query(`
            SELECT r.id_ruta
            FROM SISTEMA_RIEGO.capacitacion_ruta r
            JOIN SISTEMA_RIEGO.capacitacion_leccion_version v
              ON v.id_leccion_version = r.id_leccion_version
            JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_leccion = v.id_leccion
            JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
            WHERE l.id_modulo = $1 AND m.publicado = TRUE
              AND v.estado = 'publicada' AND r.estado = 'publicada'
              AND v.id_leccion_version = (
                  SELECT v2.id_leccion_version
                  FROM SISTEMA_RIEGO.capacitacion_leccion_version v2
                  WHERE v2.id_leccion = l.id_leccion AND v2.estado = 'publicada'
                  ORDER BY v2.numero_version DESC LIMIT 1
              )
            ORDER BY l.orden, r.id_ruta
        `, [idModulo]);
        const routes = [];
        for (const row of result.rows) {
            const route = await obtenerActividadesRuta(db, row.id_ruta, idUsuario);
            if (route) routes.push(route);
        }
        return routes;
    },

    async obtenerRuta(idRuta, idUsuario) {
        return obtenerActividadesRuta(db, idRuta, idUsuario);
    },

    async registrarRespuestaActividad(idUsuario, idRuta, idActividad, idempotencyKey, rawAnswer) {
        if (typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._:-]{8,128}$/.test(idempotencyKey)) {
            throw new CapacitacionError(400, 'Envíe un encabezado Idempotency-Key de 8 a 128 caracteres');
        }
        const answer = normalizarRespuestaActividad(rawAnswer);
        const hash = huellaActividad(idRuta, idActividad, answer);
        const client = await db.connect();
        try {
            await client.query('BEGIN');
            // Serializa los intentos de esta ruta sin exigir UPDATE sobre
            // capacitacion_ruta al usuario de aplicación. La fila publicada
            // es inmutable; la clave idempotente también se serializa abajo.
            await client.query(
                'SELECT pg_advisory_xact_lock($1, $2)',
                [943711, Number(idRuta)]
            );
            await client.query(
                'SELECT pg_advisory_xact_lock($1, hashtext($2))',
                [943712, `${idUsuario}:${idempotencyKey}`]
            );
            const routeResult = await client.query(`
                SELECT r.id_ruta
                FROM SISTEMA_RIEGO.capacitacion_ruta r
                JOIN SISTEMA_RIEGO.capacitacion_leccion_version v ON v.id_leccion_version = r.id_leccion_version
                JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_leccion = v.id_leccion
                JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
                WHERE r.id_ruta = $1 AND r.estado = 'publicada'
                  AND v.estado = 'publicada' AND m.publicado = TRUE
            `, [idRuta]);
            if (!routeResult.rows[0]) throw new CapacitacionError(404, 'Ruta publicada no encontrada');

            const activityResult = await client.query(`
                SELECT id_actividad, id_ruta, orden, xp, respuesta_correcta, explicacion
                FROM SISTEMA_RIEGO.capacitacion_actividad
                WHERE id_ruta = $1 AND id_actividad = $2
            `, [idRuta, idActividad]);
            const activity = activityResult.rows[0];
            if (!activity) throw new CapacitacionError(404, 'Actividad no encontrada');

            const prior = await client.query(`
                SELECT id_intento, id_ruta, id_actividad, huella_solicitud,
                       respuesta_usuario, correcta, xp_otorgado
                FROM SISTEMA_RIEGO.capacitacion_actividad_intento
                WHERE id_usuario = $1 AND clave_idempotencia = $2
            `, [idUsuario, idempotencyKey]);
            if (prior.rows[0]) {
                const old = prior.rows[0];
                if (Number(old.id_ruta) !== Number(idRuta)
                    || Number(old.id_actividad) !== Number(idActividad)
                    || old.huella_solicitud !== hash) {
                    throw new CapacitacionError(409, 'La clave de idempotencia ya se usó con otra respuesta');
                }
                const xp = await client.query(`
                    SELECT COALESCE(SUM(xp_ganado), 0)::int AS xp_total
                    FROM SISTEMA_RIEGO.capacitacion_actividad_progreso WHERE id_usuario = $1
                `, [idUsuario]);
                await client.query('COMMIT');
                return {
                    id_ruta: Number(idRuta), id_actividad: Number(idActividad),
                    respuesta: old.respuesta_usuario, correcta: old.correcta,
                    respuesta_correcta: activity.respuesta_correcta,
                    explicacion: activity.explicacion, xp_otorgado: old.xp_otorgado,
                    xp_total: xp.rows[0].xp_total, repetido: true
                };
            }

            const previous = await client.query(`
                SELECT COUNT(*)::int AS pendientes
                FROM SISTEMA_RIEGO.capacitacion_actividad a
                LEFT JOIN SISTEMA_RIEGO.capacitacion_actividad_progreso p
                  ON p.id_ruta = a.id_ruta AND p.id_actividad = a.id_actividad
                 AND p.id_usuario = $2 AND p.completada = TRUE
                WHERE a.id_ruta = $1 AND a.orden < $3 AND p.id_actividad IS NULL
            `, [idRuta, idUsuario, activity.orden]);
            if (previous.rows[0].pendientes > 0) {
                throw new CapacitacionError(409, 'Completa los desafíos anteriores para continuar');
            }

            const correct = canonicalizar(answer) === canonicalizar(activity.respuesta_correcta);
            const current = await client.query(`
                SELECT completada FROM SISTEMA_RIEGO.capacitacion_actividad_progreso
                WHERE id_usuario = $1 AND id_actividad = $2 FOR UPDATE
            `, [idUsuario, idActividad]);
            const reward = correct && !current.rows[0]?.completada ? Number(activity.xp) : 0;
            await client.query(`
                INSERT INTO SISTEMA_RIEGO.capacitacion_actividad_intento
                    (id_usuario, id_ruta, id_actividad, clave_idempotencia,
                     huella_solicitud, respuesta_usuario, correcta, xp_otorgado)
                VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8)
            `, [idUsuario, idRuta, idActividad, idempotencyKey, hash, JSON.stringify(answer), correct, reward]);
            await client.query(`
                INSERT INTO SISTEMA_RIEGO.capacitacion_actividad_progreso
                    (id_usuario, id_ruta, id_actividad, intentos, completada,
                     xp_ganado, fecha_completado, fecha_actualizacion)
                VALUES ($1, $2, $3, 1, $4, $5,
                        CASE WHEN $4 THEN CURRENT_TIMESTAMP ELSE NULL END,
                        CURRENT_TIMESTAMP)
                ON CONFLICT (id_usuario, id_actividad) DO UPDATE SET
                    intentos = SISTEMA_RIEGO.capacitacion_actividad_progreso.intentos + 1,
                    completada = SISTEMA_RIEGO.capacitacion_actividad_progreso.completada OR EXCLUDED.completada,
                    xp_ganado = SISTEMA_RIEGO.capacitacion_actividad_progreso.xp_ganado + EXCLUDED.xp_ganado,
                    fecha_completado = COALESCE(SISTEMA_RIEGO.capacitacion_actividad_progreso.fecha_completado, EXCLUDED.fecha_completado),
                    fecha_actualizacion = CURRENT_TIMESTAMP
            `, [idUsuario, idRuta, idActividad, correct, reward]);
            const xp = await client.query(`
                SELECT COALESCE(SUM(xp_ganado), 0)::int AS xp_total
                FROM SISTEMA_RIEGO.capacitacion_actividad_progreso WHERE id_usuario = $1
            `, [idUsuario]);
            await client.query('COMMIT');
            return {
                id_ruta: Number(idRuta), id_actividad: Number(idActividad),
                respuesta: answer, correcta: correct,
                respuesta_correcta: activity.respuesta_correcta,
                explicacion: activity.explicacion,
                xp_otorgado: reward, xp_total: xp.rows[0].xp_total,
                repetido: false
            };
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    },

    async registrarIntento(idUsuario, idLeccion, idVersion, idempotencyKey, rawAnswers) {
        if (typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._:-]{8,128}$/.test(idempotencyKey)) {
            throw new CapacitacionError(400, 'Envíe un encabezado Idempotency-Key de 8 a 128 caracteres');
        }
        const versionId = Number(idVersion);
        if (!Number.isInteger(versionId) || versionId < 1) {
            throw new CapacitacionError(400, 'id_leccion_version debe ser un entero positivo');
        }
        const answers = normalizarRespuestas(rawAnswers);
        const hash = huellaIntento(idLeccion, versionId, answers);
        const client = await db.connect();
        try {
            await client.query('BEGIN');

            const prior = await client.query(`
                SELECT id_intento, id_leccion, id_leccion_version, huella_solicitud
                FROM SISTEMA_RIEGO.capacitacion_intento
                WHERE id_usuario = $1 AND clave_idempotencia = $2
                FOR UPDATE
            `, [idUsuario, idempotencyKey]);
            if (prior.rows[0]) {
                if (Number(prior.rows[0].id_leccion) !== Number(idLeccion)
                    || Number(prior.rows[0].id_leccion_version) !== versionId
                    || prior.rows[0].huella_solicitud !== hash) {
                    throw new CapacitacionError(409, 'La clave de idempotencia ya se usó con otras respuestas');
                }
                const existing = await resultadoIntento(client, prior.rows[0].id_intento);
                await client.query('COMMIT');
                return { ...existing, repetido: true };
            }

            const versionResult = await client.query(`
                SELECT v.id_leccion_version, v.calificacion_aprobacion
                FROM SISTEMA_RIEGO.capacitacion_leccion_version v
                JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_leccion = v.id_leccion
                JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
                WHERE l.id_leccion = $1 AND v.id_leccion_version = $2
                  AND v.estado = 'publicada' AND m.publicado = TRUE
            `, [idLeccion, versionId]);
            if (!versionResult.rows[0]) throw new CapacitacionError(404, 'Lección publicada no encontrada');

            const questionsResult = await client.query(`
                SELECT id_pregunta_version, orden, respuesta_correcta, explicacion
                FROM SISTEMA_RIEGO.capacitacion_pregunta_version
                WHERE id_leccion_version = $1 ORDER BY orden
            `, [versionId]);
            const questions = questionsResult.rows;
            if (questions.length === 0) throw new CapacitacionError(409, 'La evaluación no tiene preguntas publicadas');
            if (answers.length !== questions.length || questions.some((q) => !answers.some((a) => a.id_pregunta_version === q.id_pregunta_version))) {
                throw new CapacitacionError(400, 'Debe responder cada pregunta de la evaluación exactamente una vez');
            }

            const graded = questions.map((question) => {
                const answer = answers.find((item) => item.id_pregunta_version === question.id_pregunta_version);
                return {
                    question,
                    response: answer.respuesta,
                    correct: canonicalizar(answer.respuesta) === canonicalizar(question.respuesta_correcta)
                };
            });
            const correctCount = graded.filter((item) => item.correct).length;
            const score = Math.round((correctCount * 10000) / questions.length) / 100;
            const threshold = Number(versionResult.rows[0].calificacion_aprobacion);
            const passed = score >= threshold;

            const inserted = await client.query(`
                INSERT INTO SISTEMA_RIEGO.capacitacion_intento
                    (id_usuario, id_leccion, id_leccion_version, clave_idempotencia,
                     huella_solicitud, respuestas_correctas, total_preguntas, calificacion, aprobado)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                ON CONFLICT (id_usuario, clave_idempotencia) DO NOTHING
                RETURNING id_intento
            `, [idUsuario, idLeccion, versionId, idempotencyKey, hash, correctCount, questions.length, score, passed]);

            if (!inserted.rows[0]) {
                const duplicate = await client.query(`
                    SELECT id_intento, id_leccion, id_leccion_version, huella_solicitud
                    FROM SISTEMA_RIEGO.capacitacion_intento
                    WHERE id_usuario = $1 AND clave_idempotencia = $2 FOR UPDATE
                `, [idUsuario, idempotencyKey]);
                if (Number(duplicate.rows[0].id_leccion) !== Number(idLeccion)
                    || Number(duplicate.rows[0].id_leccion_version) !== versionId
                    || duplicate.rows[0].huella_solicitud !== hash) {
                    throw new CapacitacionError(409, 'La clave de idempotencia ya se usó con otras respuestas');
                }
                const existing = await resultadoIntento(client, duplicate.rows[0].id_intento);
                await client.query('COMMIT');
                return { ...existing, repetido: true };
            }

            const attemptId = inserted.rows[0].id_intento;
            for (const item of graded) {
                await client.query(`
                    INSERT INTO SISTEMA_RIEGO.capacitacion_respuesta
                        (id_intento, id_leccion_version, id_pregunta_version, respuesta_usuario, correcta)
                    VALUES ($1, $2, $3, $4::jsonb, $5)
                `, [attemptId, versionId, item.question.id_pregunta_version, JSON.stringify(item.response), item.correct]);
            }

            await client.query(`
                INSERT INTO SISTEMA_RIEGO.capacitacion_progreso
                    (id_usuario, id_leccion, id_leccion_version, estado,
                     ultima_calificacion, fecha_inicio, fecha_completado, fecha_actualizacion)
                VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP,
                        CASE WHEN $4 = 'completado' THEN CURRENT_TIMESTAMP ELSE NULL END,
                        CURRENT_TIMESTAMP)
                ON CONFLICT (id_usuario, id_leccion) DO UPDATE SET
                    id_leccion_version = EXCLUDED.id_leccion_version,
                    estado = CASE WHEN EXCLUDED.estado = 'completado'
                        OR (SISTEMA_RIEGO.capacitacion_progreso.id_leccion_version = EXCLUDED.id_leccion_version
                            AND SISTEMA_RIEGO.capacitacion_progreso.estado = 'completado')
                        THEN 'completado' ELSE 'en_progreso' END,
                    ultima_calificacion = EXCLUDED.ultima_calificacion,
                    fecha_inicio = CASE
                        WHEN SISTEMA_RIEGO.capacitacion_progreso.id_leccion_version = EXCLUDED.id_leccion_version
                        THEN COALESCE(SISTEMA_RIEGO.capacitacion_progreso.fecha_inicio, CURRENT_TIMESTAMP)
                        ELSE CURRENT_TIMESTAMP END,
                    fecha_completado = CASE WHEN EXCLUDED.estado = 'completado'
                        OR (SISTEMA_RIEGO.capacitacion_progreso.id_leccion_version = EXCLUDED.id_leccion_version
                            AND SISTEMA_RIEGO.capacitacion_progreso.estado = 'completado')
                        THEN CASE WHEN SISTEMA_RIEGO.capacitacion_progreso.id_leccion_version = EXCLUDED.id_leccion_version
                                  THEN COALESCE(SISTEMA_RIEGO.capacitacion_progreso.fecha_completado, CURRENT_TIMESTAMP)
                                  ELSE CURRENT_TIMESTAMP END
                        ELSE NULL END,
                    fecha_actualizacion = CURRENT_TIMESTAMP
            `, [idUsuario, idLeccion, versionId, passed ? 'completado' : 'en_progreso', score]);

            const outcome = await resultadoIntento(client, attemptId);
            await client.query('COMMIT');
            return { ...outcome, repetido: false };
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    },

    async obtenerProgreso(idUsuario) {
        const result = await db.query(`
            SELECT m.id_modulo, m.titulo AS modulo,
                   l.id_leccion, l.slug,
                   v.id_leccion_version, v.numero_version, v.titulo AS leccion,
                   CASE WHEN p.id_leccion_version = v.id_leccion_version
                        THEN COALESCE(p.estado, 'no_iniciado') ELSE 'no_iniciado' END AS estado,
                   CASE WHEN p.id_leccion_version = v.id_leccion_version
                        THEN p.ultima_calificacion ELSE NULL END AS ultima_calificacion,
                   CASE WHEN p.id_leccion_version = v.id_leccion_version
                        THEN p.fecha_inicio ELSE NULL END AS fecha_inicio,
                   CASE WHEN p.id_leccion_version = v.id_leccion_version
                        THEN p.fecha_completado ELSE NULL END AS fecha_completado
            FROM SISTEMA_RIEGO.capacitacion_modulo m
            JOIN SISTEMA_RIEGO.capacitacion_leccion l ON l.id_modulo = m.id_modulo
            JOIN LATERAL (
                SELECT v1.* FROM SISTEMA_RIEGO.capacitacion_leccion_version v1
                WHERE v1.id_leccion = l.id_leccion AND v1.estado = 'publicada'
                ORDER BY v1.numero_version DESC LIMIT 1
            ) v ON TRUE
            LEFT JOIN SISTEMA_RIEGO.capacitacion_progreso p
              ON p.id_usuario = $1 AND p.id_leccion = l.id_leccion
            WHERE m.publicado = TRUE
            ORDER BY m.orden, l.orden
        `, [idUsuario]);
        return result.rows;
    }
});

const capacitacionService = createCapacitacionService();
module.exports = {
    ...capacitacionService,
    createCapacitacionService,
    CapacitacionError,
    normalizarRespuestas,
    huellaIntento,
    normalizarRespuestaActividad,
    huellaActividad
};
