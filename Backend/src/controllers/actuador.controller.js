const actuadorService = require('../services/actuador.service');

const crearActuador = async (req, res) => {
    try {

        const {
            id_sector,
            id_tipo_actuador,
            codigo,
            estado
        } = req.body;

        if (
            !id_sector ||
            !id_tipo_actuador ||
            !codigo ||
            !estado
        ) {
            return res.status(400).json({
                mensaje: 'Todos los campos son obligatorios'
            });
        }

        const actuador = await actuadorService.crearActuador(
            id_sector,
            id_tipo_actuador,
            codigo,
            estado
        );

        res.status(201).json(actuador);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear el actuador',
            error: error.message
        });
    }
};

const obtenerActuadoresPorSector = async (req, res) => {
    try {

        const { idSector } = req.params;

        const actuadores =
            await actuadorService.obtenerActuadoresPorSector(idSector);

        res.json(actuadores);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los actuadores',
            error: error.message
        });
    }
};

module.exports = {
    crearActuador,
    obtenerActuadoresPorSector
};