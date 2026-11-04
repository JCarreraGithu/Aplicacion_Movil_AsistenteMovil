class MinijuegoDecisionError extends Error {
    constructor(message) {
        super(message);
        this.status = 400;
    }
}

const error = (message, status = 400) => {
    const failure = new MinijuegoDecisionError(message);
    failure.status = status;
    throw failure;
};
const esObjetoExacto = (value, keys) => value !== null
    && typeof value === 'object' && !Array.isArray(value)
    && Object.keys(value).length === keys.length
    && keys.every((key) => Object.hasOwn(value, key));

const validarOpciones = (opciones) => {
    if (!Array.isArray(opciones) || opciones.length < 2 || opciones.length > 8) {
        error('Las opciones del desafío no son válidas');
    }
    const keys = opciones.map((option) => option?.clave);
    if (keys.some((key) => typeof key !== 'string' || !key.trim())
        || new Set(keys).size !== keys.length) {
        error('Las claves de las opciones no son válidas');
    }
    return new Set(keys);
};

const validarConfigDecision = (config, { campoPista = 'pista', camposExtra = [] } = {}) => {
    const fields = ['version', campoPista, ...camposExtra];
    if (!esObjetoExacto(config, fields) || config.version !== 1
        || typeof config[campoPista] !== 'string'
        || !config[campoPista].trim() || config[campoPista].length > 500) {
        error('La configuración del minijuego no es válida', 500);
    }
    return config;
};

const seleccionar = (respuesta, campo, opciones) => {
    if (!esObjetoExacto(respuesta, ['version', campo]) || respuesta.version !== 1
        || typeof respuesta[campo] !== 'string') {
        error(`La respuesta requiere version 1 y el campo ${campo}`);
    }
    const claves = validarOpciones(opciones);
    if (!claves.has(respuesta[campo])) error('La opción seleccionada no pertenece al desafío');
    return { version: 1, [campo]: respuesta[campo] };
};

module.exports = {
    MinijuegoDecisionError,
    error,
    esObjetoExacto,
    validarOpciones,
    validarConfigDecision,
    seleccionar
};
