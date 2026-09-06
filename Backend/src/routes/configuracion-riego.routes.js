const express = require('express');

const {
    crearConfiguracion,
    obtenerConfiguracion
} = require('../controllers/configuracion-riego.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post(
    '/:idSector/configuracion',
    crearConfiguracion
);

router.get(
    '/:idSector/configuracion',
    obtenerConfiguracion
);

module.exports = router;