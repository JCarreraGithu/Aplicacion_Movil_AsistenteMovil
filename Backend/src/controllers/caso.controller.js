const casoService = require('../services/caso.service');

// ============================================================
// CREAR CASO
// ============================================================

const crearCaso = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;

        const {
            id_planta,
            id_sector,
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
        if ((id_planta != null && (!Number.isInteger(Number(id_planta)) || Number(id_planta) < 1)) ||
            (id_sector != null && (!Number.isInteger(Number(id_sector)) || Number(id_sector) < 1)) ||
            (id_consulta != null && (!Number.isInteger(Number(id_consulta)) || Number(id_consulta) < 1))) {
            return res.status(400).json({ mensaje: 'Los identificadores de planta, sector y consulta deben ser enteros positivos' });
        }

        const caso = await casoService.crearCaso(idUsuario, {
            id_planta,
            id_sector,
            id_consulta,
            titulo,
            diagnostico,
            plan_trabajo
        });

        if (!caso) {
            return res.status(404).json({
                mensaje: 'La planta, sector o consulta indicada no existe o no te pertenece'
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

const obtenerTareas = async (req, res) => {
    try {
        const tareas = await casoService.obtenerTareas(req.usuario.id_usuario, req.params.idCaso);
        if (!tareas) return res.status(404).json({ mensaje: 'Caso no encontrado' });
        res.json(tareas);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al obtener las tareas del caso' });
    }
};

const crearTarea = async (req, res) => {
    try {
        const { descripcion, fecha_limite } = req.body;
        if (!descripcion || !descripcion.trim()) return res.status(400).json({ mensaje: 'La descripción es obligatoria' });
        const tarea = await casoService.crearTarea(req.usuario.id_usuario, req.params.idCaso, descripcion.trim(), fecha_limite);
        if (!tarea) return res.status(404).json({ mensaje: 'Caso no encontrado' });
        res.status(201).json(tarea);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al crear la tarea' });
    }
};

const actualizarTarea = async (req, res) => {
    try {
        const { completada } = req.body;
        if (typeof completada !== 'boolean') return res.status(400).json({ mensaje: 'completada debe ser booleano' });
        const tarea = await casoService.actualizarTarea(req.usuario.id_usuario, req.params.idCaso, req.params.idTarea, completada);
        if (!tarea) return res.status(404).json({ mensaje: 'Tarea o caso no encontrado' });
        res.json(tarea);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al actualizar la tarea' });
    }
};

const obtenerRecordatorios = async (req, res) => {
    try {
        const recordatorios = await casoService.obtenerRecordatorios(req.usuario.id_usuario, req.params.idCaso);
        if (!recordatorios) return res.status(404).json({ mensaje: 'Caso no encontrado' });
        res.json(recordatorios);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al obtener recordatorios' });
    }
};

const obtenerRecordatoriosUsuario = async (req, res) => {
    try {
        const recordatorios = await casoService.obtenerRecordatoriosUsuario(req.usuario.id_usuario);
        res.json(recordatorios);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al obtener las notificaciones de casos' });
    }
};

const crearRecordatorio = async (req, res) => {
    try {
        const { mensaje, fecha_recordatorio, id_tarea } = req.body;
        if (!mensaje || !mensaje.trim() || !fecha_recordatorio || Number.isNaN(Date.parse(fecha_recordatorio))) {
            return res.status(400).json({ mensaje: 'mensaje y fecha_recordatorio válida son obligatorios' });
        }
        if (new Date(fecha_recordatorio).getTime() <= Date.now()) {
            return res.status(400).json({ mensaje: 'El recordatorio debe programarse para una fecha futura' });
        }
        const recordatorio = await casoService.crearRecordatorio(
            req.usuario.id_usuario, req.params.idCaso, mensaje.trim(), fecha_recordatorio, id_tarea
        );
        if (!recordatorio) return res.status(404).json({ mensaje: 'Caso o tarea vinculada no encontrada' });
        res.status(201).json(recordatorio);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al programar el recordatorio' });
    }
};

const completarRecordatorio = async (req, res) => {
    try {
        const recordatorio = await casoService.completarRecordatorio(
            req.usuario.id_usuario, req.params.idCaso, req.params.idRecordatorio
        );
        if (!recordatorio) return res.status(404).json({ mensaje: 'Recordatorio o caso no encontrado' });
        res.json(recordatorio);
    } catch (error) {
        console.error(error);
        res.status(500).json({ mensaje: 'Error al cerrar recordatorio' });
    }
};

module.exports = {
    crearCaso,
    obtenerCasos,
    contarCasosActivos,
    obtenerCasoPorId,
    agregarSeguimiento,
    cambiarEstadoCaso,
    obtenerTareas,
    crearTarea,
    actualizarTarea,
    obtenerRecordatorios,
    obtenerRecordatoriosUsuario,
    crearRecordatorio,
    completarRecordatorio
};
