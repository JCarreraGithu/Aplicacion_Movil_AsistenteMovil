const crypto = require('crypto');

const hashApiKey = (apiKey) => crypto.createHash('sha256').update(String(apiKey), 'utf8').digest('hex');

const compareApiKey = (apiKey, expectedHash) => {
    if (typeof apiKey !== 'string' || typeof expectedHash !== 'string') return false;
    const normalizedHash = expectedHash.trim();
    if (!/^[a-f0-9]{64}$/i.test(normalizedHash)) return false;
    const candidate = Buffer.from(hashApiKey(apiKey), 'hex');
    const expected = Buffer.from(normalizedHash, 'hex');
    return candidate.length === expected.length && crypto.timingSafeEqual(candidate, expected);
};

const fechaDesdeHaceSegundos = (haceSegundos, ahora = new Date()) => {
    if (!Number.isInteger(haceSegundos) || haceSegundos < 0 || haceSegundos > 604800) return null;
    return new Date(ahora.getTime() - haceSegundos * 1000);
};

const validarLoteLecturas = (lecturas, actuadores = []) => {
    if (!Array.isArray(lecturas)) return { valido: false, mensaje: 'lecturas debe ser una lista' };
    if (lecturas.length > 100) return { valido: false, mensaje: 'Se permiten como máximo 100 lecturas por petición' };
    if (!Array.isArray(actuadores)) return { valido: false, mensaje: 'actuadores debe ser una lista' };

    for (const lectura of lecturas) {
        if (!lectura || typeof lectura !== 'object'
            || typeof lectura.uid !== 'string' || !lectura.uid.trim() || lectura.uid.length > 40
            || typeof lectura.codigo !== 'string' || !lectura.codigo.trim() || lectura.codigo.length > 50
            || typeof lectura.valor !== 'number' || !Number.isFinite(lectura.valor)
            || typeof lectura.unidad !== 'string' || !lectura.unidad.trim() || lectura.unidad.length > 20
            || !Number.isInteger(lectura.hace_segundos)
            || lectura.hace_segundos < 0 || lectura.hace_segundos > 604800) {
            return { valido: false, mensaje: 'Cada lectura requiere uid, codigo, valor finito, unidad y hace_segundos entre 0 y 604800' };
        }
    }
    for (const actuador of actuadores) {
        if (!actuador || typeof actuador.codigo !== 'string' || !actuador.codigo.trim() || actuador.codigo.length > 50
            || !['encendido', 'apagado'].includes(actuador.estado)) {
            return { valido: false, mensaje: 'Cada actuador requiere codigo y estado encendido o apagado' };
        }
    }
    return { valido: true };
};

const validarLote = validarLoteLecturas;

const transicionComandoValida = (actual, siguiente) =>
    ['PENDIENTE', 'ENVIADO'].includes(actual)
    && ['EJECUTADO', 'FALLIDO'].includes(siguiente);

const comandoVencido = (fechaExpira, ahora = new Date()) => {
    const fecha = new Date(fechaExpira);
    return Number.isNaN(fecha.getTime()) || fecha.getTime() <= ahora.getTime();
};

const puedeEncender = ({ estadoActuador, comandoVigente }) =>
    estadoActuador !== 'encendido' && comandoVigente !== true;

const estimarCantidadAgua = (duracionSegundos, caudalLpm = 1.0) => {
    if (!Number.isFinite(duracionSegundos) || duracionSegundos < 0
        || !Number.isFinite(caudalLpm) || caudalLpm < 0) return null;
    return (duracionSegundos / 60) * caudalLpm;
};

module.exports = {
    hashApiKey,
    compareApiKey,
    fechaDesdeHaceSegundos,
    validarLoteLecturas,
    validarLote,
    transicionComandoValida,
    comandoVencido,
    puedeEncender,
    estimarCantidadAgua
};
