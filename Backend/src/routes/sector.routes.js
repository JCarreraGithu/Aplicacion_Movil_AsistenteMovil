const express = require('express');

const {
    crearSector,
    obtenerSectores,
    obtenerSectorPorId,
    actualizarSector,
    eliminarSector
} = require('../controllers/sector.controller');

const verificarToken = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(verificarToken);

router.post(
    '/:idJardin/sectores',
    crearSector
);

router.get(
    '/:idJardin/sectores',
    obtenerSectores
);

router.get(
    '/:idJardin/sectores/:idSector',
    obtenerSectorPorId
);

router.put(
    '/:idJardin/sectores/:idSector',
    actualizarSector
);

router.delete(
    '/:idJardin/sectores/:idSector',
    eliminarSector
);

module.exports = router;