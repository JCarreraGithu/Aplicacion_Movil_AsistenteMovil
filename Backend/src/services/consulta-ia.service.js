const { GoogleGenAI } = require('@google/genai');
const pool = require('../config/database');

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

// ============================================================
// OBTENER CONTEXTO DEL JARDÍN DEL USUARIO
// ============================================================

const obtenerContextoJardin = async (idUsuario) => {

    const result = await pool.query(`
        SELECT
            j.id_jardin,
            j.nombre AS jardin,
            j.ubicacion,
            j.descripcion AS descripcion_jardin,

            s.id_sector,
            s.nombre AS sector,
            s.descripcion AS descripcion_sector,

            p.id_planta,
            p.nombre AS planta,
            p.descripcion AS descripcion_planta,

            ep.nombre_comun,
            ep.nombre_cientifico,
            ep.frecuencia_riego,
            ep.descripcion AS descripcion_especie

        FROM SISTEMA_RIEGO.jardin j

        LEFT JOIN SISTEMA_RIEGO.sector s
            ON s.id_jardin = j.id_jardin

        LEFT JOIN SISTEMA_RIEGO.planta p
            ON p.id_sector = s.id_sector

        LEFT JOIN SISTEMA_RIEGO.especie_planta ep
            ON ep.id_especie = p.id_especie

        WHERE j.id_usuario = $1

        ORDER BY
            j.id_jardin,
            s.id_sector,
            p.id_planta
    `, [idUsuario]);

    if (result.rows.length === 0) {

        return `
No se encontró información registrada
sobre el jardín del usuario.
`;
    }

    let contexto = `
============================================================
INFORMACIÓN DEL JARDÍN DEL USUARIO
============================================================

`;

    let jardinActual = null;
    let sectorActual = null;

    for (const fila of result.rows) {

        // ====================================================
        // JARDÍN
        // ====================================================

        if (jardinActual !== fila.id_jardin) {

            jardinActual = fila.id_jardin;
            sectorActual = null;

            contexto += `
JARDÍN: ${fila.jardin || 'Sin nombre'}
`;

            if (fila.ubicacion) {
                contexto +=
                    `Ubicación: ${fila.ubicacion}\n`;
            }

            if (fila.descripcion_jardin) {
                contexto +=
                    `Descripción: ${fila.descripcion_jardin}\n`;
            }
        }

        // ====================================================
        // SECTOR
        // ====================================================

        if (
            fila.id_sector &&
            sectorActual !== fila.id_sector
        ) {

            sectorActual = fila.id_sector;

            contexto += `
  
SECTOR: ${fila.sector || 'Sin nombre'}
`;

            if (fila.descripcion_sector) {
                contexto +=
                    `Descripción del sector: ${fila.descripcion_sector}\n`;
            }
        }

        // ====================================================
        // PLANTA
        // ====================================================

        if (fila.id_planta) {

            contexto += `
- Planta: ${fila.planta || 'Sin nombre'}
`;

            if (fila.nombre_comun) {
                contexto +=
                    `  Nombre común: ${fila.nombre_comun}\n`;
            }

            if (fila.nombre_cientifico) {
                contexto +=
                    `  Nombre científico: ${fila.nombre_cientifico}\n`;
            }

            if (fila.frecuencia_riego !== null) {
                contexto +=
                    `  Frecuencia de riego registrada: cada ${fila.frecuencia_riego} días\n`;
            }

            if (fila.descripcion_planta) {
                contexto +=
                    `  Descripción de la planta: ${fila.descripcion_planta}\n`;
            }

            if (fila.descripcion_especie) {
                contexto +=
                    `  Información de la especie: ${fila.descripcion_especie}\n`;
            }
        }
    }

    contexto += `
============================================================
FIN DE LA INFORMACIÓN DEL JARDÍN
============================================================
`;

    return contexto;
};

// ============================================================
// OBTENER HISTORIAL RECIENTE DE LA CONVERSACIÓN
// ============================================================

