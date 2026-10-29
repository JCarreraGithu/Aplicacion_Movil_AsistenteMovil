const express = require('express');
const verificarToken = require('../middlewares/auth.middleware');
const { crearCapacitacionController } = require('../controllers/capacitacion.controller');

const crearRouterCapacitacion = ({ controller = crearCapacitacionController(), auth = verificarToken } = {}) => {
    const router = express.Router();
    router.use(auth);
    router.get('/modulos', controller.obtenerModulos);
    router.get('/modulos/:idModulo/lecciones', controller.obtenerLeccionesModulo);
    router.get('/modulos/:idModulo/rutas', controller.obtenerRutasModulo);
    router.get('/rutas/:idRuta', controller.obtenerRuta);
    router.post('/rutas/:idRuta/actividades/:idActividad/respuestas', controller.registrarRespuestaActividad);
    router.get('/lecciones/:idLeccion', controller.obtenerLeccion);
    router.get('/lecciones/:idLeccion/evaluacion', controller.obtenerEvaluacion);
    router.post('/lecciones/:idLeccion/intentos', controller.registrarIntento);
    router.get('/progreso', controller.obtenerProgreso);
    return router;
};

module.exports = crearRouterCapacitacion();
module.exports.crearRouterCapacitacion = crearRouterCapacitacion;
