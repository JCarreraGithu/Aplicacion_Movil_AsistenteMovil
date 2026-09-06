const { GoogleGenAI } = require('@google/genai');
const pool = require('../config/database');

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

// ============================================================
// CONSULTA NORMAL DE TEXTO
// ============================================================

const generarRespuesta = async (pregunta) => {
console.log('ENVIANDO IMAGEN A GEMINI...');
    const response = await ai.models.generateContent({
        model: 'gemini-3.5-flash-lite',
        contents: pregunta,
        config: {
            systemInstruction:
                'Eres un asistente especializado en jardinería y cuidado de plantas. ' +
                'Responde de forma clara, sencilla y útil. ' +
                'No inventes datos específicos sobre una planta si no tienes suficiente información.'
        }
    });
console.log('GEMINI RESPONDIO');
    return response.text;
};

// ============================================================
// ANALIZAR PLANTA MEDIANTE FOTOGRAFÍA
// ============================================================

const analizarPlanta = async ({
    imagenBase64,
    mimeType,
    pregunta
}) => {

    const prompt = `
Eres un asistente especializado en jardinería y cuidado de plantas.

El usuario ha proporcionado una fotografía de una planta y puede haber
realizado una pregunta específica sobre ella.

Tu prioridad principal es RESPONDER DIRECTAMENTE A LA PREGUNTA DEL USUARIO
utilizando la fotografía como evidencia visual.

No debes realizar automáticamente un análisis completo de la planta si la
pregunta del usuario es específica.

Por ejemplo:
- Si pregunta por el color de las hojas, analiza principalmente el color
  y explica si parece normal para esa planta o si podría indicar algún
  problema.
- Si pregunta por hojas amarillas, concéntrate principalmente en las
  hojas amarillas.
- Si pregunta por manchas, analiza las manchas visibles.
- Si pregunta por falta de agua, analiza los signos visibles relacionados
  con hidratación.
- Si pregunta por iluminación, analiza los signos visibles relacionados
  con la luz.
- Si pregunta qué planta es, intenta identificarla visualmente, pero
  aclara que la identificación no es completamente segura.

IMPORTANTE:

- Responde primero y directamente a la pregunta realizada por el usuario.
- Utiliza la fotografía como referencia para responder.
- No inventes características que no puedan observarse.
- Si algo no puede determinarse mediante la fotografía, dilo claramente.
- No afirmes enfermedades, plagas o problemas con certeza si la imagen
  no permite confirmarlos.
- Utiliza expresiones como "podría indicar", "parece", "posiblemente" o
  "es compatible con" cuando exista incertidumbre.
- Si la pregunta requiere información que no puede determinarse solamente
  mediante la fotografía, indícalo y proporciona una recomendación general.
- Responde en español.
- Sé claro, natural y fácil de entender.
- No repitas innecesariamente la pregunta del usuario.
- No hagas un análisis completo de todas las categorías de la planta
  a menos que el usuario solicite un análisis general.

Pregunta del usuario:
${pregunta && pregunta.trim().length > 0
        ? pregunta
        : 'Analiza visualmente el estado general de esta planta y dime si observas algún problema visible.'}
`;

    const response = await ai.models.generateContent({
        // Utiliza aquí un modelo Gemini con soporte para imágenes.
        model: 'gemini-3.5-flash-lite',

        contents: [
            {
                inlineData: {
                    mimeType: mimeType,
                    data: imagenBase64
                }
            },
            {
                text: prompt
            }
        ]
    });

    return response.text;
};

// ============================================================
// GUARDAR CONSULTA
// ============================================================

const guardarConsulta = async (
    idUsuario,
    pregunta,
    respuesta
) => {

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.consulta_ia
        (
            id_usuario,
            pregunta,
            respuesta,
            fecha
        )
        VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
        RETURNING
            id_consulta,
            id_usuario,
            pregunta,
            respuesta,
            fecha
    `, [
        idUsuario,
        pregunta,
        respuesta
    ]);

    return result.rows[0];
};

// ============================================================
// OBTENER HISTORIAL
// ============================================================

const obtenerConsultas = async (idUsuario) => {

    const result = await pool.query(`
        SELECT
            id_consulta,
            id_usuario,
            pregunta,
            respuesta,
            fecha
        FROM SISTEMA_RIEGO.consulta_ia
        WHERE id_usuario = $1
        ORDER BY fecha DESC
    `, [idUsuario]);

    return result.rows;
};

module.exports = {
    generarRespuesta,
    analizarPlanta,
    guardarConsulta,
    obtenerConsultas
};