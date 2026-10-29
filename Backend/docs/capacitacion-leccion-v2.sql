-- Prepara una nueva versión de la lección, pero la deja en borrador.
-- Guardar este archivo como UTF-8. Ejecutar manualmente solo después de revisar
-- el destino, respaldos y contenido. Este archivo NO publica la versión 2.
-- La versión 1, sus preguntas, fuentes, intentos y progreso no se modifican.

SET client_encoding TO 'UTF8';
BEGIN;

-- Serializa la creación de versiones de esta lección y falla de forma segura si
-- la lección/versión esperada no coincide. No reutilizar IDs serial manualmente.
DO $guard$
DECLARE
    v_id_leccion INTEGER;
BEGIN
    SELECT l.id_leccion
      INTO v_id_leccion
      FROM SISTEMA_RIEGO.capacitacion_leccion l
      JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
     WHERE l.slug = 'cuando-debemos-regar-una-planta'
       AND m.slug = 'fundamentos-del-riego'
       AND m.publicado = TRUE
     FOR UPDATE OF l;

    IF v_id_leccion IS NULL THEN
        RAISE EXCEPTION 'No se encontró la lección publicada esperada en el módulo publicado';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM SISTEMA_RIEGO.capacitacion_leccion_version v
         WHERE v.id_leccion = v_id_leccion
           AND v.numero_version = 1
           AND v.estado = 'publicada'
    ) THEN
        RAISE EXCEPTION 'La versión 1 publicada no coincide con lo esperado';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM SISTEMA_RIEGO.capacitacion_leccion_version v
         WHERE v.id_leccion = v_id_leccion
           AND v.numero_version >= 2
    ) THEN
        RAISE EXCEPTION 'Ya existe una versión 2 o posterior; revise el estado antes de continuar';
    END IF;
END;
$guard$;

INSERT INTO SISTEMA_RIEGO.capacitacion_leccion_version
    (id_leccion, numero_version, titulo, objetivo, contenido,
     calificacion_aprobacion, estado)
SELECT l.id_leccion,
       2,
       '¿Cuándo debemos regar una planta?',
       'Relacionar la observación del suelo y las condiciones de cultivo con la necesidad de revisar el riego.',
       $contenido$
       {
         "secciones": [
           {"titulo":"Observar antes de regar","texto":"No existe una frecuencia universal. Revisa la humedad cerca de la zona de raíces y observa la especie, su etapa de crecimiento, el tipo y profundidad del suelo, el tamaño de la maceta, el drenaje y el clima reciente. Las hojas por sí solas no confirman falta de agua."},
           {"titulo":"Interpretar la humedad del suelo","texto":"El suelo almacena agua en sus poros. Una comprobación manual superficial puede orientar en macetas, pero debe interpretarse según el sustrato y la profundidad de las raíces. Un sensor también requiere conocer qué mide, dónde está instalado y si está calibrado para ese suelo; una lectura aislada no describe necesariamente toda la zona radicular."},
           {"titulo":"Factores que cambian la frecuencia","texto":"Textura y estructura del suelo, drenaje, volumen de la maceta, especie, tamaño y etapa de la planta, raíces, temperatura, viento, radiación, humedad ambiental y lluvia modifican la pérdida o disponibilidad de agua. Arena suele drenar más rápido; arcilla retiene agua por más tiempo y puede requerir aplicación lenta."},
           {"titulo":"Exceso y falta de agua","texto":"El encharcamiento reduce el aire disponible para las raíces y puede dañarlas; amarillamiento o marchitez también pueden tener otras causas. La falta de agua reduce el agua disponible y puede causar marchitez, pero el calor puede producir síntomas temporales. Comprueba la humedad del suelo y el drenaje antes de atribuir una causa."},
           {"titulo":"Ejemplos prácticos","texto":"Ejemplo 1: una maceta pequeña en un día cálido y ventoso puede secarse antes que una maceta grande a la sombra; comprueba el sustrato antes de decidir. Ejemplo 2: si el suelo permanece saturado, revisa drenaje y frecuencia en vez de añadir agua por rutina. Ejemplo 3: ante una planta marchita con suelo húmedo, no concluyas automáticamente que necesita más riego; revisa otras condiciones y busca orientación específica para la especie."}
         ],
         "estado_editorial":"BORRADOR_REQUIERE_REVISION_TECNICA"
       }
       $contenido$::jsonb,
       70,
       'borrador'
  FROM SISTEMA_RIEGO.capacitacion_leccion l
 WHERE l.slug = 'cuando-debemos-regar-una-planta';

