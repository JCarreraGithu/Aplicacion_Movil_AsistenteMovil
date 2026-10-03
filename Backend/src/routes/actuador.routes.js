const express = require('express');

const {
    crearActuador,
    obtenerActuadoresPorSector,
    actualizarEstadoActuador
} = require('../controllers/actuador.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearActuador);

router.get('/sector/:idSector', obtenerActuadoresPorSector);
router.patch('/:idActuador/estado', actualizarEstadoActuador);

module.exports = router;
