const { error, seleccionar, validarConfigDecision } = require('./minijuego-decision');

const validarConfiguracionDetective = (config) => {
    validarConfigDecision(config, { campoPista: 'situacion', camposExtra: ['observaciones'] });
    if (!Array.isArray(config.observaciones) || config.observaciones.length < 1
        || config.observaciones.length > 5
        || config.observaciones.some((item) => typeof item !== 'string'
            || !item.trim() || item.length > 300)) {
        error('Las observaciones del caso no son válidas', 500);
    }
    return config;
};

const normalizarDetectivePlantas = (respuesta, contexto = {}) => {
    validarConfiguracionDetective(contexto.configuracion);
    return seleccionar(respuesta, 'accion', contexto.opciones);
};

const calificarDetectivePlantas = (respuesta, _configuracion, correcta, opciones) => {
    if (typeof correcta !== 'string' || !opciones.some((option) => option.clave === correcta)) {
        error('La respuesta correcta del caso no es válida', 500);
    }
    return {
        respuesta,
        correcta: respuesta.accion === correcta,
        resultado_juego: { version: 1, accion: respuesta.accion }
    };
};

module.exports = {
    normalizarDetectivePlantas,
    calificarDetectivePlantas,
    validarConfiguracionDetective
};
