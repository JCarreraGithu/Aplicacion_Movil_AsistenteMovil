const capacitacionService = require('../services/capacitacion.service');

const crearCapacitacionController = (service = capacitacionService) => {
    const capturar = (handler) => async (req, res, next) => {
        try {
            await handler(req, res, next);
        } catch (error) {
            if (error.status) return res.status(error.status).json({ mensaje: error.message });
            return next(error);
        }
    };

    return {
        obtenerModulos: capturar(async (_req, res) => res.json(await service.obtenerModulos())),
        obtenerLeccionesModulo: capturar(async (req, res) => {
            const idModulo = Number(req.params.idModulo);
            if (!Number.isInteger(idModulo) || idModulo < 1) return res.status(400).json({ mensaje: 'idModulo debe ser un entero positivo' });
            const lecciones = await service.obtenerLeccionesModulo(idModulo, req.usuario.id_usuario);
            return res.json(lecciones);
        }),
        obtenerLeccion: capturar(async (req, res) => {
            const idLeccion = Number(req.params.idLeccion);
            if (!Number.isInteger(idLeccion) || idLeccion < 1) return res.status(400).json({ mensaje: 'idLeccion debe ser un entero positivo' });
            const lesson = await service.obtenerLeccion(idLeccion);
            if (!lesson) return res.status(404).json({ mensaje: 'Lección publicada no encontrada' });
            return res.json(lesson);
        }),
        obtenerEvaluacion: capturar(async (req, res) => {
            const idLeccion = Number(req.params.idLeccion);
            if (!Number.isInteger(idLeccion) || idLeccion < 1) return res.status(400).json({ mensaje: 'idLeccion debe ser un entero positivo' });
            const evaluation = await service.obtenerEvaluacion(idLeccion);
            if (!evaluation) return res.status(404).json({ mensaje: 'Evaluación publicada no encontrada' });
            return res.json(evaluation);
        }),
        obtenerRutasModulo: capturar(async (req, res) => {
            const idModulo = Number(req.params.idModulo);
            if (!Number.isInteger(idModulo) || idModulo < 1) return res.status(400).json({ mensaje: 'idModulo debe ser un entero positivo' });
            return res.json(await service.obtenerRutasModulo(idModulo, req.usuario.id_usuario));
        }),
        obtenerRuta: capturar(async (req, res) => {
            const idRuta = Number(req.params.idRuta);
            if (!Number.isInteger(idRuta) || idRuta < 1) return res.status(400).json({ mensaje: 'idRuta debe ser un entero positivo' });
            const route = await service.obtenerRuta(idRuta, req.usuario.id_usuario);
            if (!route) return res.status(404).json({ mensaje: 'Ruta publicada no encontrada' });
            return res.json(route);
        }),
        registrarRespuestaActividad: capturar(async (req, res) => {
            const idRuta = Number(req.params.idRuta);
            const idActividad = Number(req.params.idActividad);
            if (!Number.isInteger(idRuta) || idRuta < 1 || !Number.isInteger(idActividad) || idActividad < 1) {
                return res.status(400).json({ mensaje: 'Los identificadores deben ser enteros positivos' });
            }
            if (!req.body || !Object.prototype.hasOwnProperty.call(req.body, 'respuesta')) {
                return res.status(400).json({ mensaje: 'respuesta es obligatoria' });
            }
            const result = await service.registrarRespuestaActividad(
                req.usuario.id_usuario,
                idRuta,
                idActividad,
                req.get('Idempotency-Key'),
                req.body.respuesta
            );
            return res.status(result.repetido ? 200 : 201).json(result);
        }),
        registrarIntento: capturar(async (req, res) => {
            const idLeccion = Number(req.params.idLeccion);
            if (!Number.isInteger(idLeccion) || idLeccion < 1) return res.status(400).json({ mensaje: 'idLeccion debe ser un entero positivo' });
            const result = await service.registrarIntento(
                req.usuario.id_usuario,
                idLeccion,
                req.body?.id_leccion_version,
                req.get('Idempotency-Key'),
                req.body?.respuestas
            );
            return res.status(result.repetido ? 200 : 201).json(result);
        }),
        obtenerProgreso: capturar(async (req, res) => {
            if (req.query.id_usuario !== undefined) {
                return res.status(400).json({ mensaje: 'El progreso solo puede consultarse para el usuario autenticado' });
            }
            return res.json(await service.obtenerProgreso(req.usuario.id_usuario));
        })
    };
};

module.exports = { ...crearCapacitacionController(), crearCapacitacionController };
