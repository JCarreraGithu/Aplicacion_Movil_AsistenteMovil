const deviceService = require('../services/device.service');
const {
    validarLoteLecturas,
    fechaDesdeHaceSegundos,
    estimarCantidadAgua
} = require('../services/device-protocol');

const registrarLecturas = async (req, res, next) => {
    const { lecturas, actuadores = [] } = req.body || {};
    const validacion = validarLoteLecturas(lecturas, actuadores);
    if (!validacion.valido) return res.status(400).json({ mensaje: validacion.mensaje });
    try {
        return res.json(await deviceService.registrarLote(req.dispositivo, lecturas, actuadores));
    } catch (error) { return next(error); }
};

const registrarRiego = async (req, res, next) => {
    const { uid, hace_segundos, duracion_segundos, modo, cantidad_agua } = req.body || {};
    if (typeof uid !== 'string' || !uid.trim() || uid.length > 40) {
        return res.status(400).json({ mensaje: 'uid es obligatorio y debe tener hasta 40 caracteres' });
    }
    if (!Number.isInteger(hace_segundos) || !fechaDesdeHaceSegundos(hace_segundos)) {
        return res.status(400).json({ mensaje: 'hace_segundos debe ser un entero entre 0 y 604800' });
    }
    if (!Number.isInteger(duracion_segundos) || duracion_segundos < 0) {
        return res.status(400).json({ mensaje: 'duracion_segundos debe ser un entero mayor o igual a cero' });
    }
    if (!['AUTOMATICO', 'MANUAL'].includes(modo)) {
        return res.status(400).json({ mensaje: 'modo debe ser AUTOMATICO o MANUAL' });
    }
    if (cantidad_agua !== undefined && cantidad_agua !== null
        && (typeof cantidad_agua !== 'number' || !Number.isFinite(cantidad_agua) || cantidad_agua < 0)) {
        return res.status(400).json({ mensaje: 'cantidad_agua debe ser un número mayor o igual a cero' });
    }

    const configuredFlow = process.env.CAUDAL_BOMBA_LPM?.trim() === ''
        ? NaN : Number(process.env.CAUDAL_BOMBA_LPM);
    const flow = Number.isFinite(configuredFlow) && configuredFlow >= 0 ? configuredFlow : 1.0;
    const quantity = cantidad_agua === undefined || cantidad_agua === null
        ? estimarCantidadAgua(duracion_segundos, flow)
        : cantidad_agua;
    try {
        const result = await deviceService.registrarRiego(req.dispositivo, {
            uid, hace_segundos, duracion_segundos, modo, cantidad_agua: quantity
        });
        return res.status(result.duplicado ? 200 : 201).json(result);
    } catch (error) { return next(error); }
};

module.exports = { registrarLecturas, registrarRiego };
