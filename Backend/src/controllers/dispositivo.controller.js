const crypto = require('crypto');
const dispositivoService = require('../services/dispositivo.service');
const { hashApiKey } = require('../services/device-protocol');

const enteroPositivo = (value) => Number.isInteger(Number(value)) && Number(value) > 0;
const umbralOnline = () => Number(process.env.DISPOSITIVO_ONLINE_SEGUNDOS) > 0
    ? Number(process.env.DISPOSITIVO_ONLINE_SEGUNDOS) : 120;
const nuevaClave = () => crypto.randomBytes(32).toString('hex');

const crear = async (req, res, next) => {
    const { id_sector, nombre } = req.body || {};
    if (!enteroPositivo(id_sector)) return res.status(400).json({ mensaje: 'id_sector debe ser un entero positivo' });
    if (typeof nombre !== 'string' || !nombre.trim() || nombre.trim().length > 100) {
        return res.status(400).json({ mensaje: 'nombre es obligatorio y no puede superar 100 caracteres' });
    }
    try {
        const key = nuevaClave();
        const dispositivo = await dispositivoService.crearDispositivo(
            req.usuario.id_usuario, Number(id_sector), nombre.trim(), hashApiKey(key)
        );
        if (!dispositivo) return res.status(404).json({ mensaje: 'Sector no encontrado' });
        return res.status(201).json({ ...dispositivo, api_key: key });
    } catch (error) { return next(error); }
};

const listar = async (req, res, next) => {
    const idSector = req.query.id_sector;
    if (idSector !== undefined && !enteroPositivo(idSector)) {
        return res.status(400).json({ mensaje: 'id_sector debe ser un entero positivo' });
    }
    try {
        if (idSector !== undefined && !await dispositivoService.sectorPerteneceUsuario(req.usuario.id_usuario, Number(idSector))) {
            return res.status(404).json({ mensaje: 'Sector no encontrado' });
        }
        const devices = await dispositivoService.listarDispositivos(
            req.usuario.id_usuario, idSector === undefined ? null : Number(idSector), umbralOnline()
        );
        return res.json(devices.map(({ id_dispositivo, nombre, activo, ultimo_contacto, en_linea }) => ({
            id_dispositivo, nombre, activo, ultimo_contacto, en_linea
        })));
    } catch (error) { return next(error); }
};

const rotarClave = async (req, res, next) => {
    if (!enteroPositivo(req.params.id)) return res.status(400).json({ mensaje: 'id debe ser un entero positivo' });
    try {
        const key = nuevaClave();
        const result = await dispositivoService.rotarClave(req.usuario.id_usuario, Number(req.params.id), hashApiKey(key));
        if (!result) return res.status(404).json({ mensaje: 'Dispositivo no encontrado' });
        return res.json({ id_dispositivo: result.id_dispositivo, api_key: key });
    } catch (error) { return next(error); }
};

const actualizar = async (req, res, next) => {
    if (!enteroPositivo(req.params.id)) return res.status(400).json({ mensaje: 'id debe ser un entero positivo' });
    if (typeof req.body?.activo !== 'boolean') return res.status(400).json({ mensaje: 'activo debe ser booleano' });
    try {
        const result = await dispositivoService.actualizarActivo(req.usuario.id_usuario, Number(req.params.id), req.body.activo);
        if (!result) return res.status(404).json({ mensaje: 'Dispositivo no encontrado' });
        return res.json(result);
    } catch (error) { return next(error); }
};

module.exports = { crear, listar, rotarClave, actualizar };
