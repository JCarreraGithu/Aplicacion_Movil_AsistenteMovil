const express = require('express');
const multer = require('multer');

const {
    guardarConsulta,
    analizarPlanta,
    obtenerConsultas
} = require('../controllers/consulta-ia.controller');

const verificarToken =
    require('../middlewares/auth.middleware');

const router = express.Router();

// ============================================================
// MULTER
// ============================================================

const upload = multer({
    storage: multer.memoryStorage(),

    limits: {
        fileSize: 10 * 1024 * 1024
    },

    fileFilter: (req, file, cb) => {

        if (
            file.mimetype === 'image/jpeg' ||
            file.mimetype === 'image/png' ||
            file.mimetype === 'image/webp'
        ) {
            cb(null, true);
        } else {
            cb(
                new Error(
                    'Solo se permiten imágenes JPG, PNG o WEBP'
                )
            );
        }
    }
});

// ============================================================
// AUTENTICACIÓN
// ============================================================

router.use(verificarToken);

// ============================================================
// CONSULTA NORMAL
// ============================================================

router.post(
    '/consultas',
    guardarConsulta
);

// ============================================================
// ANALIZAR PLANTA
// ============================================================

router.post(
    '/analizar-planta',
    upload.single('imagen'),
    analizarPlanta
);

// ============================================================
// HISTORIAL
// ============================================================

router.get(
    '/consultas',
    obtenerConsultas
);

module.exports = router;