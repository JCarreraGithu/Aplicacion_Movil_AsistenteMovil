const express = require('express');

const {
    crearRiego,
    obtenerRiegosPorSector
} = require('../controllers/riego.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearRiego);

router.get('/sector/:idSector', obtenerRiegosPorSector);

module.exports = router;