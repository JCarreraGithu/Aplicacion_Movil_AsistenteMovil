const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/database');
const service = require('../src/services/planta.service');
test('un caso cerrado no se reabre por el endpoint genérico de estado', async () => {
  const original = pool.query;
  try {
    pool.query = async (sql,p) => {
      assert.match(sql, /AND estado NOT IN \('resuelto', 'abandonado'\)[\s\S]*RETURNING/);
      assert.equal(p[0], 'en_progreso');
      return {rows:[]};
    };
    const casos = require('../src/services/caso.service');
    assert.equal(await casos.cambiarEstadoCaso(3,7,'en_progreso'),null);
  } finally { pool.query = original; }
});
test('archivar conserva relaciones y filtra por propietario, sector y planta', async () => {
  const original = pool.query;
  try {
    pool.query = async (sql, params) => {
      assert.match(sql, /UPDATE SISTEMA_RIEGO.planta/);
      assert.match(sql, /j.id_usuario = \$3/);
      assert.doesNotMatch(sql, /DELETE|CASCADE/);
      assert.deepEqual(params, [2, 7, 3]);
      return {rows: []};
    };
    assert.equal(await service.archivarPlanta(3, 2, 7), null);
  } finally { pool.query = original; }
});
