const pool = require('../config/database');
const bcrypt = require('bcrypt');

const obtenerUsuarios = async () => {
    const result = await pool.query(`
        SELECT 
            id_usuario,
            nombre,
            apellido,
            correo,
            telefono,
            fecha_registro
        FROM SISTEMA_RIEGO.usuario
        ORDER BY id_usuario
    `);

    return result.rows;
};

const obtenerUsuarioPorId = async (id) => {
    const result = await pool.query(`
        SELECT 
            id_usuario,
            nombre,
            apellido,
            correo,
            telefono,
            fecha_registro
        FROM SISTEMA_RIEGO.usuario
        WHERE id_usuario = $1
    `, [id]);

    return result.rows[0];
};

const crearUsuario = async (usuario) => {
    const {
        nombre,
        apellido,
        correo,
        contrasena,
        telefono
    } = usuario;

    const contrasenaHash = await bcrypt.hash(contrasena, 10);

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.usuario
        (nombre, apellido, correo, contrasena, telefono)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING
            id_usuario,
            nombre,
            apellido,
            correo,
            telefono,
            fecha_registro
    `, [
        nombre,
        apellido,
        correo,
        contrasenaHash,
        telefono
    ]);

    return result.rows[0];
};

module.exports = {
    obtenerUsuarios,
    obtenerUsuarioPorId,
    crearUsuario
};