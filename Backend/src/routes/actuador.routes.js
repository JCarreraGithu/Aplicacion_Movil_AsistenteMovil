const express = require('express');

const {
    crearActuador,
    obtenerActuadoresPorSector
} = require('../controllers/actuador.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearActuador);

router.get('/sector/:idSector', obtenerActuadoresPorSector);

module.exports = router;