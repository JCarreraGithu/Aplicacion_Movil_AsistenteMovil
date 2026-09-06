const pool = require('../config/database');

const crearEspecie = async (especie) => {
    const {
        nombre_comun,
        nombre_cientifico,
        descripcion,
        frecuencia_riego
    } = especie;

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.especie_planta
        (
            nombre_comun,
            nombre_cientifico,
            descripcion,
            frecuencia_riego
        )
        VALUES ($1, $2, $3, $4)
        RETURNING
            id_especie,
            nombre_comun,
            nombre_cientifico,
            descripcion,
            frecuencia_riego
    `, [
        nombre_comun,
        nombre_cientifico,
        descripcion,
        frecuencia_riego
    ]);

    return result.rows[0];
};

const obtenerEspecies = async () => {
    const result = await pool.query(`
        SELECT
            id_especie,
            nombre_comun,
            nombre_cientifico,
            descripcion,
            frecuencia_riego
        FROM SISTEMA_RIEGO.especie_planta
        ORDER BY nombre_comun
    `);

    return result.rows;
};

const obtenerEspeciePorId = async (idEspecie) => {
    const result = await pool.query(`
        SELECT
            id_especie,
            nombre_comun,
            nombre_cientifico,
            descripcion,
            frecuencia_riego
        FROM SISTEMA_RIEGO.especie_planta
        WHERE id_especie = $1
    `, [idEspecie]);

    return result.rows[0];
};

module.exports = {
    crearEspecie,
    obtenerEspecies,
    obtenerEspeciePorId
};