INSERT INTO SISTEMA_RIEGO.capacitacion_pregunta_version
    (id_leccion_version, orden, enunciado, tipo, opciones,
     respuesta_correcta, explicacion)
SELECT v.id_leccion_version, q.orden, q.enunciado, q.tipo,
       q.opciones::jsonb, q.respuesta_correcta::jsonb, q.explicacion
  FROM SISTEMA_RIEGO.capacitacion_leccion l
  JOIN SISTEMA_RIEGO.capacitacion_leccion_version v
    ON v.id_leccion = l.id_leccion
   AND v.numero_version = 2
  CROSS JOIN (VALUES
    (1, '¿Qué conviene hacer antes de regar por rutina?', 'opcion_multiple',
     '[{"clave":"a","texto":"Comprobar la humedad en la zona de raíces y considerar el contexto de la planta"},{"clave":"b","texto":"Regar todas las plantas cada día a la misma hora"},{"clave":"c","texto":"Usar únicamente el color de una hoja"}]',
     '"a"',
     'La observación del suelo y las condiciones de cultivo ofrecen más contexto que un horario universal o un síntoma aislado.'),
    (2, '¿La frecuencia de riego depende solamente de la especie?', 'verdadero_falso',
     '[{"clave":"verdadero","texto":"Verdadero"},{"clave":"falso","texto":"Falso"}]',
     '"falso"',
     'También influyen el suelo, drenaje, raíces, recipiente y clima.'),
    (3, 'Un suelo que permanece saturado puede reducir principalmente…', 'opcion_multiple',
     '[{"clave":"a","texto":"El oxígeno disponible para las raíces"},{"clave":"b","texto":"La cantidad de luz que recibe la planta"},{"clave":"c","texto":"La temperatura del aire"}]',
     '"a"',
     'Al llenarse los poros de agua, queda menos aire disponible en la zona radicular.'),
    (4, 'Una planta marchita con suelo húmedo demuestra que necesita más agua.', 'verdadero_falso',
     '[{"clave":"verdadero","texto":"Verdadero"},{"clave":"falso","texto":"Falso"}]',
     '"falso"',
     'La marchitez no identifica por sí sola la causa; se debe revisar humedad, drenaje y otras condiciones.')
  ) AS q(orden, enunciado, tipo, opciones, respuesta_correcta, explicacion)
 WHERE l.slug = 'cuando-debemos-regar-una-planta'
   AND v.estado = 'borrador';

INSERT INTO SISTEMA_RIEGO.capacitacion_fuente
    (id_leccion_version, titulo, entidad, url, nota_editorial)
SELECT v.id_leccion_version, f.titulo, f.entidad, f.url, f.nota
  FROM SISTEMA_RIEGO.capacitacion_leccion l
  JOIN SISTEMA_RIEGO.capacitacion_leccion_version v
    ON v.id_leccion = l.id_leccion
   AND v.numero_version = 2
  CROSS JOIN (VALUES
    ('Watering Basics', 'Oregon State University Extension Service',
     'https://extension.oregonstate.edu/imported-publication/watering-basics',
     'Referencia práctica para observar humedad, diferencias entre sustratos y señales no concluyentes.'),
    ('Soil moisture monitoring to support irrigation scheduling', 'Oregon State University Extension Service',
     'https://extension.oregonstate.edu/catalog/em-9868-soil-moisture-monitoring-support-irrigation-scheduling',
     'Guía técnica revisada sobre medición de humedad, zona radicular, suelo y clima.'),
    ('Overwatering', 'Utah State University Extension',
     'https://extension.usu.edu/planthealth/ipm/ornamental-pest-guide/abiotic/overwatering',
     'Referencia sobre saturación, oxígeno radicular y síntomas que requieren interpretación contextual.')
  ) AS f(titulo, entidad, url, nota)
 WHERE l.slug = 'cuando-debemos-regar-una-planta'
   AND v.estado = 'borrador';

-- Evita confirmar una versión incompleta o una clave correcta que no esté
-- entre las opciones. Cualquier discrepancia aborta la transacción completa.
DO $validar$
DECLARE
    v_id_version INTEGER;
    v_preguntas INTEGER;
    v_fuentes INTEGER;
