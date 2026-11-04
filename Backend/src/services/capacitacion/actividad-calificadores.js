const { normalizarSimulacionRiego, calificarSimulacionRiego } = require('./simulacion-riego');
const { normalizarMinijuegoLuz, calificarMinijuegoLuz } = require('./minijuego-luz');
const { normalizarDetectivePlantas, calificarDetectivePlantas } = require('./detective-plantas');
const { normalizarJardinInteligente, calificarJardinInteligente } = require('./jardin-inteligente');

class ActividadCalificadorError extends Error {
    constructor(message) {
        super(message);
        this.status = 400;
    }
}

const canonicalizar = (value) => {
    if (Array.isArray(value)) return `[${value.map(canonicalizar).join(',')}]`;
    if (value && typeof value === 'object') {
        return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalizar(value[key])}`).join(',')}}`;
    }
    return JSON.stringify(value);
};

const normalizarClave = (respuesta) => {
    if (typeof respuesta !== 'string' || !respuesta.trim()) {
        throw new ActividadCalificadorError('La respuesta de la actividad no es válida');
    }
    return respuesta.trim();
};

const normalizarOrden = (respuesta) => {
    if (!Array.isArray(respuesta) || respuesta.length === 0 ||
        !respuesta.every((item) => typeof item === 'string' && item.trim())) {
        throw new ActividadCalificadorError('La respuesta de la actividad no es válida');
    }
    return respuesta.map((item) => item.trim());
};

const calificadoresActividad = Object.freeze({
    opcion_multiple: Object.freeze({ normalizar: normalizarClave }),
    verdadero_falso: Object.freeze({ normalizar: normalizarClave }),
    ordenar_pasos: Object.freeze({ normalizar: normalizarOrden }),
    simulacion_riego: Object.freeze({ normalizar: normalizarSimulacionRiego, calificar: calificarSimulacionRiego }),
    // Alias de compatibilidad de una propuesta anterior del esquema.
    minijuego_riego: Object.freeze({ normalizar: normalizarSimulacionRiego, calificar: calificarSimulacionRiego }),
    minijuego_luz: Object.freeze({ normalizar: normalizarMinijuegoLuz, calificar: calificarMinijuegoLuz }),
    diagnostico_interactivo: Object.freeze({ normalizar: normalizarDetectivePlantas, calificar: calificarDetectivePlantas }),
    simulacion_jardin: Object.freeze({ normalizar: normalizarJardinInteligente, calificar: calificarJardinInteligente })
});

const normalizarRespuestaActividad = (tipo, respuesta, contexto = {}) => {
    const calificador = Object.hasOwn(calificadoresActividad, tipo) ? calificadoresActividad[tipo] : null;
    if (!calificador) {
        throw new ActividadCalificadorError(`Tipo de actividad no compatible: ${tipo}`);
    }
    return calificador.normalizar(respuesta, contexto);
};

const calificarActividad = (tipo, respuesta, respuestaCorrecta, configuracion, opciones = []) => {
    const calificador = Object.hasOwn(calificadoresActividad, tipo) ? calificadoresActividad[tipo] : null;
    if (!calificador) {
        throw new ActividadCalificadorError(`Tipo de actividad no compatible: ${tipo}`);
    }
    const contexto = { configuracion, opciones };
    const normalizada = calificador.normalizar(respuesta, contexto);
    if (calificador.calificar) return calificador.calificar(normalizada, configuracion, respuestaCorrecta, opciones);
    return {
        respuesta: normalizada,
        correcta: canonicalizar(normalizada) === canonicalizar(respuestaCorrecta)
    };
};

module.exports = {
    ActividadCalificadorError,
    calificadoresActividad,
    normalizarRespuestaActividad,
    calificarActividad
};
