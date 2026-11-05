const router = require('express').Router();
const c = require('../controllers/conversacion.controller');
router.use(require('../middlewares/auth.middleware'));
router.get('/', c.listar);
router.put('/:id', c.guardar);
router.delete('/:id', c.eliminar);
module.exports = router;
