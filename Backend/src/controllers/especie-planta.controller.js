const especieService = require('../services/especie-planta.service');

const crearEspecie = async (req, res) => {
    try {
        const especie = await especieService.crearEspecie(req.body);

        res.status(201).json(especie);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear la especie'
        });
    }
};

const obtenerEspecies = async (req, res) => {
    try {
        const especies = await especieService.obtenerEspecies();

        res.json(especies);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener las especies'
        });
    }
};

const obtenerEspeciePorId = async (req, res) => {
    try {
        const especie = await especieService.obtenerEspeciePorId(
            req.params.id
        );

        if (!especie) {
            return res.status(404).json({
                mensaje: 'Especie no encontrada'
            });
        }

        res.json(especie);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener la especie'
        });
    }
};

module.exports = {
    crearEspecie,
    obtenerEspecies,
    obtenerEspeciePorId
};