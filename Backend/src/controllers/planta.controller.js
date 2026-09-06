const plantaService = require('../services/planta.service');

const crearPlanta = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idSector = req.params.idSector;

        const planta = await plantaService.crearPlanta(
            idUsuario,
            idSector,
            req.body
        );

        if (!planta) {
            return res.status(404).json({
                mensaje: 'Sector no encontrado'
            });
        }

        res.status(201).json(planta);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear la planta'
        });
    }
};

const obtenerPlantas = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idSector = req.params.idSector;

        const plantas = await plantaService.obtenerPlantas(
            idUsuario,
            idSector
        );

        if (plantas === null) {
            return res.status(404).json({
                mensaje: 'Sector no encontrado'
            });
        }

        res.json(plantas);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener las plantas'
        });
    }
};

const obtenerPlantaPorId = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idSector = req.params.idSector;
        const idPlanta = req.params.idPlanta;

        const planta = await plantaService.obtenerPlantaPorId(
            idUsuario,
            idSector,
            idPlanta
        );

        if (!planta) {
            return res.status(404).json({
                mensaje: 'Planta no encontrada'
            });
        }

        res.json(planta);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener la planta'
        });
    }
};

module.exports = {
    crearPlanta,
    obtenerPlantas,
    obtenerPlantaPorId
};