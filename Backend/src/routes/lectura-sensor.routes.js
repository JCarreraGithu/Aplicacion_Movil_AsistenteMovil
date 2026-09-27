
const express = require('express');

const {
    crearLectura,
    obtenerLecturasPorSensor,
    obtenerUltimasLecturasPorSector
} = require('../controllers/lectura-sensor.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

// ============================================================
// AUTENTICACIÓN
// ============================================================

router.use(verificarToken);

// ============================================================
// REGISTRAR LECTURA
// ============================================================

router.post('/', crearLectura);

// ============================================================
// OBTENER LECTURAS DE UN SENSOR
// ============================================================

router.get(
    '/sensor/:idSensor',
    obtenerLecturasPorSensor
);

// ============================================================
// OBTENER ÚLTIMAS LECTURAS DE UN SECTOR
// ============================================================

router.get(
    '/sector/:idSector',
    obtenerUltimasLecturasPorSector
);

module.exports = router;

