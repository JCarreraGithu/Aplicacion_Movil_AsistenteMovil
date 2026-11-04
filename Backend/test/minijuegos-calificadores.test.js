const test = require('node:test');
const assert = require('node:assert/strict');
const {
    calificarActividad,
    normalizarRespuestaActividad,
    huellaActividad
} = require('../src/services/capacitacion.service');

const opcionesLuz = [
    { clave: 'indirecta', texto: 'Luz filtrada' },
    { clave: 'directa', texto: 'Sol directo intenso' },
    { clave: 'oscuro', texto: 'Sin entrada de luz' }
];
const configLuz = { version: 1, pista: 'La ficha indica luz brillante indirecta.' };

const opcionesDetective = [
    { clave: 'observar', texto: 'Revisar drenaje y reunir observaciones' },
    { clave: 'regar', texto: 'Añadir agua inmediatamente' },
    { clave: 'diagnosticar', texto: 'Afirmar una enfermedad específica' }
];
const configDetective = {
    version: 1,
    situacion: 'Una hoja está caída y el sustrato sigue húmedo.',
    observaciones: ['No hay más observaciones.', 'No se conoce la especie.']
};

const configJardin = {
    version: 1,
    sectores: [
        { id: 'A', pista: 'Bajo el intervalo ficticio.', estado_dato: 'baja' },
        { id: 'B', pista: 'Dentro del intervalo ficticio.', estado_dato: 'objetivo' },
        { id: 'C', pista: 'Sobre el intervalo ficticio.', estado_dato: 'alta' },
        { id: 'D', pista: 'No hay lectura en la ficha.', estado_dato: 'sin_lectura' }
    ]
};
const respuestaJardin = (overrides = {}) => ({
    version: 1,
    decisiones: [
        { sector: 'A', accion: 'regar' },
        { sector: 'B', accion: 'observar' },
        { sector: 'C', accion: 'drenaje' },
        { sector: 'D', accion: 'lectura' }
    ].map((decision) => ({ ...decision, ...overrides[decision.sector] }))
});
const correctaJardin = { A: 'regar', B: 'observar', C: 'drenaje', D: 'lectura' };

test('Sol o sombra valida selección y la califica según opciones y clave del servidor', () => {
    const buena = calificarActividad(
        'minijuego_luz', { version: 1, seleccion: 'indirecta' },
        'indirecta', configLuz, opcionesLuz
    );
    const mala = calificarActividad(
        'minijuego_luz', { version: 1, seleccion: 'directa' },
        'indirecta', configLuz, opcionesLuz
    );
    assert.equal(buena.correcta, true);
    assert.equal(mala.correcta, false);
    assert.deepEqual(buena.resultado_juego, { version: 1, seleccion: 'indirecta' });
    for (const respuesta of [
        { version: 1, seleccion: 'inventada' },
        { version: 1, seleccion: 'directa', correcto: true },
        { version: 2, seleccion: 'indirecta' },
        'indirecta'
    ]) {
        assert.throws(() => calificarActividad(
            'minijuego_luz', respuesta, 'indirecta', configLuz, opcionesLuz
        ), (error) => error.status === 400);
    }
    assert.throws(() => calificarActividad(
        'minijuego_luz', { version: 1, seleccion: 'indirecta' },
        'indirecta', { version: 2, pista: 'Inválida' }, opcionesLuz
    ), (error) => error.status === 500);
});

test('Detective de plantas califica evidencia y rechaza acciones o campos manipulados', () => {
    assert.equal(calificarActividad(
        'diagnostico_interactivo', { version: 1, accion: 'observar' },
        'observar', configDetective, opcionesDetective
    ).correcta, true);
    assert.equal(calificarActividad(
        'diagnostico_interactivo', { version: 1, accion: 'regar' },
        'observar', configDetective, opcionesDetective
    ).correcta, false);
    for (const respuesta of [
        { version: 1, accion: 'curar' },
        { version: 1, accion: 'observar', xp: 999 },
        { version: 2, accion: 'observar' },
        null
    ]) {
        assert.throws(() => calificarActividad(
            'diagnostico_interactivo', respuesta, 'observar', configDetective, opcionesDetective
        ), (error) => error.status === 400);
    }
    assert.throws(() => normalizarRespuestaActividad(
        { version: 1, accion: 'observar' }, 'diagnostico_interactivo',
        { configuracion: { ...configDetective, observaciones: [] }, opciones: opcionesDetective }
    ), (error) => error.status === 500);
});

test('Jardín inteligente valida una decisión única por cada sector y calcula en servidor', () => {
    const buena = calificarActividad(
        'simulacion_jardin', respuestaJardin(), correctaJardin, configJardin
    );
    assert.equal(buena.correcta, true);
    assert.deepEqual(buena.resultado_juego, {
        version: 1,
        decisiones_correctas: 4,
        total_decisiones: 4
    });
    assert.equal(calificarActividad(
        'simulacion_jardin', respuestaJardin({ C: { accion: 'observar' } }),
        correctaJardin, configJardin
    ).correcta, false);
    assert.throws(() => calificarActividad(
        'simulacion_jardin', respuestaJardin(),
        { ...correctaJardin, A: 'observar' }, configJardin
    ), (error) => error.status === 500);

    const duplicada = respuestaJardin();
    duplicada.decisiones[3].sector = 'C';
    for (const respuesta of [
        { ...respuestaJardin(), correcto: true },
        { version: 1, decisiones: respuestaJardin().decisiones.slice(0, 3) },
        duplicada,
        respuestaJardin({ D: { accion: 'activar_bomba' } }),
        { version: 2, decisiones: respuestaJardin().decisiones }
    ]) {
        assert.throws(() => calificarActividad(
            'simulacion_jardin', respuesta, correctaJardin, configJardin
        ), (error) => error.status === 400);
    }
    const reverse = {
        version: 1,
        decisiones: [...respuestaJardin().decisiones].reverse()
    };
    const normal = normalizarRespuestaActividad(
        respuestaJardin(), 'simulacion_jardin', { configuracion: configJardin }
    );
    const reverseNormal = normalizarRespuestaActividad(
        reverse, 'simulacion_jardin', { configuracion: configJardin }
    );
    assert.deepEqual(reverseNormal, normal);
    assert.equal(huellaActividad(7, 19, normal), huellaActividad(7, 19, reverseNormal));
});
