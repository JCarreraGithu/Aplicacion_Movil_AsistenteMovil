const test = require('node:test');
const assert = require('node:assert/strict');
const { calificarActividad, normalizarRespuestaActividad } = require('../src/services/capacitacion/actividad-calificadores');

const config = { version: 1, humedad_inicial: 20, objetivo_min: 45, objetivo_max: 65,
    incremento_por_unidad: 2, agua_max_por_accion: 15, agua_max_total: 40, max_acciones: 8 };
const respuesta = (...dosis) => ({ version: 1, acciones: dosis.map((agua) => ({ tipo: 'regar', agua })) });
const calificar = (value, opciones = config) => calificarActividad('simulacion_riego', value, { correcta: true }, opciones);

test('reproduce humedad insuficiente, adecuada y excesiva desde el historial de acciones', () => {
    for (const [dosis, humedad, estado, correcta] of [
        [[], 20, 'insuficiente', false], [[5], 30, 'insuficiente', false],
        [[5, 10], 50, 'adecuada', true], [[15, 15], 80, 'excesiva', false],
        [[15, 15, 10], 100, 'excesiva', false]
    ]) {
        const result = calificar(respuesta(...dosis));
        assert.equal(result.correcta, correcta);
        assert.deepEqual(result.resultado_simulacion, { version: 1, humedad_final: humedad,
            agua_total: dosis.reduce((sum, agua) => sum + agua, 0), estado });
    }
});

test('incluye ambos límites del objetivo y distingue una unidad fuera de ellos', () => {
    const limites = { ...config, objetivo_min: 40, objetivo_max: 60 };
    assert.equal(calificar(respuesta(10), limites).correcta, true);
    assert.equal(calificar(respuesta(10, 10), limites).correcta, true);
    assert.equal(calificar(respuesta(9), limites).correcta, false);
    assert.equal(calificar(respuesta(10, 11), limites).correcta, false);
});

test('rechaza agua, acciones y campos manipulados; no acepta el resultado calculado en Flutter', () => {
    for (const value of [null, true, 'correcto', { ...respuesta(15), correcto: true },
        { ...respuesta(15), humedad_final: 50 }, { ...respuesta(15), configuracion: config },
        { version: 2, acciones: [] }, { version: 1, acciones: [{ tipo: 'secar', agua: 5 }] },
        respuesta(-1), respuesta(0), respuesta(1.5), respuesta('15'), respuesta(NaN),
        respuesta(Infinity), respuesta(16), respuesta(15, 15, 11), respuesta(...Array(9).fill(1))]) {
        assert.throws(() => calificar(value), (error) => error.status === 400, JSON.stringify(value));
    }
    assert.throws(() => normalizarRespuestaActividad('simulacion_riego', respuesta(...Array(21).fill(1))),
        (error) => error.status === 400);
});

test('configuración y versión provienen del servidor y deben tener un objetivo alcanzable', () => {
    for (const value of [null, {}, { ...config, version: 2 }, { ...config, humedad_inicial: 99 },
        { ...config, objetivo_min: 45, objetivo_max: 45 }]) {
        assert.throws(() => calificar(respuesta(15), value), (error) => error.status === 500);
    }
});
