const express = require('express');

const {
    identificarPlanta,
    registrarPlantaIdentificada
} = require('../controllers/identificacion.controller');

const verificarToken =
    require('../middlewares/auth.middleware');

const upload =
    require('../middlewares/upload.middleware');

const router = express.Router();


// ============================================================
// TODAS LAS RUTAS REQUIEREN JWT
// ============================================================

router.use(verificarToken);


// ============================================================
// IDENTIFICAR PLANTA
// ============================================================

router.post(
    '/identificar',
    upload.single('imagen'),
    identificarPlanta
);


// ============================================================
// REGISTRAR PLANTA CON FOTO
// ============================================================

router.post(
    '/registrar',
    upload.single('imagen'),
    registrarPlantaIdentificada
);


module.exports = router;