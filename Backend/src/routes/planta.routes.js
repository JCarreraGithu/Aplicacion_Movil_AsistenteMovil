const express = require('express');

const {
    crearPlanta,
    obtenerPlantas,
    obtenerPlantaPorId
} = require('../controllers/planta.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post(
    '/:idSector/plantas',
    crearPlanta
);

router.get(
    '/:idSector/plantas',
    obtenerPlantas
);

router.get(
    '/:idSector/plantas/:idPlanta',
    obtenerPlantaPorId
);

module.exports = router;