const consultaService = require('../services/consulta-ia.service');

// ============================================================
// CONSULTA NORMAL
// ============================================================

const guardarConsulta = async (req, res) => {

    try {

        const idUsuario = req.usuario.id_usuario;
        const { pregunta } = req.body;

        if (!pregunta) {
            return res.status(400).json({
                mensaje: 'La pregunta es obligatoria'
            });
        }

        const respuesta =
            await consultaService.generarRespuesta(
                pregunta
            );

        const consulta =
            await consultaService.guardarConsulta(
                idUsuario,
                pregunta,
                respuesta
            );

        res.status(201).json(consulta);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje: 'Error al consultar el asistente de IA'
        });
    }
};

// ============================================================
// ANALIZAR PLANTA
// ============================================================

const analizarPlanta = async (req, res) => {

    try {

        if (!req.file) {

            return res.status(400).json({
                mensaje: 'La fotografía de la planta es obligatoria'
            });
        }

        const idUsuario =
            req.usuario.id_usuario;

        const pregunta =
            req.body.pregunta || '';

        const imagenBase64 =
            req.file.buffer.toString('base64');

        const mimeType =
            req.file.mimetype;

        console.log(
            '===================================='
        );

        console.log(
            'ANALIZANDO PLANTA CON GEMINI'
        );

        console.log(
            'Usuario:',
            idUsuario
        );

        console.log(
            'Archivo:',
            req.file.originalname
        );

        console.log(
            'Tipo:',
            mimeType
        );

        console.log(
            'Tamaño:',
            req.file.size,
            'bytes'
        );

        console.log(
            '===================================='
        );

        const respuesta =
            await consultaService.analizarPlanta({
                imagenBase64,
                mimeType,
                pregunta
            });

        // ================================================
        // GUARDAR EN HISTORIAL
        // ================================================

        const preguntaHistorial =
            pregunta.trim().isNotEmpty
                ? pregunta
                : 'Análisis visual de una planta';

        const consulta =
            await consultaService.guardarConsulta(
                idUsuario,
                preguntaHistorial,
                respuesta
            );

        res.status(201).json({
            respuesta: respuesta,
            consulta: consulta
        });

    } catch (error) {

        console.error(
            'ERROR ANALIZANDO PLANTA:'
        );

        console.error(error);

        res.status(500).json({
            mensaje:
                'Error al analizar la planta con IA'
        });
    }
};

// ============================================================
// OBTENER HISTORIAL
// ============================================================

const obtenerConsultas = async (req, res) => {

    try {

        const idUsuario =
            req.usuario.id_usuario;

        const consultas =
            await consultaService.obtenerConsultas(
                idUsuario
            );

        res.json(consultas);

    } catch (error) {

        console.error(error);

        res.status(500).json({
            mensaje:
                'Error al obtener las consultas'
        });
    }
};

module.exports = {
    guardarConsulta,
    analizarPlanta,
    obtenerConsultas
};