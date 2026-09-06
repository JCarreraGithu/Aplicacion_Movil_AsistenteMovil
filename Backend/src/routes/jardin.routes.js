const express = require('express');

const {
    crearJardin,
    obtenerJardines,
    obtenerJardinPorId,
    actualizarJardin,
    eliminarJardin
} = require('../controllers/jardin.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post('/', crearJardin);

router.get('/', obtenerJardines);

router.get('/:id', obtenerJardinPorId);

router.put('/:id', actualizarJardin);

router.delete('/:id', eliminarJardin);

module.exports = router;