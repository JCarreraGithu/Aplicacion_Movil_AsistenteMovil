const pool = require('../config/database');

const verificarJardinUsuario = async (idJardin, idUsuario) => {
    const result = await pool.query(`
        SELECT id_jardin
        FROM SISTEMA_RIEGO.jardin
        WHERE id_jardin = $1
        AND id_usuario = $2
    `, [idJardin, idUsuario]);

    return result.rows[0];
};

const crearSector = async (idUsuario, idJardin, sector) => {

    const jardin = await verificarJardinUsuario(
        idJardin,
        idUsuario
    );

    if (!jardin) {
        return null;
    }

    const {
        nombre,
        descripcion
    } = sector;

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.sector
        (id_jardin, nombre, descripcion)
        VALUES ($1, $2, $3)
        RETURNING
            id_sector,
            id_jardin,
            nombre,
            descripcion
    `, [
        idJardin,
        nombre,
        descripcion
    ]);

    return result.rows[0];
};

const obtenerSectores = async (idUsuario, idJardin) => {

    const jardin = await verificarJardinUsuario(
        idJardin,
        idUsuario
    );

    if (!jardin) {
        return null;
    }

    const result = await pool.query(`
        SELECT
            id_sector,
            id_jardin,
            nombre,
            descripcion
        FROM SISTEMA_RIEGO.sector
        WHERE id_jardin = $1
        ORDER BY id_sector
    `, [idJardin]);

    return result.rows;
};

const obtenerSectorPorId = async (
    idUsuario,
    idJardin,
    idSector
) => {

    const jardin = await verificarJardinUsuario(
        idJardin,
        idUsuario
    );

    if (!jardin) {
        return null;
    }

    const result = await pool.query(`
        SELECT
            id_sector,
            id_jardin,
            nombre,
            descripcion
        FROM SISTEMA_RIEGO.sector
        WHERE id_sector = $1
        AND id_jardin = $2
    `, [
        idSector,
        idJardin
    ]);

    return result.rows[0];
};

const actualizarSector = async (
    idUsuario,
    idJardin,
    idSector,
    sector
) => {

    const jardin = await verificarJardinUsuario(
        idJardin,
        idUsuario
    );

    if (!jardin) {
        return null;
    }

    const {
        nombre,
        descripcion
    } = sector;

    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.sector
        SET
            nombre = $1,
            descripcion = $2
        WHERE id_sector = $3
        AND id_jardin = $4
        RETURNING
            id_sector,
            id_jardin,
            nombre,
            descripcion
    `, [
        nombre,
        descripcion,
        idSector,
        idJardin
    ]);

    return result.rows[0];
};

const eliminarSector = async (
    idUsuario,
    idJardin,
    idSector
) => {

    const jardin = await verificarJardinUsuario(
        idJardin,
        idUsuario
    );

    if (!jardin) {
        return null;
    }

    const result = await pool.query(`
        DELETE FROM SISTEMA_RIEGO.sector
        WHERE id_sector = $1
        AND id_jardin = $2
        RETURNING id_sector
    `, [
        idSector,
        idJardin
    ]);

    return result.rows[0];
};

module.exports = {
    crearSector,
    obtenerSectores,
    obtenerSectorPorId,
    actualizarSector,
    eliminarSector
};