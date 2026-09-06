const usuarioService = require('../services/usuario.service');

const obtenerUsuarios = async (req, res) => {
    try {
        const usuarios = await usuarioService.obtenerUsuarios();

        res.json(usuarios);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los usuarios'
        });
    }
};

const obtenerUsuarioPorId = async (req, res) => {
    try {
        const usuario = await usuarioService.obtenerUsuarioPorId(req.params.id);

        if (!usuario) {
            return res.status(404).json({
                mensaje: 'Usuario no encontrado'
            });
        }

        res.json(usuario);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener el usuario'
        });
    }
};


const crearUsuario = async (req, res) => {
    try {
        const usuario = await usuarioService.crearUsuario(req.body);

        res.status(201).json(usuario);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear el usuario'
        });
    }
};

module.exports = {
    obtenerUsuarios,
    obtenerUsuarioPorId,
    crearUsuario
};