BEGIN
    SELECT v.id_leccion_version
      INTO v_id_version
      FROM SISTEMA_RIEGO.capacitacion_leccion l
      JOIN SISTEMA_RIEGO.capacitacion_leccion_version v
        ON v.id_leccion = l.id_leccion
       AND v.numero_version = 2
     WHERE l.slug = 'cuando-debemos-regar-una-planta'
       AND v.estado = 'borrador';

    IF v_id_version IS NULL THEN
        RAISE EXCEPTION 'No se creó la versión 2 en borrador';
    END IF;

    SELECT COUNT(*) INTO v_preguntas
      FROM SISTEMA_RIEGO.capacitacion_pregunta_version q
     WHERE q.id_leccion_version = v_id_version;
    SELECT COUNT(*) INTO v_fuentes
      FROM SISTEMA_RIEGO.capacitacion_fuente f
     WHERE f.id_leccion_version = v_id_version;

    IF v_preguntas <> 4 OR v_fuentes <> 3 THEN
        RAISE EXCEPTION 'Versión 2 incompleta: % preguntas y % fuentes', v_preguntas, v_fuentes;
    END IF;

    IF EXISTS (
        SELECT 1
          FROM SISTEMA_RIEGO.capacitacion_pregunta_version q
         WHERE q.id_leccion_version = v_id_version
           AND NOT EXISTS (
               SELECT 1
                 FROM jsonb_array_elements(q.opciones) AS opciones(opcion)
                WHERE opciones.opcion -> 'clave' = q.respuesta_correcta
           )
    ) THEN
        RAISE EXCEPTION 'Una respuesta correcta de la versión 2 no coincide con sus opciones';
    END IF;
END;
$validar$;

COMMIT;

-- Verificación de salida. La versión 2 debe seguir en borrador y la versión 1
-- no debe haber cambiado. Estas consultas son solo de lectura.
SELECT l.slug, v.numero_version, v.estado, v.fecha_publicacion,
       COUNT(DISTINCT q.id_pregunta_version) AS preguntas,
       COUNT(DISTINCT f.id_fuente) AS fuentes
  FROM SISTEMA_RIEGO.capacitacion_leccion l
  JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
  LEFT JOIN SISTEMA_RIEGO.capacitacion_pregunta_version q USING (id_leccion_version)
  LEFT JOIN SISTEMA_RIEGO.capacitacion_fuente f USING (id_leccion_version)
 WHERE l.slug = 'cuando-debemos-regar-una-planta'
 GROUP BY l.slug, v.numero_version, v.estado, v.fecha_publicacion
 ORDER BY v.numero_version;

SELECT q.orden, q.enunciado, q.tipo, q.opciones, q.respuesta_correcta, q.explicacion
  FROM SISTEMA_RIEGO.capacitacion_leccion l
  JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
  JOIN SISTEMA_RIEGO.capacitacion_pregunta_version q USING (id_leccion_version)
 WHERE l.slug = 'cuando-debemos-regar-una-planta'
   AND v.numero_version = 2
 ORDER BY q.orden;

SELECT f.titulo, f.entidad, f.url, f.nota_editorial
  FROM SISTEMA_RIEGO.capacitacion_leccion l
  JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
  JOIN SISTEMA_RIEGO.capacitacion_fuente f USING (id_leccion_version)
 WHERE l.slug = 'cuando-debemos-regar-una-planta'
   AND v.numero_version = 2
 ORDER BY f.id_fuente;

-- Antes de publicar, la versión activa debe continuar siendo la 1.
SELECT l.slug, activa.numero_version AS version_activa,
       activa.estado AS estado_version_activa
  FROM SISTEMA_RIEGO.capacitacion_leccion l
  JOIN LATERAL (
      SELECT v.numero_version, v.estado
        FROM SISTEMA_RIEGO.capacitacion_leccion_version v
       WHERE v.id_leccion = l.id_leccion
         AND v.estado = 'publicada'
       ORDER BY v.numero_version DESC
       LIMIT 1
  ) activa ON TRUE
 WHERE l.slug = 'cuando-debemos-regar-una-planta';

-- Revise estos valores; el script no modifica datos del módulo.
SELECT slug, titulo, descripcion
  FROM SISTEMA_RIEGO.capacitacion_modulo
 WHERE slug = 'fundamentos-del-riego';
