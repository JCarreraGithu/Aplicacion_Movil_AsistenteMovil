const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/database');
const riegoService = require('../src/services/riego.service');

test('el resumen limita la consulta al sector del usuario y distingue no autorizado', async (t) => {
    const originalQuery = pool.query;
    t.after(() => { pool.query = originalQuery; });
    let sqlEjecutado;
    let parametros;
    pool.query = async (sql, values) => {
        sqlEjecutado = sql;
        parametros = values;
        return { rows: [] };
    };

    const noEncontrado = await riegoService.obtenerResumenPorSector(12, 7);
    assert.equal(noEncontrado, null);
    assert.deepEqual(parametros, [12, 7]);
    assert.match(sqlEjecutado, /j\.id_usuario = \$2/);
    assert.match(sqlEjecutado, /s\.id_sector = \$1/);
    assert.match(sqlEjecutado, /cantidad_agua IS NULL/);
    assert.match(sqlEjecutado, /INTERVAL '7 days'/);
});

test('el resumen devuelve los valores agregados de PostgreSQL sin transformarlos', async (t) => {
    const originalQuery = pool.query;
    t.after(() => { pool.query = originalQuery; });
    const fila = {
        id_sector: 3,
        cantidad_riegos: 4,
        consumo_total: '19.50',
        cantidades_desconocidas: 1,
        fecha_ultimo_riego: '2026-10-12T10:00:00.000Z',
        consumo_ultimos_7_dias: '8.25',
        riegos_ultimos_7_dias: 2,
        cantidades_desconocidas_ultimos_7_dias: 1
    };
    pool.query = async () => ({ rows: [fila] });

    assert.equal(await riegoService.obtenerResumenPorSector(3, 9), fila);
});
