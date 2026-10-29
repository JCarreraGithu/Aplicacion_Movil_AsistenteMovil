const riegoService = require('../services/riego.service');

const esEnteroPositivo = (value) => Number.isInteger(Number(value)) && Number(value) > 0;
const esFechaIsoValida = (value) => typeof value === 'string'
    && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$/.test(value)
    && Number.isFinite(Date.parse(value));

// Registra un riego que el dispositivo ya ejecutó; el servidor no lo inicia ni lo calcula.
const crearRiego = async (req, res, next) => {
    const { id_sector, fecha_hora, duracion_segundos, modo, cantidad_agua } = req.body || {};

    if (!esEnteroPositivo(id_sector)) {
        return res.status(400).json({ mensaje: 'id_sector debe ser un entero positivo' });
    }
    if (!esFechaIsoValida(fecha_hora)) {
        return res.status(400).json({ mensaje: 'fecha_hora debe ser una fecha ISO válida' });
    }
    if (duracion_segundos === null || duracion_segundos === undefined
        || (typeof duracion_segundos === 'string' && duracion_segundos.trim() === '')
        || !Number.isInteger(Number(duracion_segundos)) || Number(duracion_segundos) < 0) {
        return res.status(400).json({ mensaje: 'duracion_segundos debe ser un entero mayor o igual a cero' });
    }
    if (!['AUTOMATICO', 'MANUAL'].includes(modo)) {
        return res.status(400).json({ mensaje: 'modo debe ser AUTOMATICO o MANUAL' });
    }
    if (cantidad_agua !== undefined && cantidad_agua !== null
        && ((typeof cantidad_agua === 'string' && cantidad_agua.trim() === '')
            || !Number.isFinite(Number(cantidad_agua)) || Number(cantidad_agua) < 0)) {
        return res.status(400).json({ mensaje: 'cantidad_agua debe ser un número mayor o igual a cero' });
    }

    try {
        const riego = await riegoService.crearRiego(
            req.usuario.id_usuario,
            Number(id_sector),
            fecha_hora,
            Number(duracion_segundos),
            cantidad_agua === undefined || cantidad_agua === null ? null : Number(cantidad_agua),
            modo
        );
        if (!riego) return res.status(404).json({ mensaje: 'Sector no encontrado' });
        return res.status(201).json(riego);
    } catch (error) {
        return next(error);
    }
};

const obtenerRiegosPorSector = async (req, res, next) => {
    try {
        const { idSector } = req.params;
        const dias = Number(req.query.dias || 15);
        const periodo = req.query.periodo || 'actual';

        if (!esEnteroPositivo(idSector)) {
            return res.status(400).json({ mensaje: 'idSector debe ser un entero positivo' });
        }
        if (![7, 15, 30].includes(dias)) {
            return res.status(400).json({ mensaje: 'dias debe ser 7, 15 o 30' });
        }
        if (!['actual', 'anterior'].includes(periodo)) {
            return res.status(400).json({ mensaje: 'periodo debe ser actual o anterior' });
        }

        const riegos = await riegoService.obtenerRiegosPorSector(
            Number(idSector),
            req.usuario.id_usuario,
            dias,
            periodo
        );
        if (riegos === null) return res.status(404).json({ mensaje: 'Sector no encontrado' });
        return res.json(riegos);
    } catch (error) {
        return next(error);
    }
};

const obtenerResumenPorSector = async (req, res, next) => {
    try {
        const { idSector } = req.params;
        if (!esEnteroPositivo(idSector)) {
            return res.status(400).json({ mensaje: 'idSector debe ser un entero positivo' });
        }

        const resumen = await riegoService.obtenerResumenPorSector(
            Number(idSector),
            req.usuario.id_usuario
        );
        if (!resumen) return res.status(404).json({ mensaje: 'Sector no encontrado' });
        return res.json(resumen);
    } catch (error) {
        return next(error);
    }
};

module.exports = {
    crearRiego,
    obtenerRiegosPorSector,
    obtenerResumenPorSector
};
