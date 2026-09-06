const express = require('express');

const {
    crearEspecie,
    obtenerEspecies,
    obtenerEspeciePorId
} = require('../controllers/especie-planta.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearEspecie);

router.get('/', obtenerEspecies);

router.get('/:id', obtenerEspeciePorId);

module.exports = router;