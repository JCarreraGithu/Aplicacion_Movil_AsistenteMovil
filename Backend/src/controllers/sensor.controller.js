const sensorService = require('../services/sensor.service');

const crearSensor = async (req, res) => {
    try {

        const {
            id_sector,
            id_tipo_sensor,
            codigo,
            estado,
            fecha_instalacion
        } = req.body;

        if (
            !id_sector ||
            !id_tipo_sensor ||
            !codigo ||
            !estado ||
            !fecha_instalacion
        ) {
            return res.status(400).json({
                mensaje: 'Todos los campos son obligatorios'
            });
        }

        const sensor = await sensorService.crearSensor(
            id_sector,
            id_tipo_sensor,
            codigo,
            estado,
            fecha_instalacion
        );

        res.status(201).json(sensor);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear el sensor',
            error: error.message
        });
    }
};

const obtenerSensoresPorSector = async (req, res) => {
    try {

        const { idSector } = req.params;

        const sensores =
            await sensorService.obtenerSensoresPorSector(idSector);

        res.json(sensores);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los sensores',
            error: error.message
        });
    }
};

module.exports = {
    crearSensor,
    obtenerSensoresPorSector
};