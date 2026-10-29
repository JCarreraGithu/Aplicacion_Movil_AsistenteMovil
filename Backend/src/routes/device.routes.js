const express = require('express');
const controller = require('../controllers/device.controller');
const commandController = require('../controllers/comando-actuador.controller');
const verificarDispositivo = require('../middlewares/verificar-dispositivo');

const router = express.Router();
router.use(verificarDispositivo);
router.post('/lecturas', controller.registrarLecturas);
router.post('/riegos', controller.registrarRiego);
router.get('/comandos', commandController.listarDispositivo);
router.post('/comandos/:id/ack', commandController.ackDispositivo);

module.exports = router;
