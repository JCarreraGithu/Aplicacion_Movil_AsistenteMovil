const pool = require('../config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const login = async (correo, contrasena) => {

    const result = await pool.query(`
        SELECT
            id_usuario,
            nombre,
            apellido,
            correo,
            contrasena
        FROM SISTEMA_RIEGO.usuario
        WHERE correo = $1
    `, [correo]);

    const usuario = result.rows[0];

    if (!usuario) {
        return null;
    }

    const contrasenaValida = await bcrypt.compare(
        contrasena,
        usuario.contrasena
    );

    if (!contrasenaValida) {
        return null;
    }

    const token = jwt.sign(
        {
            id_usuario: usuario.id_usuario,
            correo: usuario.correo
        },
        process.env.JWT_SECRET,
        {
            expiresIn: '2h'
        }
    );

    return {
        usuario: {
            id_usuario: usuario.id_usuario,
            nombre: usuario.nombre,
            apellido: usuario.apellido,
            correo: usuario.correo
        },
        token
    };
};

module.exports = {
    login
};