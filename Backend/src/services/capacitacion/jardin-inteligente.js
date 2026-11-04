const { error, esObjetoExacto } = require('./minijuego-decision');

const SECTORES = ['A', 'B', 'C', 'D'];
const ACCIONES = new Set(['regar', 'observar', 'drenaje', 'lectura']);
const ACCION_POR_ESTADO = Object.freeze({
    baja: 'regar',
    objetivo: 'observar',
    alta: 'drenaje',
    sin_lectura: 'lectura'
});

const validarConfiguracionJardin = (config) => {
    if (!esObjetoExacto(config, ['version', 'sectores']) || config.version !== 1
        || !Array.isArray(config.sectores) || config.sectores.length !== SECTORES.length) {
        error('La configuración del jardín virtual no es válida', 500);
    }
    const ids = [];
    for (const sector of config.sectores) {
        if (!esObjetoExacto(sector, ['id', 'pista', 'estado_dato'])
            || !SECTORES.includes(sector.id)
            || typeof sector.pista !== 'string' || !sector.pista.trim() || sector.pista.length > 300
            || !['baja', 'objetivo', 'alta', 'sin_lectura'].includes(sector.estado_dato)) {
            error('La ficha de un sector virtual no es válida', 500);
        }
        ids.push(sector.id);
    }
    if (new Set(ids).size !== SECTORES.length || !SECTORES.every((id) => ids.includes(id))) {
        error('El jardín virtual debe incluir una ficha A, B, C y D', 500);
    }
    return config;
};

const normalizarJardinInteligente = (respuesta, contexto = {}) => {
    validarConfiguracionJardin(contexto.configuracion);
    if (!esObjetoExacto(respuesta, ['version', 'decisiones']) || respuesta.version !== 1
        || !Array.isArray(respuesta.decisiones) || respuesta.decisiones.length !== SECTORES.length) {
        error('La respuesta requiere una decisión para cada sector virtual');
    }
    const decisions = respuesta.decisiones.map((decision) => {
        if (!esObjetoExacto(decision, ['sector', 'accion'])
            || !SECTORES.includes(decision.sector) || !ACCIONES.has(decision.accion)) {
            error('Cada decisión debe incluir un sector y una acción permitida');
        }
        return { sector: decision.sector, accion: decision.accion };
    }).sort((a, b) => SECTORES.indexOf(a.sector) - SECTORES.indexOf(b.sector));
    if (new Set(decisions.map((item) => item.sector)).size !== SECTORES.length) {
        error('No se permiten sectores duplicados');
    }
    return { version: 1, decisiones: decisions };
};

const calificarJardinInteligente = (respuesta, configuracion, correcta) => {
    validarConfiguracionJardin(configuracion);
    if (!esObjetoExacto(correcta, SECTORES)
        || SECTORES.some((sector) => !ACCIONES.has(correcta[sector]))) {
        error('La clave del jardín virtual no es válida', 500);
    }
    if (configuracion.sectores.some((sector) => correcta[sector.id] !== ACCION_POR_ESTADO[sector.estado_dato])) {
        error('La clave de respuesta no coincide con las pistas del jardín virtual', 500);
    }
    const aciertos = respuesta.decisiones.filter((decision) =>
        decision.accion === correcta[decision.sector]).length;
    return {
        respuesta,
        correcta: aciertos === SECTORES.length,
        explicacion: `${aciertos} de ${SECTORES.length} decisiones coinciden con las pistas ficticias. Interpreta cada escenario por separado; esto no controla bombas ni representa una lectura real.`,
        resultado_juego: { version: 1, decisiones_correctas: aciertos, total_decisiones: SECTORES.length }
    };
};

module.exports = {
    normalizarJardinInteligente,
    calificarJardinInteligente,
    validarConfiguracionJardin,
    SECTORES,
    ACCIONES
};
