const express = require('express');

const {
    crearLectura,
    obtenerLecturasPorSensor
} = require('../controllers/lectura-sensor.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearLectura);

router.get('/sensor/:idSensor', obtenerLecturasPorSensor);

module.exports = router;