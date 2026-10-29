const express = require('express');

const {
    crearCaso,
    obtenerCasos,
    contarCasosActivos,
    obtenerCasoPorId,
    agregarSeguimiento,
    cambiarEstadoCaso,
    cerrarCasoConResultado,
    obtenerTareas,
    crearTarea,
    actualizarTarea,
    obtenerRecordatorios,
    obtenerRecordatoriosUsuario,
    crearRecordatorio,
    actualizarRecordatorio,
    completarRecordatorio
} = require('../controllers/caso.controller');

const verificarToken = require('../middlewares/auth.middleware');
const uploadCaso = require('../middlewares/caso-upload.middleware');

const router = express.Router();

router.use(verificarToken);

// GET /api/casos?estado=abierto
router.get('/', obtenerCasos);

// GET /api/casos/activos/contador  -> badge del dashboard
router.get('/activos/contador', contarCasosActivos);

// POST /api/casos
router.post('/', crearCaso);

// Lista de recordatorios activos del usuario para la bandeja de notificaciones.
router.get('/recordatorios', obtenerRecordatoriosUsuario);

// GET /api/casos/:idCaso
router.get('/:idCaso', obtenerCasoPorId);

// PATCH /api/casos/:idCaso/estado
router.patch('/:idCaso/estado', cambiarEstadoCaso);
router.post('/:idCaso/cerrar', cerrarCasoConResultado);

// POST /api/casos/:idCaso/seguimientos
router.post('/:idCaso/seguimientos', uploadCaso.single('imagen'), agregarSeguimiento);

router.get('/:idCaso/tareas', obtenerTareas);
router.post('/:idCaso/tareas', crearTarea);
router.patch('/:idCaso/tareas/:idTarea', actualizarTarea);
router.get('/:idCaso/recordatorios', obtenerRecordatorios);
router.post('/:idCaso/recordatorios', crearRecordatorio);
router.patch('/:idCaso/recordatorios/:idRecordatorio', actualizarRecordatorio);
router.patch('/:idCaso/recordatorios/:idRecordatorio/cerrar', completarRecordatorio);

module.exports = router;
