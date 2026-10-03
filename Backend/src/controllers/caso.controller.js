const casoService = require('../services/caso.service');

// ============================================================
// CREAR CASO
// ============================================================

const crearCaso = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;

        const {
            id_planta,
            id_consulta,
            titulo,
            diagnostico,
            plan_trabajo
        } = req.body;

        if (!titulo || !diagnostico || !plan_trabajo) {
            return res.status(400).json({
                mensaje:
                    'titulo, diagnostico y plan_trabajo son obligatorios'
            });
        }

        const caso = await casoService.crearCaso(idUsuario, {
            id_planta,
            id_consulta,
            titulo,
            diagnostico,
            plan_trabajo
        });

        if (!caso) {
            return res.status(404).json({
                mensaje: 'La planta indicada no existe o no te pertenece'
            });
        }

        res.status(201).json(caso);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear el caso'
        });
    }
};

// ============================================================
// OBTENER CASOS (?estado=abierto|en_progreso|resuelto|abandonado)
// ============================================================

const obtenerCasos = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const { estado } = req.query;

        const casos = await casoService.obtenerCasos(
            idUsuario,
            estado
        );

        res.json(casos);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los casos'
        });
    }
};

// ============================================================
// CONTAR CASOS ACTIVOS (badge del dashboard)
// ============================================================

const contarCasosActivos = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;

        const total = await casoService.contarCasosActivos(
            idUsuario
        );

        res.json({ total });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al contar los casos activos'
        });
    }
};

// ============================================================
// OBTENER UN CASO POR ID
// ============================================================

const obtenerCasoPorId = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idCaso = req.params.idCaso;

        const caso = await casoService.obtenerCasoPorId(
            idUsuario,
            idCaso
        );

        if (!caso) {
            return res.status(404).json({
                mensaje: 'Caso no encontrado'
            });
        }

        res.json(caso);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener el caso'
        });
    }
};

// ============================================================
// AGREGAR SEGUIMIENTO
// ============================================================

const agregarSeguimiento = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idCaso = req.params.idCaso;
        const { nota, imagen_url } = req.body;

        if (!nota || nota.trim().length === 0) {
            return res.status(400).json({
                mensaje: 'La nota de seguimiento es obligatoria'
            });
        }

        const seguimiento = await casoService.agregarSeguimiento(
            idUsuario,
            idCaso,
            nota,
            imagen_url
        );

        if (!seguimiento) {
            return res.status(404).json({
                mensaje: 'Caso no encontrado'
            });
        }

        res.status(201).json(seguimiento);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al agregar el seguimiento'
        });
    }
};

// ============================================================
// CAMBIAR ESTADO DEL CASO
// ============================================================

const cambiarEstadoCaso = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idCaso = req.params.idCaso;
        const { estado } = req.body;

        if (!estado) {
            return res.status(400).json({
                mensaje: 'El estado es obligatorio'
            });
        }

        const resultado = await casoService.cambiarEstadoCaso(
            idUsuario,
            idCaso,
            estado
        );

        if (resultado === 'estado_invalido') {
            return res.status(400).json({
                mensaje:
                    'Estado inválido. Usa: abierto, en_progreso, resuelto o abandonado'
            });
        }

        if (!resultado) {
            return res.status(404).json({
                mensaje: 'Caso no encontrado'
            });
        }

        res.json(resultado);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al actualizar el estado del caso'
        });
    }
};

module.exports = {
    crearCaso,
    obtenerCasos,
    contarCasosActivos,
    obtenerCasoPorId,
    agregarSeguimiento,
    cambiarEstadoCaso
};
