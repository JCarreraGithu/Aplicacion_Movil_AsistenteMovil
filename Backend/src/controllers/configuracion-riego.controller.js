const configuracionService = require('../services/configuracion-riego.service');

const crearConfiguracion = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idSector = req.params.idSector;

        const configuracion =
            await configuracionService.crearConfiguracion(
                idUsuario,
                idSector,
                req.body
            );

        if (!configuracion) {
            return res.status(404).json({
                mensaje: 'Sector no encontrado'
            });
        }

        res.status(201).json(configuracion);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear la configuración de riego'
        });
    }
};

const obtenerConfiguracion = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idSector = req.params.idSector;

        const configuracion =
            await configuracionService.obtenerConfiguracion(
                idUsuario,
                idSector
            );

        if (!configuracion) {
            return res.status(404).json({
                mensaje: 'Configuración no encontrada'
            });
        }

        res.json(configuracion);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener la configuración de riego'
        });
    }
};

module.exports = {
    crearConfiguracion,
    obtenerConfiguracion
};