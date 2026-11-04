// Modelo educativo discreto. Sus unidades y umbrales no representan un sensor
// real ni una recomendación de riego para una especie.
const fallo = (mensaje, status = 400) => {
    const error = new Error(mensaje);
    error.status = status;
    throw error;
};
const objetoConClaves = (value, keys) => value && !Array.isArray(value)
    && typeof value === 'object' && Object.keys(value).length === keys.length
    && keys.every((key) => Object.hasOwn(value, key));

const normalizarSimulacionRiego = (respuesta) => {
    if (!objetoConClaves(respuesta, ['version', 'acciones']) || respuesta.version !== 1
        || !Array.isArray(respuesta.acciones) || respuesta.acciones.length > 20) {
        fallo('La simulación requiere version 1 y una lista de hasta 20 acciones');
    }
    return {
        version: 1,
        acciones: respuesta.acciones.map((accion) => {
            if (!objetoConClaves(accion, ['tipo', 'agua']) || accion.tipo !== 'regar'
                || !Number.isInteger(accion.agua) || accion.agua < 1 || accion.agua > 100) {
                fallo('Cada acción debe ser regar con agua entera entre 1 y 100 unidades virtuales');
            }
            return { tipo: 'regar', agua: accion.agua };
        })
    };
};

const validarConfiguracionRiego = (config) => {
    const campos = ['version', 'humedad_inicial', 'objetivo_min', 'objetivo_max',
        'incremento_por_unidad', 'agua_max_por_accion', 'agua_max_total', 'max_acciones'];
    if (!objetoConClaves(config, campos) || config.version !== 1
        || !campos.every((campo) => Number.isInteger(config[campo]))
        || config.humedad_inicial < 0 || config.humedad_inicial >= config.objetivo_min
        || config.objetivo_min < 1 || config.objetivo_min > config.objetivo_max || config.objetivo_max > 100
        || config.incremento_por_unidad < 1 || config.incremento_por_unidad > 10
        || config.agua_max_por_accion < 1 || config.agua_max_por_accion > 100
        || config.agua_max_total < config.agua_max_por_accion || config.agua_max_total > 100
        || config.max_acciones < 1 || config.max_acciones > 20) {
        fallo('Configuración de simulación de riego inválida', 500);
    }
    const dosisMinima = Math.ceil((config.objetivo_min - config.humedad_inicial) / config.incremento_por_unidad);
    if (dosisMinima > Math.min(config.agua_max_total, config.max_acciones * config.agua_max_por_accion)
        || config.humedad_inicial + dosisMinima * config.incremento_por_unidad > config.objetivo_max) {
        fallo('La configuración de simulación no permite alcanzar el objetivo', 500);
    }
    return config;
};

const calificarSimulacionRiego = (respuesta, config) => {
    validarConfiguracionRiego(config);
    const normalizada = normalizarSimulacionRiego(respuesta);
    if (normalizada.acciones.length > config.max_acciones) fallo('Se excedió el límite de acciones virtuales');
    let aguaTotal = 0;
    let humedad = config.humedad_inicial;
    for (const accion of normalizada.acciones) {
        if (accion.agua > config.agua_max_por_accion) fallo('La dosis excede el máximo por acción');
        aguaTotal += accion.agua;
        if (aguaTotal > config.agua_max_total) fallo('Se excedió el agua virtual disponible');
        humedad = Math.min(100, humedad + accion.agua * config.incremento_por_unidad);
    }
    const estado = humedad < config.objetivo_min ? 'insuficiente'
        : humedad > config.objetivo_max ? 'excesiva' : 'adecuada';
    const consejos = {
        insuficiente: 'Todavía falta humedad en este escenario. Aplica pequeñas dosis y observa el indicador.',
        adecuada: '¡Encontraste el equilibrio del escenario! Detenerte a tiempo también es cuidar.',
        excesiva: 'Te pasaste de agua en este escenario. Reinicia y prueba dosis menores; más agua no siempre ayuda.'
    };
    return {
        respuesta: normalizada,
        correcta: estado === 'adecuada',
        explicacion: consejos[estado],
        resultado_simulacion: { version: 1, humedad_final: humedad, agua_total: aguaTotal, estado }
    };
};

module.exports = { normalizarSimulacionRiego, calificarSimulacionRiego, validarConfiguracionRiego };
