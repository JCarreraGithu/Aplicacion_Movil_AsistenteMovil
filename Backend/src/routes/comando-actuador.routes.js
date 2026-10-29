const express = require('express');
const controller = require('../controllers/comando-actuador.controller');
const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();
router.use(verificarToken);
router.post('/:id/comandos', controller.crear);
router.get('/:id/comandos/:idComando', controller.obtener);

module.exports = router;
