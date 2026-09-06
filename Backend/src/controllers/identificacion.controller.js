const identificacionService =
    require('../services/identificacion.service');


// ============================================================
// IDENTIFICAR PLANTA
// ============================================================

const identificarPlanta = async (req, res) => {

    try {

        if (!req.file) {

            return res.status(400).json({
                mensaje: 'Debe enviar una imagen'
            });
        }

        const resultado =
            await identificacionService.identificarPlanta(
                req.file
            );

        res.status(200).json(resultado);

    } catch (error) {

        console.error(
            'ERROR IDENTIFICACIÓN:',
            error
        );

        res.status(500).json({
            mensaje: 'Error al identificar la planta',
            error: error.message
        });
    }
};


// ============================================================
// REGISTRAR PLANTA IDENTIFICADA
// ============================================================

const registrarPlantaIdentificada = async (req, res) => {

    try {

        // ------------------------------------------------------
        // VERIFICAR IMAGEN
        // ------------------------------------------------------

        if (!req.file) {

            return res.status(400).json({
                mensaje: 'Debe enviar una imagen'
            });
        }


        // ------------------------------------------------------
        // USUARIO
        // ------------------------------------------------------

        const idUsuario =
            req.usuario.id_usuario;


        // ------------------------------------------------------
        // DATOS RECIBIDOS
        // ------------------------------------------------------

        const {
            idSector,
            nombre,
            nombreCientifico,
            descripcion,
            fechaRegistro
        } = req.body;


        // ------------------------------------------------------
        // VALIDACIONES
        // ------------------------------------------------------

        if (!idSector) {

            return res.status(400).json({
                mensaje:
                    'El sector es obligatorio'
            });
        }

        if (!nombre) {

            return res.status(400).json({
                mensaje:
                    'El nombre de la planta es obligatorio'
            });
        }


        // ------------------------------------------------------
        // REGISTRAR
        // ------------------------------------------------------

        const planta =
            await identificacionService.registrarPlantaIdentificada(
                idUsuario,
                idSector,
                {
                    nombre,
                    nombreCientifico,
                    descripcion,
                    fechaRegistro,
                    archivo: req.file
                }
            );


        // ------------------------------------------------------
        // SECTOR NO ENCONTRADO
        // ------------------------------------------------------

        if (!planta) {

            return res.status(404).json({
                mensaje:
                    'El sector no existe o no pertenece al usuario'
            });
        }


        // ------------------------------------------------------
        // RESPUESTA
        // ------------------------------------------------------

        res.status(201).json(planta);

    } catch (error) {

        console.error(
            'ERROR REGISTRANDO PLANTA:',
            error
        );

        res.status(500).json({
            mensaje:
                'Error al registrar la planta',
            error: error.message
        });
    }
};


module.exports = {
    identificarPlanta,
    registrarPlantaIdentificada
};