const lecturaService = require('../services/lectura-sensor.service');

const esIdPositivo = (value) => Number.isInteger(Number(value)) && Number(value) > 0;
const esFechaIsoValida = (value) => {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)?$/.test(value)) {
        return false;
    }
    return Number.isFinite(Date.parse(value));
};

const crearLectura = async (req, res, next) => {
    const { id_sensor, valor, unidad, fecha_hora } = req.body;
    if (!esIdPositivo(id_sensor)) {
        return res.status(400).json({ mensaje: 'id_sensor debe ser un entero positivo' });
    }
    if (valor === null || valor === undefined || (typeof valor === 'string' && valor.trim() === '') || !['number', 'string'].includes(typeof valor) || !Number.isFinite(Number(valor))) {
        return res.status(400).json({ mensaje: 'valor debe ser un número finito' });
    }
    if (typeof unidad !== 'string' || unidad.trim().length === 0) {
        return res.status(400).json({ mensaje: 'unidad debe ser un texto no vacío' });
    }
    if (fecha_hora !== undefined && fecha_hora !== null && !esFechaIsoValida(fecha_hora)) {
        return res.status(400).json({ mensaje: 'fecha_hora debe ser una fecha ISO válida' });
    }

    try {
        const resultado = await lecturaService.crearLectura(
            req.usuario.id_usuario,
            Number(id_sensor),
            Number(valor),
            unidad.trim(),
            fecha_hora || null
        );
        if (!resultado) return res.status(404).json({ mensaje: 'Sensor no encontrado' });
        return res.status(201).json(resultado);
    } catch (error) {
        return next(error);
    }
};

const obtenerLecturasPorSensor = async (req, res, next) => {
    const { idSensor } = req.params;
    if (!esIdPositivo(idSensor)) return res.status(400).json({ mensaje: 'idSensor debe ser un entero positivo' });
    try {
        const lecturas = await lecturaService.obtenerLecturasPorSensor(req.usuario.id_usuario, Number(idSensor));
        if (lecturas === null) return res.status(404).json({ mensaje: 'Sensor no encontrado' });
        return res.json(lecturas);
    } catch (error) {
        return next(error);
    }
};

const obtenerUltimasLecturasPorSector = async (req, res, next) => {
    const { idSector } = req.params;
    if (!esIdPositivo(idSector)) return res.status(400).json({ mensaje: 'idSector debe ser un entero positivo' });
    try {
        const lecturas = await lecturaService.obtenerUltimasLecturasPorSector(req.usuario.id_usuario, Number(idSector));
        if (lecturas === null) return res.status(404).json({ mensaje: 'Sector no encontrado' });
        return res.json(lecturas);
    } catch (error) {
        return next(error);
    }
};

module.exports = {
    crearLectura,
    obtenerLecturasPorSensor,
    obtenerUltimasLecturasPorSector
};
