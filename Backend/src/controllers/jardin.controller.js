const jardinService = require('../services/jardin.service');

const crearJardin = async (req, res) => {
    try {

        const idUsuario = req.usuario.id_usuario;

        const jardin = await jardinService.crearJardin(
            idUsuario,
            req.body
        );

        res.status(201).json(jardin);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear el jardín'
        });
    }
};

const obtenerJardines = async (req, res) => {
    try {

        const idUsuario = req.usuario.id_usuario;

        const jardines = await jardinService.obtenerJardines(
            idUsuario
        );

        res.json(jardines);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los jardines'
        });
    }
};

const obtenerJardinPorId = async (req, res) => {
    try {

        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.id;

        const jardin = await jardinService.obtenerJardinPorId(
            idJardin,
            idUsuario
        );

        if (!jardin) {
            return res.status(404).json({
                mensaje: 'Jardín no encontrado'
            });
        }

        res.json(jardin);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener el jardín'
        });
    }
};

const actualizarJardin = async (req, res) => {
    try {

        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.id;

        const jardin = await jardinService.actualizarJardin(
            idJardin,
            idUsuario,
            req.body
        );

        if (!jardin) {
            return res.status(404).json({
                mensaje: 'Jardín no encontrado'
            });
        }

        res.json(jardin);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al actualizar el jardín'
        });
    }
};

const eliminarJardin = async (req, res) => {
    try {

        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.id;

        const jardin = await jardinService.eliminarJardin(
            idJardin,
            idUsuario
        );

        if (!jardin) {
            return res.status(404).json({
                mensaje: 'Jardín no encontrado'
            });
        }

        res.json({
            mensaje: 'Jardín eliminado correctamente'
        });

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al eliminar el jardín'
        });
    }
};

module.exports = {
    crearJardin,
    obtenerJardines,
    obtenerJardinPorId,
    actualizarJardin,
    eliminarJardin
};