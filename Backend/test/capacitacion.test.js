const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const verificarToken = require('../src/middlewares/auth.middleware');
const {
    createCapacitacionService,
    normalizarRespuestas,
    huellaIntento,
    normalizarRespuestaActividad,
    huellaActividad,
    CapacitacionError
} = require('../src/services/capacitacion.service');
const { crearCapacitacionController } = require('../src/controllers/capacitacion.controller');

const raiz = path.resolve(__dirname, '..', '..');

test('normaliza respuestas y rechaza entradas duplicadas', () => {
    const normalized = normalizarRespuestas([
        { id_pregunta_version: 2, respuesta: 'b' },
        { id_pregunta_version: 1, respuesta: 'a' }
    ]);
    assert.deepEqual(normalized.map((item) => item.id_pregunta_version), [1, 2]);
    assert.throws(() => normalizarRespuestas([
        { id_pregunta_version: 1, respuesta: 'a' },
        { id_pregunta_version: 1, respuesta: 'b' }
    ]), CapacitacionError);
});

test('la huella incluye lección, versión y respuestas normalizadas', () => {
    const answers = [{ id_pregunta_version: 4, respuesta: 'a' }];
    assert.notEqual(huellaIntento(5, 12, answers), huellaIntento(6, 12, answers));
    assert.notEqual(huellaIntento(5, 12, answers), huellaIntento(5, 13, answers));
    assert.equal(
        huellaIntento(5, 12, answers),
        huellaIntento(5, 12, [{ id_pregunta_version: 4, respuesta: 'a' }])
    );
});

test('normaliza respuestas de actividades y su huella incluye ruta, actividad y respuesta', () => {
    assert.deepEqual(normalizarRespuestaActividad([' suelo ', 'decidir']), ['suelo', 'decidir']);
    assert.equal(normalizarRespuestaActividad(' a '), 'a');
    assert.throws(() => normalizarRespuestaActividad([]), CapacitacionError);
    assert.notEqual(huellaActividad(1, 2, 'a'), huellaActividad(2, 2, 'a'));
    assert.notEqual(huellaActividad(1, 2, 'a'), huellaActividad(1, 3, 'a'));
    assert.notEqual(huellaActividad(1, 2, 'a'), huellaActividad(1, 2, 'b'));
});

