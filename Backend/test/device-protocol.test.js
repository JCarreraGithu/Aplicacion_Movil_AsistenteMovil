const test = require('node:test');
const assert = require('node:assert/strict');
const {
    hashApiKey,
    compareApiKey,
    fechaDesdeHaceSegundos,
    validarLoteLecturas,
    transicionComandoValida,
    comandoVencido,
    puedeEncender,
    estimarCantidadAgua
} = require('../src/services/device-protocol');

const lectura = (overrides = {}) => ({
    uid: 'sensor-uid-1', codigo: 'HUM-001', valor: 43.5,
    unidad: '%', hace_segundos: 40, ...overrides
});

test('SHA-256 genera hash hexadecimal y compara clave correcta', () => {
    const hash = hashApiKey('clave-secreta');
    assert.match(hash, /^[a-f0-9]{64}$/);
    assert.equal(compareApiKey('clave-secreta', hash), true);
    assert.equal(compareApiKey('clave-secreta', `${hash}  `), true);
});

test('la comparación de clave rechaza clave equivocada y hash malformado', () => {
    assert.equal(compareApiKey('otra', hashApiKey('clave-secreta')), false);
    assert.equal(compareApiKey('clave-secreta', 'no-es-un-hash'), false);
    assert.equal(compareApiKey(null, hashApiKey('clave-secreta')), false);
});

test('hace_segundos calcula la fecha hacia atrás', () => {
    const now = new Date('2026-10-11T12:00:00.000Z');
    assert.equal(fechaDesdeHaceSegundos(40, now).toISOString(), '2026-10-11T11:59:20.000Z');
});

test('hace_segundos acepta los límites cero y siete días', () => {
    const now = new Date('2026-10-11T12:00:00Z');
    assert.equal(fechaDesdeHaceSegundos(0, now).getTime(), now.getTime());
    assert.equal(fechaDesdeHaceSegundos(604800, now).getTime(), now.getTime() - 604800000);
});

test('hace_segundos fuera de rango o fraccionario se rechaza', () => {
    for (const value of [-1, 604801, 2.5, NaN]) assert.equal(fechaDesdeHaceSegundos(value), null);
});

test('lote válido de lecturas se acepta', () => {
    assert.deepEqual(validarLoteLecturas([lectura()], []), { valido: true });
});

test('lote con 101 lecturas se rechaza', () => {
    assert.equal(validarLoteLecturas(Array.from({ length: 101 }, () => lectura())).valido, false);
});

test('lote rechaza lectura incompleta, no finita o con hace_segundos inválido', () => {
    for (const item of [lectura({ uid: '' }), lectura({ valor: Infinity }), lectura({ unidad: '' }), lectura({ hace_segundos: 604801 })]) {
        assert.equal(validarLoteLecturas([item]).valido, false);
    }
});

test('valida actuadores reportados y estado requerido', () => {
    assert.equal(validarLoteLecturas([], [{ codigo: 'BOMBA-001', estado: 'encendido' }]).valido, true);
    assert.equal(validarLoteLecturas([], [{ codigo: 'BOMBA-001', estado: 'ACTIVO' }]).valido, false);
});

test('las transiciones de comando solo permiten PENDIENTE/ENVIADO a ACK terminal', () => {
    assert.equal(transicionComandoValida('PENDIENTE', 'EJECUTADO'), true);
    assert.equal(transicionComandoValida('ENVIADO', 'FALLIDO'), true);
    assert.equal(transicionComandoValida('EJECUTADO', 'FALLIDO'), false);
    assert.equal(transicionComandoValida('EXPIRADO', 'EJECUTADO'), false);
});

test('un comando vencido nunca es vigente', () => {
    const now = new Date('2026-10-11T12:00:00Z');
    assert.equal(comandoVencido('2026-10-11T11:59:59Z', now), true);
    assert.equal(comandoVencido('2026-10-11T12:00:01Z', now), false);
});

test('rechaza doble ENCENDER si el actuador ya está encendido o tiene comando vigente', () => {
    assert.equal(puedeEncender({ estadoActuador: 'encendido', comandoVigente: false }), false);
    assert.equal(puedeEncender({ estadoActuador: 'apagado', comandoVigente: true }), false);
    assert.equal(puedeEncender({ estadoActuador: 'apagado', comandoVigente: false }), true);
});

test('estima litros según duración y caudal, rechazando entradas negativas', () => {
    assert.equal(estimarCantidadAgua(90, 2), 3);
    assert.equal(estimarCantidadAgua(60), 1);
    assert.equal(estimarCantidadAgua(-1, 1), null);
});
