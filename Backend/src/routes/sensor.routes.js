const express = require('express');

const {
    crearSensor,
    obtenerSensoresPorSector
} = require('../controllers/sensor.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearSensor);

router.get('/sector/:idSector', obtenerSensoresPorSector);

module.exports = router;