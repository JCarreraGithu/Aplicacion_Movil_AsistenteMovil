const express = require('express');
const controller = require('../controllers/dispositivo.controller');
const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();
router.use(verificarToken);
router.post('/', controller.crear);
router.get('/', controller.listar);
router.post('/:id/rotar-clave', controller.rotarClave);
router.patch('/:id', controller.actualizar);

module.exports = router;
