const { error, seleccionar, validarConfigDecision } = require('./minijuego-decision');

const normalizarMinijuegoLuz = (respuesta, contexto = {}) => {
    validarConfigDecision(contexto.configuracion);
    return seleccionar(respuesta, 'seleccion', contexto.opciones);
};

const calificarMinijuegoLuz = (respuesta, _configuracion, correcta, opciones) => {
    if (typeof correcta !== 'string' || !opciones.some((option) => option.clave === correcta)) {
        error('La respuesta correcta del minijuego de luz no es válida', 500);
    }
    return {
        respuesta,
        correcta: respuesta.seleccion === correcta,
        resultado_juego: { version: 1, seleccion: respuesta.seleccion }
    };
};

module.exports = { normalizarMinijuegoLuz, calificarMinijuegoLuz };
