const authService = require('../services/auth.service');

const login = async (req, res) => {
    try {

        const { correo, contrasena } = req.body;

        if (!correo || !contrasena) {
            return res.status(400).json({
                mensaje: 'Correo y contraseña son obligatorios'
            });
        }

        const resultado = await authService.login(
            correo,
            contrasena
        );

        if (!resultado) {
            return res.status(401).json({
                mensaje: 'Credenciales incorrectas'
            });
        }

        res.json(resultado);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al iniciar sesión'
        });
    }
};

module.exports = {
    login
};