const obtenerHistorialConversacion = async (
    idUsuario,
    limite = 10
) => {

    const result = await pool.query(`
        SELECT
            pregunta,
            respuesta,
            fecha
        FROM SISTEMA_RIEGO.consulta_ia
        WHERE id_usuario = $1
        ORDER BY fecha DESC
        LIMIT $2
    `, [idUsuario, limite]);

    // La consulta viene de más reciente a más antigua.
    // La invertimos para entregársela a Gemini
    // en el orden natural de la conversación.
    return result.rows.reverse();
};

// ============================================================
// FORMATEAR HISTORIAL PARA GEMINI
// ============================================================

const formatearHistorial = (historial) => {

    if (historial.length === 0) {
        return `
No existe conversación previa.
`;
    }

    let contexto = `
============================================================
HISTORIAL RECIENTE DE LA CONVERSACIÓN
============================================================

`;

    for (const item of historial) {

        contexto += `
USUARIO:
${item.pregunta}

ASISTENTE:
${item.respuesta}

------------------------------------------------------------
`;
    }

    contexto += `
============================================================
FIN DEL HISTORIAL DE CONVERSACIÓN
============================================================
`;

    return contexto;
};

// ============================================================
// CONSULTA NORMAL DE TEXTO
// ============================================================

const generarRespuesta = async (
    pregunta,
    idUsuario
) => {

    console.log(
        'OBTENIENDO CONTEXTO DEL JARDÍN...'
    );

    const contextoJardin =
        await obtenerContextoJardin(
            idUsuario
        );

    console.log(
        'CONTEXTO DEL JARDÍN OBTENIDO'
    );

    // ========================================================
    // OBTENER HISTORIAL
    // ========================================================

    console.log(
        'OBTENIENDO HISTORIAL DE CONVERSACIÓN...'
    );

    const historial =
        await obtenerHistorialConversacion(
            idUsuario
        );

    const contextoConversacion =
        formatearHistorial(
            historial
        );

    console.log(
        'HISTORIAL OBTENIDO:',
        historial.length,
        'conversaciones'
    );

    const prompt = `
Eres el asistente inteligente del sistema de
riego automatizado y conoces el jardín del usuario.

Tu función es ayudar al usuario con el cuidado,
organización y mantenimiento de SUS plantas.

La conversación debe sentirse como una conversación
continua, similar a un asistente de chat.

============================================================
INFORMACIÓN DEL JARDÍN DEL USUARIO
============================================================

La información que aparece debajo corresponde
al jardín real del usuario.

${contextoJardin}

${contextoConversacion}

============================================================
REGLAS DEL ASISTENTE
============================================================

1. Responde directamente la pregunta actual del usuario.

2. Utiliza la información del jardín cuando sea relevante.

3. Utiliza también el historial reciente para comprender
   el contexto de la conversación.

4. Si el usuario utiliza palabras como:
   "esa", "esa planta", "esa flor", "la anterior",
   "las", "ellos", "ahí", "ese sector", "¿y dónde?",
   "¿y esa?", etc., intenta determinar a qué se refiere
   utilizando las conversaciones anteriores.

5. No obligues al usuario a repetir información que ya
   aparece claramente en el historial.

6. Si el usuario pregunta dónde colocar una planta nueva,
   compara sus necesidades conocidas con los sectores y
   plantas existentes en el jardín.

7. Si el usuario pregunta por una planta que ya existe,
   utiliza su sector y los datos registrados.

8. Puedes mencionar plantas existentes por su nombre.

9. Puedes comparar una planta nueva con las plantas que
   ya existen en el jardín.

10. No inventes características específicas del jardín que
    no estén registradas.

11. Si no existe suficiente información para recomendar
    una ubicación exacta, dilo claramente y proporciona
    una recomendación general.

12. No confundas una recomendación general de jardinería
    con un dato registrado del jardín.

13. Si una referencia del usuario sigue siendo realmente
    ambigua incluso después de revisar el historial,
    solicita únicamente la aclaración necesaria.

14. Responde en español.

15. Sé natural, claro y útil.

16. No muestres al usuario el historial interno ni el
    contexto interno del jardín.

============================================================
PREGUNTA ACTUAL DEL USUARIO
============================================================

${pregunta}
`;

    console.log(
        'ENVIANDO CONSULTA A GEMINI...'
    );

    const response =
        await ai.models.generateContent({
            model: 'gemini-3.5-flash-lite',
            contents: prompt
        });

    console.log(
        'GEMINI RESPONDIO'
    );

    return response.text;
};

