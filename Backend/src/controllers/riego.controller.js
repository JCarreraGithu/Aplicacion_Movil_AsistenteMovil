const riegoService = require('../services/riego.service');

const crearRiego = async (req, res) => {
    try {

        const {
            id_sector,
            fecha_hora,
            duracion_segundos,
            cantidad_agua,
            modo
        } = req.body;

        if (
            !id_sector ||
            !fecha_hora ||
            duracion_segundos === undefined ||
            cantidad_agua === undefined ||
            !modo
        ) {
            return res.status(400).json({
                mensaje: 'Todos los campos son obligatorios'
            });
        }

        const riego = await riegoService.crearRiego(
            id_sector,
            fecha_hora,
            duracion_segundos,
            cantidad_agua,
            modo
        );

        res.status(201).json(riego);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al registrar el riego',
            error: error.message
        });
    }
};

const obtenerRiegosPorSector = async (req, res) => {
    try {

        const { idSector } = req.params;

        const riegos =
            await riegoService.obtenerRiegosPorSector(idSector);

        res.json(riegos);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los riegos',
            error: error.message
        });
    }
};

module.exports = {
    crearRiego,
    obtenerRiegosPorSector
};