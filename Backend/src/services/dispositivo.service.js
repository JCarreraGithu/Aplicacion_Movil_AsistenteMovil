const pool = require('../config/database');

const crearDispositivo = async (idUsuario, idSector, nombre, apiKeyHash) => {
    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.dispositivo (id_sector, nombre, api_key_hash)
        SELECT $1, $3, $4
        WHERE EXISTS (
            SELECT 1 FROM SISTEMA_RIEGO.sector s
            JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
            WHERE s.id_sector = $1 AND j.id_usuario = $2
        )
        RETURNING id_dispositivo, id_sector, nombre, activo, ultimo_contacto, fecha_creacion
    `, [idSector, idUsuario, nombre, apiKeyHash]);
    return result.rows[0] || null;
};

const listarDispositivos = async (idUsuario, idSector, onlineSeconds) => {
    const result = await pool.query(`
        SELECT d.id_dispositivo, d.id_sector, d.nombre, d.activo, d.ultimo_contacto,
               COALESCE(d.ultimo_contacto >= CURRENT_TIMESTAMP - ($3 * INTERVAL '1 second'), FALSE) AS en_linea
        FROM SISTEMA_RIEGO.dispositivo d
        JOIN SISTEMA_RIEGO.sector s ON s.id_sector = d.id_sector
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE j.id_usuario = $1 AND ($2::INTEGER IS NULL OR d.id_sector = $2)
        ORDER BY d.id_dispositivo
    `, [idUsuario, idSector, onlineSeconds]);
    return result.rows;
};

const sectorPerteneceUsuario = async (idUsuario, idSector) => {
    const result = await pool.query(`
        SELECT 1 FROM SISTEMA_RIEGO.sector s
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE s.id_sector = $1 AND j.id_usuario = $2
    `, [idSector, idUsuario]);
    return result.rows.length > 0;
};

const rotarClave = async (idUsuario, idDispositivo, apiKeyHash) => {
    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.dispositivo d SET api_key_hash = $3
        FROM SISTEMA_RIEGO.sector s
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE d.id_sector = s.id_sector AND d.id_dispositivo = $1 AND j.id_usuario = $2
        RETURNING d.id_dispositivo
    `, [idDispositivo, idUsuario, apiKeyHash]);
    return result.rows[0] || null;
};

const actualizarActivo = async (idUsuario, idDispositivo, activo) => {
    const result = await pool.query(`
        UPDATE SISTEMA_RIEGO.dispositivo d SET activo = $3
        FROM SISTEMA_RIEGO.sector s
        JOIN SISTEMA_RIEGO.jardin j ON j.id_jardin = s.id_jardin
        WHERE d.id_sector = s.id_sector AND d.id_dispositivo = $1 AND j.id_usuario = $2
        RETURNING d.id_dispositivo, d.id_sector, d.nombre, d.activo, d.ultimo_contacto
    `, [idDispositivo, idUsuario, activo]);
    return result.rows[0] || null;
};

module.exports = {
    crearDispositivo,
    listarDispositivos,
    sectorPerteneceUsuario,
    rotarClave,
    actualizarActivo
};
