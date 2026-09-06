const pool =
    require('../config/database');

const fs =
    require('fs');

const path =
    require('path');


// ============================================================
// IDENTIFICAR PLANTA CON PLANTNET
// ============================================================

const identificarPlanta = async (archivo) => {

    const formData = new FormData();

    formData.append(
        'images',
        new Blob(
            [archivo.buffer],
            {
                type: archivo.mimetype
            }
        ),
        archivo.originalname
    );

    formData.append(
        'organs',
        'leaf'
    );


    const url =
        `https://my-api.plantnet.org/v2/identify/all` +
        `?api-key=${process.env.PLANTNET_API_KEY}`;


    const response = await fetch(
        url,
        {
            method: 'POST',
            body: formData
        }
    );


    if (!response.ok) {

        const errorText =
            await response.text();

        throw new Error(
            `Error PlantNet (${response.status}): ${errorText}`
        );
    }


    const data =
        await response.json();


    if (
        !data.results ||
        data.results.length === 0
    ) {

        throw new Error(
            'PlantNet no encontró resultados'
        );
    }


    const resultados =
        data.results.slice(0, 3);


    const mejorResultado =
        resultados[0];


    const nombreCientifico =
        mejorResultado.species?.scientificName ||
        null;


    const nombreComun =
        mejorResultado.species?.commonNames?.[0] ||
        null;


    const porcentajeConfianza =
        mejorResultado.score
            ? mejorResultado.score * 100
            : 0;


    return {

        nombreIdentificado:
            nombreComun,

        nombreCientifico:
            nombreCientifico,

        porcentajeConfianza:
            porcentajeConfianza,

        resultados
    };
};


// ============================================================
// VERIFICAR SECTOR DEL USUARIO
// ============================================================

const verificarSectorUsuario = async (
    idSector,
    idUsuario
) => {

    const result =
        await pool.query(`
            SELECT
                s.id_sector
            FROM SISTEMA_RIEGO.sector s

            INNER JOIN SISTEMA_RIEGO.jardin j
                ON s.id_jardin = j.id_jardin

            WHERE
                s.id_sector = $1

            AND
                j.id_usuario = $2
        `, [
            idSector,
            idUsuario
        ]);


    return result.rows[0];
};


// ============================================================
// REGISTRAR PLANTA IDENTIFICADA
// ============================================================

const registrarPlantaIdentificada = async (
    idUsuario,
    idSector,
    planta
) => {

    // --------------------------------------------------------
    // VERIFICAR SECTOR
    // --------------------------------------------------------

    const sector =
        await verificarSectorUsuario(
            idSector,
            idUsuario
        );


    if (!sector) {
        return null;
    }


    // --------------------------------------------------------
    // GUARDAR IMAGEN
    // --------------------------------------------------------

    const carpetaFotos =
        path.join(
            __dirname,
            '..',
            'uploads',
            'plantas'
        );


    // Crear carpeta si no existe

    if (!fs.existsSync(carpetaFotos)) {

        fs.mkdirSync(
            carpetaFotos,
            {
                recursive: true
            }
        );
    }


    // --------------------------------------------------------
    // GENERAR NOMBRE ÚNICO
    // --------------------------------------------------------

    const extension =
        path.extname(
            planta.archivo.originalname
        ).toLowerCase();


    const nombreArchivo =
        `planta_${Date.now()}_${Math.round(
            Math.random() * 100000
        )}${extension}`;


    const rutaArchivo =
        path.join(
            carpetaFotos,
            nombreArchivo
        );


    // --------------------------------------------------------
    // GUARDAR ARCHIVO
    // --------------------------------------------------------

    fs.writeFileSync(
        rutaArchivo,
        planta.archivo.buffer
    );


    // --------------------------------------------------------
    // URL DE LA FOTO
    // --------------------------------------------------------

    const fotoUrl =
        `/uploads/plantas/${nombreArchivo}`;


    // --------------------------------------------------------
    // BUSCAR ESPECIE
    // --------------------------------------------------------

    let especie =
        await pool.query(`
            SELECT
                id_especie
            FROM SISTEMA_RIEGO.especie_planta

            WHERE
                LOWER(nombre_cientifico)
                =
                LOWER($1)

            LIMIT 1
        `, [
            planta.nombreCientifico
        ]);


    let idEspecie;


    // --------------------------------------------------------
    // ESPECIE EXISTENTE
    // --------------------------------------------------------

    if (especie.rows.length > 0) {

        idEspecie =
            especie.rows[0].id_especie;

    }


    // --------------------------------------------------------
    // CREAR ESPECIE
    // --------------------------------------------------------

    else {

        const nuevaEspecie =
            await pool.query(`
                INSERT INTO
                    SISTEMA_RIEGO.especie_planta
                (
                    nombre_comun,
                    nombre_cientifico
                )

                VALUES
                (
                    $1,
                    $2
                )

                RETURNING
                    id_especie
            `, [
                planta.nombre,
                planta.nombreCientifico
            ]);


        idEspecie =
            nuevaEspecie.rows[0].id_especie;
    }


    // --------------------------------------------------------
    // CREAR PLANTA
    // --------------------------------------------------------

    const result =
        await pool.query(`
            INSERT INTO
                SISTEMA_RIEGO.planta
            (
                id_sector,
                id_especie,
                nombre,
                fecha_registro,
                descripcion,
                foto_url
            )

            VALUES
            (
                $1,
                $2,
                $3,
                $4,
                $5,
                $6
            )

            RETURNING
                id_planta,
                id_sector,
                id_especie,
                nombre,
                fecha_registro,
                descripcion,
                foto_url
        `, [

            idSector,

            idEspecie,

            planta.nombre,

            planta.fechaRegistro ||
                new Date(),

            planta.descripcion ||
                null,

            fotoUrl
        ]);


    return result.rows[0];
};


module.exports = {

    identificarPlanta,

    registrarPlantaIdentificada
};