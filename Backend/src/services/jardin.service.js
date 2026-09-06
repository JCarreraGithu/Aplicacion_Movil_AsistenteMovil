const pool = require('../config/database');

const crearJardin = async (idUsuario, jardin) => {
    const {
        nombre,
        ubicacion,
        descripcion
    } = jardin;

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.jardin
        (id_usuario, nombre, ubicacion, descripcion)
        VALUES ($1, $2, $3, $4)
        RETURNING
            id_jardin,
            id_usuario,
            nombre,
            ubicacion,
            descripcion
    `, [
        idUsuario,
        nombre,
        ubicacion,
        descripcion
    ]);

    return result.rows[0];
};

const obtenerJardines = async (idUsuario) => {
    const result = await pool.query(`
        SELECT
            id_jardin,
            nombre,
            ubicacion,
            descripcion
        FROM SISTEMA_RIEGO.jardin
        WHERE id_usuario = $1
        ORDER BY id_jardin
    `, [idUsuario]);

    return result.rows;
};

const obtenerJardinPorId = async (idJardin, idUsuario) => {
    const result = await pool.query(`
        SELECT
            id_jardin,
            nombre,
            ubicacion,
            descripcion
        FROM SISTEMA_RIEGO.jardin
        WHERE id_jardin = $1
        AND id_usuario = $2
    `, [idJardin, idUsuario]);

    return result.rows[0];
};

const actualizarJardin = async (idJardin, idUsuario, jardin) => {
    const {
        nombre,
        ubicacion,
        descripcion
    } = jardin;

    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.jardin
        SET
            nombre = $1,
            ubicacion = $2,
            descripcion = $3
        WHERE id_jardin = $4
        AND id_usuario = $5
        RETURNING
            id_jardin,
            nombre,
            ubicacion,
            descripcion
    `, [
        nombre,
        ubicacion,
        descripcion,
        idJardin,
        idUsuario
    ]);

    return result.rows[0];
};

const eliminarJardin = async (idJardin, idUsuario) => {
    const result = await pool.query(`
        DELETE FROM SISTEMA_RIEGO.jardin
        WHERE id_jardin = $1
        AND id_usuario = $2
        RETURNING id_jardin
    `, [
        idJardin,
        idUsuario
    ]);

    return result.rows[0];
};

module.exports = {
    crearJardin,
    obtenerJardines,
    obtenerJardinPorId,
    actualizarJardin,
    eliminarJardin
};