test('califica desafíos en servidor, registra progreso por usuario e idempotencia', async () => {
    const state = { attempts: [], progress: new Map(), nextId: 1 };
    const sqlEjecutado = [];
    const activity = {
        id_actividad: 21, id_ruta: 4, orden: 1, xp: 10,
        respuesta_correcta: 'b', explicacion: 'Observa el suelo antes de decidir.'
    };
    const fakeDb = {
        connect: async () => ({
            query: async (sql, params = []) => {
                sqlEjecutado.push(sql);
                if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(sql)) return { rows: [] };
                if (/pg_advisory_xact_lock/.test(sql)) return { rows: [] };
                if (/SELECT r\.id_ruta/.test(sql)) return { rows: [{ id_ruta: 4 }] };
                if (/SELECT id_actividad, id_ruta, orden, xp, respuesta_correcta/.test(sql)) return { rows: [activity] };
                if (/FROM SISTEMA_RIEGO\.capacitacion_actividad_intento/.test(sql)) {
                    const hit = state.attempts.find((item) => item.user === params[0] && item.clave_idempotencia === params[1]);
                    return { rows: hit ? [{ ...hit }] : [] };
                }
                if (/SELECT COUNT\(\*\)::int AS pendientes/.test(sql)) return { rows: [{ pendientes: 0 }] };
                if (/SELECT completada FROM SISTEMA_RIEGO\.capacitacion_actividad_progreso/.test(sql)) {
                    const hit = state.progress.get(`${params[0]}:${params[1]}`);
                    return { rows: hit ? [{ completada: hit.completada }] : [] };
                }
                if (/INSERT INTO SISTEMA_RIEGO\.capacitacion_actividad_intento/.test(sql)) {
                    const row = {
                        id_intento: state.nextId++, id_ruta: params[1], id_actividad: params[2],
                        user: params[0], clave_idempotencia: params[3], huella_solicitud: params[4],
                        respuesta_usuario: JSON.parse(params[5]), correcta: params[6], xp_otorgado: params[7]
                    };
                    state.attempts.push(row);
                    return { rows: [{ id_intento: row.id_intento }] };
                }
                if (/INSERT INTO SISTEMA_RIEGO\.capacitacion_actividad_progreso/.test(sql)) {
                    const key = `${params[0]}:${params[2]}`;
                    const previous = state.progress.get(key);
                    state.progress.set(key, {
                        user: params[0], id_actividad: params[2],
                        intentos: (previous?.intentos || 0) + 1,
                        completada: Boolean(previous?.completada || params[3]),
                        xp_ganado: (previous?.xp_ganado || 0) + params[4]
                    });
                    return { rows: [] };
                }
                if (/SELECT COALESCE\(SUM\(xp_ganado\)/.test(sql)) {
                    const xp = [...state.progress.values()].filter((row) => row.user === params[0]).reduce((sum, row) => sum + row.xp_ganado, 0);
                    return { rows: [{ xp_total: xp }] };
                }
                throw new Error(`SQL de test no reconocido: ${sql}`);
            },
            release() {}
        })
    };
    const service = createCapacitacionService(fakeDb);
    const wrong = await service.registrarRespuestaActividad(7, 4, 21, 'activity-key-01', 'a');
    assert.equal(wrong.correcta, false);
    assert.equal(wrong.xp_otorgado, 0);
    assert.equal(state.attempts.length, 1);
    assert.equal(state.progress.get('7:21').completada, false);

    const retry = await service.registrarRespuestaActividad(7, 4, 21, 'activity-key-01', 'a');
    assert.equal(retry.repetido, true);
    assert.equal(state.attempts.length, 1);
    await assert.rejects(
        service.registrarRespuestaActividad(7, 4, 21, 'activity-key-01', 'b'),
        (error) => error.status === 409
    );

    const correct = await service.registrarRespuestaActividad(7, 4, 21, 'activity-key-02', 'b');
    assert.equal(correct.correcta, true);
    assert.equal(correct.xp_otorgado, 10);
    assert.equal(correct.xp_total, 10);
    assert.equal(state.progress.get('7:21').completada, true);
    const anotherUser = await service.registrarRespuestaActividad(8, 4, 21, 'activity-key-01', 'b');
    assert.equal(anotherUser.correcta, true);
    assert.equal(anotherUser.xp_otorgado, 10);
    assert.equal(state.attempts.filter((item) => item.user === 8).length, 1);
    assert.ok(sqlEjecutado.some((sql) => /pg_advisory_xact_lock/.test(sql)));
    assert.ok(sqlEjecutado.some((sql) => /hashtext\(\$2\)/.test(sql)));
    assert.ok(sqlEjecutado.some((sql) => /FROM SISTEMA_RIEGO\.capacitacion_ruta/.test(sql) && !/FOR UPDATE OF r/.test(sql)));
    assert.ok(sqlEjecutado.some((sql) => /FROM SISTEMA_RIEGO\.capacitacion_actividad_intento/.test(sql) && !/FOR UPDATE/.test(sql)));
});

test('rutas solo usan la versión publicada más reciente por número', async () => {
    let sql;
    const service = createCapacitacionService({ query: async (query) => { sql = query; return { rows: [] }; } });
    assert.deepEqual(await service.obtenerRutasModulo(1, 9), []);
    assert.match(sql, /ORDER BY v2\.numero_version DESC LIMIT 1/);
});

test('el catálogo requiere módulo y versión publicados', async () => {
    let sql;
    const service = createCapacitacionService({
        query: async (query) => { sql = query; return { rows: [{ id_modulo: 1, total_lecciones: 1 }] }; }
    });
    const modules = await service.obtenerModulos();
    assert.equal(modules[0].id_modulo, 1);
    assert.match(sql, /m\.publicado = TRUE/);
    assert.match(sql, /v\.estado = 'publicada'/);
});

test('lecciones consultan la versión publicada más reciente y progreso del usuario autenticado', async () => {
    let params;
    let sql;
    const service = createCapacitacionService({
        query: async (query, values) => { sql = query; params = values; return { rows: [] }; }
    });
    assert.deepEqual(await service.obtenerLeccionesModulo(8, 42), []);
    assert.deepEqual(params, [8, 42]);
    assert.match(sql, /ORDER BY v1\.numero_version DESC LIMIT 1/);
    assert.match(sql, /p\.id_usuario = \$2/);
});

