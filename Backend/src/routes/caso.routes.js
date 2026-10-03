const express = require('express');

const {
    crearCaso,
    obtenerCasos,
    contarCasosActivos,
    obtenerCasoPorId,
    agregarSeguimiento,
    cambiarEstadoCaso
} = require('../controllers/caso.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

// GET /api/casos?estado=abierto
router.get('/', obtenerCasos);

// GET /api/casos/activos/contador  -> badge del dashboard
router.get('/activos/contador', contarCasosActivos);

// POST /api/casos
router.post('/', crearCaso);

// GET /api/casos/:idCaso
router.get('/:idCaso', obtenerCasoPorId);

// PATCH /api/casos/:idCaso/estado
router.patch('/:idCaso/estado', cambiarEstadoCaso);

// POST /api/casos/:idCaso/seguimientos
router.post('/:idCaso/seguimientos', agregarSeguimiento);

module.exports = router;
