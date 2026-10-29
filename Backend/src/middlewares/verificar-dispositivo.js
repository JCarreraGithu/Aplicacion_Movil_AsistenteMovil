const pool = require('../config/database');
const { hashApiKey, compareApiKey } = require('../services/device-protocol');

const verificarDispositivo = async (req, res, next) => {
    const key = req.get('X-Device-Key');
    if (!key) return res.status(401).json({ mensaje: 'Dispositivo no autorizado' });

    try {
        const keyHash = hashApiKey(key);
        const result = await pool.query(`
            SELECT id_dispositivo, id_sector, api_key_hash, activo
            FROM SISTEMA_RIEGO.dispositivo
            WHERE api_key_hash = $1
        `, [keyHash]);
        const dispositivo = result.rows[0];
        if (!dispositivo || !compareApiKey(key, dispositivo.api_key_hash) || !dispositivo.activo) {
            return res.status(401).json({ mensaje: 'Dispositivo no autorizado' });
        }

        const actualizado = await pool.query(`
            UPDATE SISTEMA_RIEGO.dispositivo
            SET ultimo_contacto = CURRENT_TIMESTAMP
            WHERE id_dispositivo = $1 AND activo = TRUE AND api_key_hash = $2
            RETURNING id_dispositivo, id_sector, nombre
        `, [dispositivo.id_dispositivo, keyHash]);
        if (!actualizado.rows[0]) return res.status(401).json({ mensaje: 'Dispositivo no autorizado' });

        req.dispositivo = actualizado.rows[0];
        return next();
    } catch (error) {
        return next(error);
    }
};

module.exports = verificarDispositivo;