test('la evaluación pública no consulta ni retorna respuestas correctas o explicaciones', async () => {
    let sql;
    const service = createCapacitacionService({
        query: async (query) => {
            sql = query;
            return { rows: [{ id_leccion_version: 12, numero_version: 1, calificacion_aprobacion: '70', id_pregunta_version: 90, orden: 1, enunciado: 'Pregunta', tipo: 'opcion_multiple', opciones: [{ clave: 'a', texto: 'A' }] }] };
        }
    });
    const evaluation = await service.obtenerEvaluacion(5);
    assert.equal(evaluation.preguntas.length, 1);
    assert.equal(Object.hasOwn(evaluation.preguntas[0], 'respuesta_correcta'), false);
    assert.equal(Object.hasOwn(evaluation.preguntas[0], 'explicacion'), false);
    assert.doesNotMatch(sql, /respuesta_correcta|explicacion/);
});

test('califica en backend, guarda una sola vez y repite resultado por Idempotency-Key', async () => {
    const state = { attempts: [], answers: [], progress: null, attemptId: 17 };
    const questions = [
        { id_pregunta_version: 101, orden: 1, respuesta_correcta: 'a', explicacion: 'Explicación A' },
        { id_pregunta_version: 102, orden: 2, respuesta_correcta: 'falso', explicacion: 'Explicación B' }
    ];
    const fakeDb = {
        connect: async () => ({
            query: async (sql, params = []) => {
                if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') return { rows: [] };
                if (/SELECT id_intento, id_leccion, id_leccion_version, huella_solicitud/.test(sql)) {
                    const attempt = state.attempts.find((item) => item.user === params[0] && item.key === params[1]);
                    return { rows: attempt ? [{ id_intento: attempt.id, id_leccion: attempt.lesson, id_leccion_version: attempt.version, huella_solicitud: attempt.hash }] : [] };
                }
                if (/SELECT v\.id_leccion_version, v\.calificacion_aprobacion/.test(sql)) {
                    return { rows: [{ id_leccion_version: 12, calificacion_aprobacion: '70' }] };
                }
                if (/SELECT id_pregunta_version, orden, respuesta_correcta/.test(sql)) return { rows: questions };
                if (/INSERT INTO SISTEMA_RIEGO\.capacitacion_intento/.test(sql)) {
                    if (state.attempts.some((item) => item.user === params[0] && item.key === params[3])) return { rows: [] };
                    const id = state.attemptId++;
                    state.attempts.push({ id, user: params[0], key: params[3], hash: params[4], lesson: params[1], version: params[2], correct: params[5], total: params[6], score: params[7], passed: params[8] });
                    return { rows: [{ id_intento: id }] };
                }
                if (/INSERT INTO SISTEMA_RIEGO\.capacitacion_respuesta/.test(sql)) {
                    state.answers.push({ id_intento: params[0], id_pregunta_version: params[2], respuesta_usuario: JSON.parse(params[3]), correcta: params[4] });
                    return { rows: [] };
                }
                if (/INSERT INTO SISTEMA_RIEGO\.capacitacion_progreso/.test(sql)) {
                    state.progress = { user: params[0], lesson: params[1], version: params[2], state: params[3], score: params[4] };
                    return { rows: [] };
                }
                if (/SELECT i\.id_intento/.test(sql)) {
                    const attempt = state.attempts.find((item) => item.id === params[0]);
                    return { rows: [{ id_intento: attempt.id, id_leccion: attempt.lesson, id_leccion_version: attempt.version, respuestas_correctas: attempt.correct, total_preguntas: attempt.total, calificacion: attempt.score, aprobado: attempt.passed, respuestas: state.answers.filter((answer) => answer.id_intento === attempt.id).map((answer) => ({ ...answer, respuesta_correcta: questions.find((q) => q.id_pregunta_version === answer.id_pregunta_version).respuesta_correcta, explicacion: questions.find((q) => q.id_pregunta_version === answer.id_pregunta_version).explicacion })) }] };
                }
                throw new Error(`SQL de test no reconocido: ${sql}`);
            },
            release() {}
        })
    };
    const service = createCapacitacionService(fakeDb);
    const body = [
        { id_pregunta_version: 101, respuesta: 'a' },
        { id_pregunta_version: 102, respuesta: 'verdadero' }
    ];
    const first = await service.registrarIntento(7, 5, 12, 'request-123456', body);
    assert.equal(first.calificacion, 50);
    assert.equal(first.aprobado, false);
    assert.deepEqual(state.progress, { user: 7, lesson: 5, version: 12, state: 'en_progreso', score: 50 });
    assert.equal(state.answers.length, 2);
    assert.equal(first.respuestas[0].respuesta_correcta, 'a');

    const retry = await service.registrarIntento(7, 5, 12, 'request-123456', body);
    assert.equal(retry.repetido, true);
    assert.equal(state.answers.length, 2);
    await assert.rejects(
        service.registrarIntento(7, 5, 12, 'request-123456', [
            { id_pregunta_version: 101, respuesta: 'b' },
            { id_pregunta_version: 102, respuesta: 'verdadero' }
        ]),
        (error) => error.status === 409
    );
    await assert.rejects(
        service.registrarIntento(7, 6, 12, 'request-123456', body),
        (error) => error.status === 409
    );

    const otherUser = await service.registrarIntento(8, 5, 12, 'request-123456', body);
    assert.equal(otherUser.repetido, false);
    assert.equal(state.attempts.length, 2);
    assert.equal(state.attempts[0].user, 7);
    assert.equal(state.attempts[1].user, 8);
});

