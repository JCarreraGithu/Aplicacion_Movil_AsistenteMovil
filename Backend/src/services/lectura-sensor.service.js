const pool = require('../config/database');

const crearLectura = async (
    idSensor,
    valor,
    unidad,
    fechaHora
) => {

    const result = await pool.query(`
        INSERT INTO SISTEMA_RIEGO.lectura_sensor
        (
            id_sensor,
            valor,
            unidad,
            fecha_hora
        )
        VALUES ($1, $2, $3, $4)
        RETURNING
            id_lectura,
            id_sensor,
            valor,
            unidad,
            fecha_hora
    `, [
        idSensor,
        valor,
        unidad,
        fechaHora
    ]);

    const lectura = result.rows[0];

    const configuracion = await pool.query(`
        SELECT
            s.id_sector,
            c.humedad_minima,
            c.humedad_maxima,
            c.modo_automatico,
            a.id_actuador,
            a.codigo AS actuador,
            a.estado AS estado_actuador
        FROM SISTEMA_RIEGO.sensor s
        JOIN SISTEMA_RIEGO.configuracion_riego c
            ON c.id_sector = s.id_sector
        JOIN SISTEMA_RIEGO.actuador a
            ON a.id_sector = s.id_sector
        WHERE s.id_sensor = $1
        AND s.estado = 'ACTIVO'
        LIMIT 1
    `, [idSensor]);

    if (configuracion.rows.length === 0) {

        return {
            lectura,
            automatizacion: {
                necesita_riego: false,
                accion: 'NINGUNA',
                motivo: 'No existe configuración de riego para el sector'
            }
        };
    }

    const datos = configuracion.rows[0];

    let necesitaRiego = false;
    let accion = 'NINGUNA';

    if (
        datos.modo_automatico === true &&
        Number(valor) < Number(datos.humedad_minima)
    ) {
        necesitaRiego = true;
        accion = 'ACTIVAR';
    }

    return {
        lectura,
        automatizacion: {
            necesita_riego: necesitaRiego,
            accion,
            actuador: datos.actuador,
            estado_actuador: datos.estado_actuador,
            humedad_minima: datos.humedad_minima,
            humedad_maxima: datos.humedad_maxima,
            modo_automatico: datos.modo_automatico
        }
    };
};


const obtenerLecturasPorSensor = async (idSensor) => {

    const result = await pool.query(`
        SELECT
            id_lectura,
            id_sensor,
            valor,
            unidad,
            fecha_hora
        FROM SISTEMA_RIEGO.lectura_sensor
        WHERE id_sensor = $1
        ORDER BY fecha_hora DESC
    `, [idSensor]);

    return result.rows;
};


module.exports = {
    crearLectura,
    obtenerLecturasPorSensor
};  