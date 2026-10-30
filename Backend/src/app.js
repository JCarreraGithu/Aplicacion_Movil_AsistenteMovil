const express = require('express');
const pool = require('./config/database');
const authRoutes = require('./routes/auth.routes');
const verificarToken = require('./middlewares/auth.middleware');
const usuarioRoutes = require('./routes/usuario.routes');
const jardinRoutes = require('./routes/jardin.routes');
const sectorRoutes = require('./routes/sector.routes');
const especiePlantaRoutes = require('./routes/especie-planta.routes');
const plantaRoutes = require('./routes/planta.routes');
const configuracionRiegoRoutes = require('./routes/configuracion-riego.routes');
const consultaIaRoutes = require('./routes/consulta-ia.routes');
const sensorRoutes = require('./routes/sensor.routes');
const actuadorRoutes = require('./routes/actuador.routes');
const lecturaSensorRoutes =
    require('./routes/lectura-sensor.routes');
const riegoRoutes = require('./routes/riego.routes');
const cors = require('cors');
const app = express();
const identificacionRoutes = require('./routes/identificacion.routes');
const casoRoutes = require('./routes/caso.routes');
const path = require('path');
const { rateLimit } = require('express-rate-limit');
const dispositivoRoutes = require('./routes/dispositivo.routes');
const comandoActuadorRoutes = require('./routes/comando-actuador.routes');
const deviceRoutes = require('./routes/device.routes');
const capacitacionRoutes = require('./routes/capacitacion.routes');



app.use(express.json());
app.use(cors());
app.use('/api/auth', authRoutes);
app.use('/api/usuarios', usuarioRoutes);
app.use('/api/jardines', jardinRoutes);
app.use('/api/jardines', sectorRoutes);
app.use('/api/especies', especiePlantaRoutes);
app.use('/api/plantas', plantaRoutes);
app.use('/api/sectores', configuracionRiegoRoutes);
app.use('/api/dispositivos', dispositivoRoutes);
app.use('/api/lecturas', lecturaSensorRoutes);
app.use('/api/sensores', sensorRoutes);
app.use('/api/actuadores', comandoActuadorRoutes);
app.use('/api/actuadores', actuadorRoutes);
app.use('/api/riegos', riegoRoutes);
app.use(
    '/api/identificacion',
    identificacionRoutes
);
app.use('/api/ia', consultaIaRoutes);
app.use('/api/casos', casoRoutes);
app.use('/api/capacitacion', capacitacionRoutes);
app.use('/api/device', rateLimit({
    windowMs: 60 * 1000,
    limit: 120,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: (_req, res) => res.status(429).json({ mensaje: 'Demasiadas solicitudes del dispositivo' })
}), deviceRoutes);



const PORT = Number(process.env.PORT) || 3000;

app.get('/', (req, res) => {
    res.json({
        mensaje: 'API Sistema de Riego funcionando'
    });
});
app.use(
    '/uploads',
    express.static(
        path.join(__dirname, 'uploads')
    )
);

app.get('/api/protegido', verificarToken, (req, res) => {
    res.json({
        mensaje: 'Acceso autorizado',
        usuario: req.usuario
    });
});

// Último middleware: evita que Express exponga páginas HTML o trazas internas.
app.use((error, req, res, next) => {
    if (res.headersSent) {
        return next(error);
    }

    if (error.type === 'entity.parse.failed') {
        return res.status(400).json({ mensaje: 'JSON inválido' });
    }

    console.error('Error interno no controlado:', error);
    return res.status(500).json({ mensaje: 'Error interno' });
});

app.listen(PORT, () => {
    console.log(`Servidor ejecutándose en http://localhost:${PORT}`);
});