test('rechaza versión no publicada y respuestas faltantes antes de crear intento', async () => {
    let inserted = false;
    const fakeDb = {
        connect: async () => ({
            query: async (sql) => {
                if (sql === 'BEGIN' || sql === 'ROLLBACK') return { rows: [] };
                if (/SELECT id_intento, id_leccion, id_leccion_version, huella_solicitud/.test(sql)) return { rows: [] };
                if (/SELECT v\.id_leccion_version/.test(sql)) return { rows: [] };
                if (/INSERT INTO SISTEMA_RIEGO\.capacitacion_intento/.test(sql)) inserted = true;
                return { rows: [] };
            }, release() {}
        })
    };
    const service = createCapacitacionService(fakeDb);
    await assert.rejects(service.registrarIntento(1, 1, 2, 'request-123456', [{ id_pregunta_version: 1, respuesta: 'a' }]), (error) => error.status === 404);
    assert.equal(inserted, false);
});

test('progreso siempre filtra por usuario JWT y solo incluye contenido publicado', async () => {
    let sql;
    let params;
    const service = createCapacitacionService({
        query: async (query, values) => { sql = query; params = values; return { rows: [] }; }
    });
    await service.obtenerProgreso(91);
    assert.deepEqual(params, [91]);
    assert.match(sql, /p\.id_usuario = \$1/);
    assert.match(sql, /m\.publicado = TRUE/);
    assert.match(sql, /CASE WHEN p\.id_leccion_version = v\.id_leccion_version/);
});

test('middleware JWT bloquea anónimos y el controlador deriva el progreso del token', async () => {
    process.env.JWT_SECRET = 'test-capacitacion-secret';
    const seenUsers = [];
    const seenActivityUsers = [];
    const controller = crearCapacitacionController({
        obtenerModulos: async () => [],
        obtenerLeccionesModulo: async () => [],
        obtenerLeccion: async () => null,
        obtenerEvaluacion: async () => null,
        obtenerRutasModulo: async (moduleId, userId) => { seenActivityUsers.push(userId); return [{ moduleId }]; },
        obtenerRuta: async (routeId, userId) => { seenActivityUsers.push(userId); return { routeId }; },
        registrarRespuestaActividad: async (userId) => { seenActivityUsers.push(userId); return { userId, repetido: false }; },
        registrarIntento: async (userId) => ({ userId, repetido: false }),
        obtenerProgreso: async (userId) => { seenUsers.push(userId); return [{ id_usuario: userId }]; }
    });
    const response = () => ({
        statusCode: 200,
        body: null,
        status(code) { this.statusCode = code; return this; },
        json(body) { this.body = body; return this; }
    });
    const anonResponse = response();
    verificarToken({ headers: {} }, anonResponse, () => {});
    assert.equal(anonResponse.statusCode, 401);

    const token = jwt.sign({ id_usuario: 23 }, process.env.JWT_SECRET);
    const req = { headers: { authorization: `Bearer ${token}` }, query: {} };
    const authorized = response();
    await new Promise((resolve, reject) => verificarToken(req, authorized, (error) => error ? reject(error) : resolve()));
    assert.equal(req.usuario.id_usuario, 23);
    await controller.obtenerProgreso(req, authorized, (error) => { if (error) throw error; });
    assert.equal(authorized.statusCode, 200);
    assert.deepEqual(seenUsers, [23]);

    req.params = { idModulo: '5', idRuta: '6', idActividad: '7' };
    await controller.obtenerRutasModulo(req, authorized, (error) => { if (error) throw error; });
    req.get = (header) => header === 'Idempotency-Key' ? 'activity-key-123' : undefined;
    req.body = { respuesta: 'a' };
    await controller.registrarRespuestaActividad(req, authorized, (error) => { if (error) throw error; });
    assert.deepEqual(seenActivityUsers, [23, 23]);
    assert.equal(authorized.statusCode, 201);

    req.query.id_usuario = '99';
    const otherUser = response();
    await controller.obtenerProgreso(req, otherUser, (error) => { if (error) throw error; });
    assert.equal(otherUser.statusCode, 400);
    assert.deepEqual(seenUsers, [23]);
});

