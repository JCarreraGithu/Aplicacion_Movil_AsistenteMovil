const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/database');
const casoService = require('../src/services/caso.service');

const conClienteSimulado = async (t, queryCliente) => {
    const consultas = [];
    const client = {
        query: async (sql, params = []) => {
            consultas.push({ sql, params });
            return queryCliente(sql, params);
        },
        release: () => {}
    };
    const originalConnect = pool.connect;
    pool.connect = async () => client;
    t.after(() => { pool.connect = originalConnect; });
    return consultas;
};

test('no cierra ni escribe bitácora si el caso no pertenece al usuario', async (t) => {
    const consultas = await conClienteSimulado(t, async (sql) => {
        if (sql.includes('SELECT id_caso, estado')) return { rows: [] };
        return { rows: [] };
    });

    const resultado = await casoService.cerrarCasoConResultado(20, 8, 'Recuperada');

    assert.equal(resultado, null);
    assert.match(consultas[1].sql, /id_caso = \$1 AND id_usuario = \$2 FOR UPDATE/);
    assert.deepEqual(consultas[1].params, [8, 20]);
    assert.equal(consultas.some(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.seguimiento_caso')), false);
    assert.equal(consultas.at(-1).sql, 'ROLLBACK');
});

test('registra resultado en la bitácora y cierra el caso en la misma transacción', async (t) => {
    const consultas = await conClienteSimulado(t, async (sql, params) => {
        if (sql.includes('SELECT id_caso, estado')) return { rows: [{ id_caso: 8, estado: 'en_progreso' }] };
        if (sql.includes('INSERT INTO SISTEMA_RIEGO.seguimiento_caso')) {
            return { rows: [{ id_seguimiento: 55, id_caso: params[0], nota: params[1] }] };
        }
        if (sql.includes('UPDATE SISTEMA_RIEGO.caso_planta')) {
            return { rows: [{ id_caso: params[0], estado: 'resuelto' }] };
        }
        return { rows: [] };
    });

    const resultado = await casoService.cerrarCasoConResultado(20, 8, 'Hojas nuevas sanas');

    assert.equal(resultado.estado, 'resuelto');
    assert.equal(resultado.resultado_final.nota, 'Resultado final: Hojas nuevas sanas');
    assert.equal(consultas[0].sql, 'BEGIN');
    assert.equal(consultas.at(-1).sql, 'COMMIT');
    assert.equal(consultas.filter(({ sql }) => sql.includes('INSERT INTO SISTEMA_RIEGO.seguimiento_caso')).length, 1);
    assert.equal(consultas.filter(({ sql }) => sql.includes('UPDATE SISTEMA_RIEGO.caso_planta')).length, 1);
});
