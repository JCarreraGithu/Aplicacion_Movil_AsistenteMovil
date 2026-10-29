const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/database');
const casoService = require('../src/services/caso.service');

const usarPoolSimulado = (t, { query, connect }) => {
    const originalQuery = pool.query;
    const originalConnect = pool.connect;
    if (query) pool.query = query;
    if (connect) pool.connect = connect;
    t.after(() => {
        pool.query = originalQuery;
        pool.connect = originalConnect;
    });
};

test('crearCaso persiste pasos confirmados y deduplica recordatorios propuestos', async (t) => {
    const consultas = [];
    let idTarea = 100;
    const client = {
        query: async (sql, params = []) => {
            consultas.push({ sql, params });
            if (sql.includes('INSERT INTO SISTEMA_RIEGO.caso_planta')) {
                return { rows: [{ id_caso: 8, plan_trabajo: params[6] }] };
            }
            if (sql.includes('INSERT INTO SISTEMA_RIEGO.caso_tarea')) {
                return { rows: [{ id_tarea: ++idTarea }] };
            }
            return { rows: [] };
        },
        release: () => {}
    };
    usarPoolSimulado(t, { connect: async () => client });

    await casoService.crearCaso(12, {
        titulo: 'Recuperación de planta',
        diagnostico: 'Diagnóstico conservado',
        plan_trabajo: 'Revisar el drenaje.\nRevisar la humedad.',
        pasos: [
            { descripcion: 'Revisar el drenaje', fecha_limite: '2026-11-20T12:00:00Z', recordatorio_mensaje: 'Revisar avances', recordatorio_fecha: '2026-11-20T12:00:00Z' },
            { descripcion: 'Revisar la humedad', fecha_limite: '2026-11-20T12:00:00Z', recordatorio_mensaje: 'Revisar avances', recordatorio_fecha: '2026-11-20T12:00:00Z' }
        ]
    });

    assert.equal(consultas.filter(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.caso_tarea')).length, 2);
    assert.equal(consultas.filter(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.recordatorio_caso')).length, 1);
    assert.equal(consultas.at(-1).sql, 'COMMIT');
});

test('agregarSeguimiento conserva texto y foto, enlaza recordatorio y rechaza casos ajenos', async (t) => {
    const consultas = [];
    let permitirCaso = true;
    let permitirRecordatorio = true;
    const client = {
        query: async (sql, params = []) => {
            consultas.push({ sql, params });
            if (sql.includes('SELECT id_caso')) return { rows: permitirCaso ? [{ id_caso: 8 }] : [] };
            if (sql.includes('SELECT id_recordatorio')) return { rows: permitirRecordatorio ? [{ id_recordatorio: params[0] }] : [] };
            if (sql.includes('INSERT INTO SISTEMA_RIEGO.seguimiento_caso')) {
                return { rows: [{ id_seguimiento: 5, nota: params[1], imagen_url: params[2], id_recordatorio: params[3] }] };
            }
            return { rows: [] };
        },
        release: () => {}
    };
    usarPoolSimulado(t, { connect: async () => client });

    const guardado = await casoService.agregarSeguimiento(
        12, 8, 'Observación original', '/uploads/casos/avance.jpg', 3
    );
    assert.equal(guardado.nota, 'Observación original');
    assert.equal(guardado.imagen_url, '/uploads/casos/avance.jpg');
    assert.equal(guardado.id_recordatorio, 3);
    assert.ok(consultas.some(({ sql, params }) =>
        sql.includes('UPDATE SISTEMA_RIEGO.recordatorio_caso') && params[0] === 3
    ));
    assert.equal(consultas.at(-1).sql, 'COMMIT');

    consultas.length = 0;
    permitirCaso = false;
    const noAutorizado = await casoService.agregarSeguimiento(
        99, 8, 'No autorizado', null, 3
    );
    assert.equal(noAutorizado, null);
    assert.equal(consultas.some(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.seguimiento_caso')), false);
    assert.equal(consultas.at(-1).sql, 'ROLLBACK');

    consultas.length = 0;
    permitirCaso = true;
    permitirRecordatorio = false;
    assert.equal(
        await casoService.agregarSeguimiento(12, 8, 'Recordatorio ajeno', null, 44),
        'recordatorio_no_encontrado'
    );
    assert.equal(consultas.some(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.seguimiento_caso')), false);
    assert.equal(consultas.at(-1).sql, 'ROLLBACK');
});

test('obtenerCasoPorId conserva la bitácora existente en orden cronológico', async (t) => {
    const notas = [
        { id_seguimiento: 1, fecha: '2026-10-01T10:00:00Z', nota: 'Nota antigua', imagen_url: null },
        { id_seguimiento: 2, fecha: '2026-10-03T10:00:00Z', nota: 'Nota reciente', imagen_url: '/uploads/casos/foto.jpg' }
    ];
    usarPoolSimulado(t, {
        query: async (sql) => {
            if (sql.includes('SELECT\n            c.*')) return { rows: [{ id_caso: 8, id_usuario: 12 }] };
            if (sql.includes('FROM SISTEMA_RIEGO.seguimiento_caso')) return { rows: notas };
            if (sql.includes('SELECT id_caso FROM SISTEMA_RIEGO.caso_planta')) return { rows: [{ id_caso: 8 }] };
            if (sql.includes('FROM SISTEMA_RIEGO.caso_tarea')) return { rows: [] };
            if (sql.includes('FROM SISTEMA_RIEGO.recordatorio_caso')) return { rows: [] };
            return { rows: [] };
        }
    });

    const caso = await casoService.obtenerCasoPorId(12, 8);
    assert.deepEqual(caso.seguimientos, notas);
    assert.equal(caso.seguimientos[0].nota, 'Nota antigua');
    assert.equal(caso.seguimientos[1].imagen_url, '/uploads/casos/foto.jpg');
});

test('crearRecordatorio devuelve el existente y evita insertar el duplicado', async (t) => {
    const consultas = [];
    const client = {
        query: async (sql, params = []) => {
            consultas.push({ sql, params });
            if (sql.includes('SELECT id_caso')) return { rows: [{ id_caso: 8 }] };
            if (sql.includes('SELECT * FROM SISTEMA_RIEGO.recordatorio_caso')) {
                return { rows: [{ id_recordatorio: 3, mensaje: 'Revisar', fecha_recordatorio: params[3] }] };
            }
            return { rows: [] };
        },
        release: () => {}
    };
    usarPoolSimulado(t, { connect: async () => client });

    const recordatorio = await casoService.crearRecordatorio(
        12, 8, 'Revisar', '2026-11-20T12:00:00Z', null
    );
    assert.equal(recordatorio.id_recordatorio, 3);
    assert.equal(consultas.some(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.recordatorio_caso')), false);
    assert.equal(consultas.at(-1).sql, 'COMMIT');
});

test('crearRecordatorio rechaza un caso que pertenece a otro usuario', async (t) => {
    const consultas = [];
    const client = {
        query: async (sql, params = []) => {
            consultas.push({ sql, params });
            return { rows: [] };
        },
        release: () => {}
    };
    usarPoolSimulado(t, { connect: async () => client });

    assert.equal(await casoService.crearRecordatorio(99, 8, 'Revisar', '2026-11-20T12:00:00Z', null), null);
    assert.deepEqual(consultas[1].params, [8, 99]);
    assert.equal(consultas.some(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.recordatorio_caso')), false);
    assert.equal(consultas.at(-1).sql, 'ROLLBACK');
});

test('actualizarRecordatorio modifica mensaje y fecha sin salir del caso propietario', async (t) => {
    const consultas = [];
    const client = {
        query: async (sql, params = []) => {
            consultas.push({ sql, params });
            if (sql.includes('SELECT id_caso')) return { rows: [{ id_caso: 8 }] };
            if (sql.includes('SELECT id_recordatorio FROM SISTEMA_RIEGO.recordatorio_caso') && sql.includes('<>')) return { rows: [] };
            if (sql.includes('SELECT id_recordatorio FROM SISTEMA_RIEGO.recordatorio_caso')) return { rows: [{ id_recordatorio: 3 }] };
            if (sql.includes('UPDATE SISTEMA_RIEGO.recordatorio_caso')) return { rows: [{ id_recordatorio: 3, mensaje: params[0], fecha_recordatorio: params[1] }] };
            return { rows: [] };
        },
        release: () => {}
    };
    usarPoolSimulado(t, { connect: async () => client });

    const actualizado = await casoService.actualizarRecordatorio(
        12, 8, 3, 'Revisar cambios', '2026-11-20T12:00:00Z'
    );
    assert.equal(actualizado.mensaje, 'Revisar cambios');
    assert.equal(actualizado.fecha_recordatorio, '2026-11-20T12:00:00Z');
    assert.equal(consultas.some(({ sql }) => sql.includes('UPDATE SISTEMA_RIEGO.recordatorio_caso')), true);
    assert.equal(consultas.at(-1).sql, 'COMMIT');
});
