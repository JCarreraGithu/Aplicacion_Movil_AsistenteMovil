const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/database');
const sensorService = require('../src/services/sensor.service');

test('el listado de sensores filtra por propietario del sector', async (t) => {
    const originalQuery = pool.query;
    t.after(() => { pool.query = originalQuery; });
    let sql;
    let parametros;
    pool.query = async (query, values) => {
        sql = query;
        parametros = values;
        return { rows: [] };
    };

    const sensores = await sensorService.obtenerSensoresPorSector(14, 6);
    assert.deepEqual(sensores, []);
    assert.deepEqual(parametros, [14, 6]);
    assert.match(sql, /j\.id_usuario = \$2/);
    assert.match(sql, /s\.id_sector = \$1/);
});
