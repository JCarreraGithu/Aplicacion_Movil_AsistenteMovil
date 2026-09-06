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
const path = require('path');



app.use(express.json());
app.use(cors());
app.use('/api/auth', authRoutes);
app.use('/api/usuarios', usuarioRoutes);
app.use('/api/jardines', jardinRoutes);
app.use('/api/jardines', sectorRoutes);
app.use('/api/especies', especiePlantaRoutes);
app.use('/api/plantas', plantaRoutes);
app.use('/api/sectores', configuracionRiegoRoutes);
app.use('/api/lecturas', lecturaSensorRoutes);
app.use('/api/sensores', sensorRoutes);
app.use('/api/actuadores', actuadorRoutes);
app.use('/api/riegos', riegoRoutes);
app.use(
    '/api/identificacion',
    identificacionRoutes
);
app.use('/api/ia', consultaIaRoutes);



const PORT = 3000;

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

app.listen(PORT, () => {
    console.log(`Servidor ejecutándose en http://localhost:${PORT}`);
});

app.get('/api/protegido', verificarToken, (req, res) => {
    res.json({
        mensaje: 'Acceso autorizado',
        usuario: req.usuario
    });
});