test('migración compatible con esquema existente, idempotente y con piloto no publicado', () => {
    const migration = fs.readFileSync(path.join(raiz, 'Backend', 'migrations', '2026_add_capacitacion.sql'), 'utf8');
    const schema = fs.readFileSync(path.join(raiz, 'DB'), 'utf8');
    assert.match(schema, /CREATE TABLE usuario\s*\(\s*id_usuario SERIAL PRIMARY KEY/i);
    assert.match(migration, /REFERENCES SISTEMA_RIEGO\.usuario\(id_usuario\)/);
    assert.match(migration, /CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO\.capacitacion_progreso/);
    assert.match(migration, /ON CONFLICT \(slug\) DO NOTHING/);
    assert.match(migration, /'Fundamentos del riego'[\s\S]*FALSE/);
    assert.match(migration, /estado = 'borrador'/);
    assert.match(migration, /proteger_capacitacion_publicada/);
    assert.match(migration, /WHERE id_leccion_version = ANY\(ids_version\)[\s\S]*FOR UPDATE/);
    assert.match(migration, /FOR UPDATE\s+LOOP/);
    assert.match(migration, /BEFORE UPDATE OR DELETE ON SISTEMA_RIEGO\.capacitacion_leccion_version/);
    assert.match(migration, /BEFORE INSERT OR UPDATE OR DELETE ON SISTEMA_RIEGO\.capacitacion_pregunta_version/);
    assert.match(migration, /BEFORE INSERT OR UPDATE OR DELETE ON SISTEMA_RIEGO\.capacitacion_fuente/);
    assert.match(migration, /ids_version := ARRAY\[NEW\.id_leccion_version\]/);
    assert.match(migration, /ids_version := ARRAY\[OLD\.id_leccion_version\]/);
    assert.match(migration, /ids_version := ARRAY\[OLD\.id_leccion_version, NEW\.id_leccion_version\]/);
    assert.match(migration, /IF version_bloqueada\.estado = 'publicada'/);
    assert.match(migration, /UNIQUE \(id_usuario, clave_idempotencia\)/);
    assert.doesNotMatch(migration, /\bDROP\s+TABLE\b|\bALTER\s+TABLE\b|\bTRUNCATE\b/i);
});

test('la migración gamificada es aditiva, protege rutas publicadas y deja el seed en borrador', () => {
    const migration = fs.readFileSync(path.join(raiz, 'Backend', 'migrations', '2026_add_capacitacion_gamificada.sql'), 'utf8');
    const rollback = fs.readFileSync(path.join(raiz, 'Backend', 'migrations', '2026_add_capacitacion_gamificada.down.sql'), 'utf8');
    assert.match(migration, /BEGIN;[\s\S]*COMMIT;/);
    for (const table of ['capacitacion_ruta', 'capacitacion_actividad', 'capacitacion_actividad_intento', 'capacitacion_actividad_progreso']) {
        assert.match(migration, new RegExp(`CREATE TABLE IF NOT EXISTS SISTEMA_RIEGO\\.${table}`));
    }
    assert.match(migration, /REFERENCES SISTEMA_RIEGO\.usuario\(id_usuario\)/);
    assert.match(migration, /UNIQUE \(id_usuario, clave_idempotencia\)/);
    assert.match(migration, /FOR UPDATE/);
    assert.match(migration, /IF estado_ruta = 'publicada'/);
    assert.match(migration, /BEFORE UPDATE OR DELETE ON SISTEMA_RIEGO\.capacitacion_ruta/);
    assert.match(migration, /BEFORE INSERT OR UPDATE OR DELETE ON SISTEMA_RIEGO\.capacitacion_actividad/);
    assert.match(migration, /'borrador'/);
    assert.doesNotMatch(migration, /SET estado\s*=\s*'publicada'/i);
    assert.match(rollback, /capacitacion_actividad_progreso/);
    assert.match(rollback, /capacitacion_actividad_intento/);
    assert.match(rollback, /ADVERTENCIA:[\s\S]*elimina intentos, XP y progreso/);
});
