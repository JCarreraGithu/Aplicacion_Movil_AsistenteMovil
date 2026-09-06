const sectorService = require('../services/sector.service');

const crearSector = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.idJardin;

        const sector = await sectorService.crearSector(
            idUsuario,
            idJardin,
            req.body
        );

        if (!sector) {
            return res.status(404).json({
                mensaje: 'Jardín no encontrado'
            });
        }

        res.status(201).json(sector);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al crear el sector'
        });
    }
};

const obtenerSectores = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.idJardin;

        const sectores = await sectorService.obtenerSectores(
            idUsuario,
            idJardin
        );

        if (sectores === null) {
            return res.status(404).json({
                mensaje: 'Jardín no encontrado'
            });
        }

        res.json(sectores);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener los sectores'
        });
    }
};

const obtenerSectorPorId = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.idJardin;
        const idSector = req.params.idSector;

        const sector = await sectorService.obtenerSectorPorId(
            idUsuario,
            idJardin,
            idSector
        );

        if (!sector) {
            return res.status(404).json({
                mensaje: 'Sector no encontrado'
            });
        }

        res.json(sector);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al obtener el sector'
        });
    }
};

const actualizarSector = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.idJardin;
        const idSector = req.params.idSector;

        const sector = await sectorService.actualizarSector(
            idUsuario,
            idJardin,
            idSector,
            req.body
        );

        if (!sector) {
            return res.status(404).json({
                mensaje: 'Sector no encontrado'
            });
        }

        res.json(sector);

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al actualizar el sector'
        });
    }
};

const eliminarSector = async (req, res) => {
    try {
        const idUsuario = req.usuario.id_usuario;
        const idJardin = req.params.idJardin;
        const idSector = req.params.idSector;

        const sector = await sectorService.eliminarSector(
            idUsuario,
            idJardin,
            idSector
        );

        if (!sector) {
            return res.status(404).json({
                mensaje: 'Sector no encontrado'
            });
        }

        res.json({
            mensaje: 'Sector eliminado correctamente'
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            mensaje: 'Error al eliminar el sector'
        });
    }
};

module.exports = {
    crearSector,
    obtenerSectores,
    obtenerSectorPorId,
    actualizarSector,
    eliminarSector
};