// ============================================================
// ANALIZAR PLANTA MEDIANTE FOTOGRAFÍA
// ============================================================

const analizarPlanta = async ({
    imagenBase64,
    mimeType,
    pregunta,
    idUsuario
}) => {

    console.log(
        'OBTENIENDO CONTEXTO DEL JARDÍN PARA ANÁLISIS...'
    );

    const contextoJardin =
        await obtenerContextoJardin(
            idUsuario
        );

    // ========================================================
    // OBTENER HISTORIAL
    // ========================================================

    const historial =
        await obtenerHistorialConversacion(
            idUsuario
        );

    const contextoConversacion =
        formatearHistorial(
            historial
        );

    const preguntaActual =
        pregunta &&
        pregunta.trim().length > 0
            ? pregunta
            : 'Analiza visualmente el estado general de esta planta y dime si observas algún problema visible.';

    const prompt = `
Eres un asistente especializado en jardinería
y cuidado de plantas.

El usuario ha proporcionado una fotografía de una planta
y puede haber realizado una pregunta específica.

La conversación debe sentirse como una conversación
continua.

============================================================
INFORMACIÓN DEL JARDÍN
============================================================

${contextoJardin}

${contextoConversacion}

============================================================
INSTRUCCIONES
============================================================

1. Responde directamente a la pregunta actual.

2. Utiliza la fotografía como evidencia visual.

3. Utiliza el historial reciente para comprender referencias
   a conversaciones anteriores.

4. Utiliza la información del jardín cuando sea relevante.

5. Si la pregunta está relacionada con dónde colocar,
   cómo cuidar o cómo integrar la planta al jardín,
   utiliza el contexto del jardín.

6. Puedes comparar la planta fotografiada con los
   sectores existentes.

7. Puedes recomendar un sector si las condiciones
   registradas son compatibles.

8. Puedes mencionar plantas existentes cuando sea útil.

9. No inventes características del jardín.

10. No inventes características que no puedan observarse.

11. No afirmes enfermedades o plagas con certeza si
    la fotografía no permite confirmarlas.

12. Utiliza expresiones como "podría indicar",
    "parece", "posiblemente" o "es compatible con"
    cuando exista incertidumbre.

13. Si el usuario utiliza referencias como "esa planta",
    "la anterior", "esa", "las", etc., utiliza el historial
    para determinar a qué se refiere.

14. No obligues al usuario a repetir información que
    ya aparece claramente en la conversación.

15. Responde primero a la pregunta específica.

16. No hagas automáticamente un análisis completo si
    el usuario realizó una pregunta concreta.

17. Si la información del jardín no es suficiente,
    proporciona una recomendación general.

18. Responde en español.

19. Sé claro, natural y fácil de entender.

============================================================
PREGUNTA ACTUAL DEL USUARIO
============================================================

${preguntaActual}
`;

    console.log(
        'ENVIANDO IMAGEN, HISTORIAL Y CONTEXTO A GEMINI...'
    );

    const response =
        await ai.models.generateContent({

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

    const result =
        await pool.query(`
            INSERT INTO SISTEMA_RIEGO.consulta_ia
            (
                id_usuario,
                pregunta,
                respuesta,
                fecha
            )
            VALUES (
                $1,
                $2,
                $3,
                CURRENT_TIMESTAMP
            )
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
// OBTENER HISTORIAL COMPLETO
// ============================================================

const obtenerConsultas = async (
    idUsuario
) => {

    const result =
        await pool.query(`
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

// ============================================================
// EXPORTACIONES
// ============================================================

module.exports = {
    generarRespuesta,
    analizarPlanta,
    obtenerContextoJardin,
    obtenerHistorialConversacion,
    guardarConsulta,
    obtenerConsultas
};