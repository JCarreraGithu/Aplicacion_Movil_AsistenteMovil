const commandService = require('../services/comando-actuador.service');
const { transicionComandoValida } = require('../services/device-protocol');

const enteroPositivo = (value) => Number.isInteger(Number(value)) && Number(value) > 0;
const envPositiveInt = (name, fallback) => {
    const value = Number(process.env[name]);
    return Number.isInteger(value) && value > 0 ? value : fallback;
};

const crear = async (req, res, next) => {
    const { accion, duracion_segundos } = req.body || {};
    if (!['ENCENDER', 'APAGAR'].includes(accion)) {
        return res.status(400).json({ mensaje: 'accion debe ser ENCENDER o APAGAR' });
    }
    if (accion === 'ENCENDER') {
        const max = envPositiveInt('MAX_RIEGO_MANUAL_SEGUNDOS', 300);
        if (!Number.isInteger(duracion_segundos) || duracion_segundos < 10 || duracion_segundos > max) {
            return res.status(400).json({ mensaje: `duracion_segundos debe ser un entero entre 10 y ${max}` });
        }
    }
    if (!enteroPositivo(req.params.id)) return res.status(400).json({ mensaje: 'id de actuador no válido' });
    try {
        const result = await commandService.crearComando(
            req.usuario.id_usuario, Number(req.params.id), accion, duracion_segundos
        );
        if (result.tipo === 'no_encontrado') return res.status(404).json({ mensaje: 'Actuador no encontrado' });
        if (result.tipo === 'sin_conexion') return res.status(409).json({ mensaje: 'Dispositivo sin conexión' });
        if (result.tipo === 'ya_encendido_o_pendiente') {
            return res.status(409).json({ mensaje: 'El actuador ya está encendido o tiene un comando ENCENDER pendiente' });
        }
        return res.status(201).json(result.comando);
    } catch (error) { return next(error); }
};

const obtener = async (req, res, next) => {
    if (!enteroPositivo(req.params.id) || !enteroPositivo(req.params.idComando)) {
        return res.status(400).json({ mensaje: 'Identificadores de actuador o comando no válidos' });
    }
    try {
        const command = await commandService.obtenerComandoUsuario(
            req.usuario.id_usuario, Number(req.params.id), Number(req.params.idComando)
        );
        if (!command) return res.status(404).json({ mensaje: 'Comando no encontrado' });
        return res.json(command);
    } catch (error) { return next(error); }
};

const listarDispositivo = async (req, res, next) => {
    try {
        return res.json(await commandService.comandosPendientesDispositivo(req.dispositivo));
    } catch (error) { return next(error); }
};

const ackDispositivo = async (req, res, next) => {
    const { estado } = req.body || {};
    if (!enteroPositivo(req.params.id)) return res.status(400).json({ mensaje: 'id de comando no válido' });
    if (!['EJECUTADO', 'FALLIDO'].includes(estado)) {
        return res.status(400).json({ mensaje: 'estado debe ser EJECUTADO o FALLIDO' });
    }
    try {
        const result = await commandService.ackComando(req.dispositivo, Number(req.params.id), estado);
        if (result.tipo === 'no_encontrado') return res.status(404).json({ mensaje: 'Comando no encontrado' });
        if (result.tipo === 'expirado') return res.status(409).json({ mensaje: 'El comando expiró y ya no puede ejecutarse' });
        if (result.tipo === 'transicion_invalida' || !transicionComandoValida('ENVIADO', estado)) {
            return res.status(409).json({ mensaje: 'Transición de estado no permitida' });
        }
        return res.json(result.comando);
    } catch (error) { return next(error); }
};

module.exports = { crear, obtener, listarDispositivo, ackDispositivo };
