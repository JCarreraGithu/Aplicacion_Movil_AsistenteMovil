const lecturaService = require('../services/lectura-sensor.service');

const crearLectura = async (req, res) => {
    try {

        const {
            id_sensor,
            valor,
            unidad,
            fecha_hora
        } = req.body;

        if (
            !id_sensor ||
            valor === undefined ||
            !unidad ||
            !fecha_hora
        ) {
            return res.status(400).json({
                mensaje: 'Todos los campos son obligatorios'
            });
        }

        const lectura = await lecturaService.crearLectura(
            id_sensor,
            valor,
            unidad,
            fecha_hora
        );

        res.status(201).json(lectura);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al registrar la lectura',
            error: error.message
        });
    }
};

const obtenerLecturasPorSensor = async (req, res) => {
    try {

        const { idSensor } = req.params;

        const lecturas =
            await lecturaService.obtenerLecturasPorSensor(idSensor);

        res.json(lecturas);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener las lecturas',
            error: error.message
        });
    }
};

module.exports = {
    crearLectura,
    obtenerLecturasPorSensor
};