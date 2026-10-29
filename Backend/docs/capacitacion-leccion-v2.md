# Corrección de la lección publicada de riego

## Archivos

- `docs/capacitacion-leccion-v2.sql` crea la versión 2 y cuatro preguntas/tres fuentes, en una transacción. Deja la versión en `borrador`; no publica nada.

El SQL toma únicamente el texto UTF-8 correcto del seed de `migrations/2026_add_capacitacion.sql`. No lee ni copia campos de la versión 1. La versión publicada 1, sus preguntas/fuentes, intentos y progreso no se actualizan ni se eliminan. El script falla si falta la versión 1 publicada o ya hay una versión 2 o posterior; por ello no debe repetirse a ciegas si existe una versión 2.

## Restricciones y selección vigente

`capacitacion_leccion_version` tiene clave única `(id_leccion, numero_version)` y una restricción que requiere `fecha_publicacion` para estado `publicada`. Preguntas y fuentes se relacionan con `id_leccion_version`; sus triggers bloquean filas de versión y rechazan cambios si están publicadas. Las respuestas de intento referencian versión y pregunta. Intentos y progreso conservan las claves de la lección y versión.

Las consultas del backend en `src/services/capacitacion.service.js` eligen la última versión publicada con `ORDER BY numero_version DESC LIMIT 1` tanto para catálogo/lecciones, detalle, evaluación como progreso. Mientras v2 permanezca en borrador, la API seguirá sirviendo v1. Al publicar v2, la API elegirá v2 sin modificar v1. No hace falta un cambio de código backend para elegir la versión publicada más reciente.

## Verificación antes de publicar

Después de revisar el contenido en una sesión manual, ejecutar estas lecturas:

```sql
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

SELECT q.orden, q.enunciado, q.tipo, q.opciones,
       q.respuesta_correcta, q.explicacion
FROM SISTEMA_RIEGO.capacitacion_leccion l
JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
JOIN SISTEMA_RIEGO.capacitacion_pregunta_version q USING (id_leccion_version)
WHERE l.slug = 'cuando-debemos-regar-una-planta' AND v.numero_version = 2
ORDER BY q.orden;

SELECT f.titulo, f.entidad, f.url, f.nota_editorial
FROM SISTEMA_RIEGO.capacitacion_leccion l
JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
JOIN SISTEMA_RIEGO.capacitacion_fuente f USING (id_leccion_version)
WHERE l.slug = 'cuando-debemos-regar-una-planta' AND v.numero_version = 2
ORDER BY f.id_fuente;

SELECT l.slug, activa.numero_version AS version_activa, activa.estado
FROM SISTEMA_RIEGO.capacitacion_leccion l
JOIN LATERAL (
    SELECT v.numero_version, v.estado
    FROM SISTEMA_RIEGO.capacitacion_leccion_version v
    WHERE v.id_leccion = l.id_leccion AND v.estado = 'publicada'
    ORDER BY v.numero_version DESC LIMIT 1
) activa ON TRUE
WHERE l.slug = 'cuando-debemos-regar-una-planta';

SELECT slug, titulo, descripcion
FROM SISTEMA_RIEGO.capacitacion_modulo
WHERE slug = 'fundamentos-del-riego';
```

Se espera: v1 publicada sin cambios; v2 en borrador, cuatro preguntas y tres fuentes; cada `respuesta_correcta` coincide con una clave en `opciones`; la consulta de versión activa sigue mostrando v1. Revise título/descripción del módulo y la pertinencia/validez actual de las tres referencias antes de publicar.

La clave de respuestas incluida es: pregunta 1 `a` (observar humedad en zona radicular y contexto), pregunta 2 `falso` (la frecuencia no depende solo de la especie), pregunta 3 `a` (saturación reduce oxígeno disponible) y pregunta 4 `falso` (marchitez en suelo húmedo no demuestra por sí sola falta de agua). Las explicaciones están asociadas a cada pregunta en la versión.

Cuando se autorice crear v2, ejecutar desde `Backend` con una conexión UTF-8 y detención ante error, por ejemplo `psql -v ON_ERROR_STOP=1 -d NOMBRE_BASE -f .\docs\capacitacion-leccion-v2.sql`. Confirmar el nombre de la base y contar con respaldo antes de ejecutarlo. En pgAdmin, abrir/guardar el archivo como UTF-8 y ejecutar en la base correcta.

## Publicación manual (no incluida en el script de creación)

Solo después de aprobación editorial, respaldo y confirmación del entorno, ejecutar la actualización de estado en una transacción propia. La versión 1 permanece publicada e inmutable; la selección del backend usa la mayor versión publicada.

```sql
BEGIN;

DO $publicar$
DECLARE
    v_id_version INTEGER;
    v_preguntas INTEGER;
    v_fuentes INTEGER;
BEGIN
    SELECT v.id_leccion_version
      INTO v_id_version
      FROM SISTEMA_RIEGO.capacitacion_leccion l
      JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
      JOIN SISTEMA_RIEGO.capacitacion_modulo m ON m.id_modulo = l.id_modulo
     WHERE l.slug = 'cuando-debemos-regar-una-planta'
       AND m.slug = 'fundamentos-del-riego'
       AND m.publicado = TRUE
       AND v.numero_version = 2
       AND v.estado = 'borrador'
     FOR UPDATE OF v;

    IF v_id_version IS NULL THEN
        RAISE EXCEPTION 'No se encontró la versión 2 en borrador';
    END IF;

    SELECT COUNT(*) INTO v_preguntas
    FROM SISTEMA_RIEGO.capacitacion_pregunta_version
    WHERE id_leccion_version = v_id_version;
    SELECT COUNT(*) INTO v_fuentes
    FROM SISTEMA_RIEGO.capacitacion_fuente
    WHERE id_leccion_version = v_id_version;

    IF v_preguntas <> 4 OR v_fuentes <> 3 THEN
        RAISE EXCEPTION 'Versión incompleta: % preguntas, % fuentes', v_preguntas, v_fuentes;
    END IF;

    UPDATE SISTEMA_RIEGO.capacitacion_leccion_version
       SET estado = 'publicada', fecha_publicacion = CURRENT_TIMESTAMP
     WHERE id_leccion_version = v_id_version AND estado = 'borrador';
END;
$publicar$;

COMMIT;
```

La clave del módulo ya debe estar publicada para que la lección aparezca en los endpoints. Si no lo está, detenerse y confirmar la intención antes de cambiar `capacitacion_modulo.publicado`; el script no cambia ese dato.

## Progreso e intentos históricos

Publicar v2 no escribe en `capacitacion_progreso` ni en `capacitacion_intento`. Los intentos de v1 permanecen unidos a v1. El backend compara el `id_leccion_version` de progreso con la versión publicada activa; después de publicar v2, si el progreso almacenado apunta a v1, GET `/api/capacitacion/progreso` lo presenta como `no_iniciado` para v2 y sin calificación, sin borrar ni cambiar la fila de v1. Al completar una evaluación de v2, el servicio actualiza la única fila de progreso por usuario/lección para apuntar a v2; los intentos históricos siguen conservados.

Esta presentación por versión es comportamiento actual. No se cambió el backend ni se reinició progreso automáticamente.

## Título y descripción del módulo

El seed original define el título `Fundamentos del riego` y la descripción `Principios para observar el suelo y decidir cuándo revisar la necesidad de agua.`. El título no tiene caracteres acentuados. La descripción contiene `cuándo` y podría presentar mojibake si se insertó bajo la misma conversión defectuosa; no se consultó el módulo activo en esta tarea porque no se ejecutó SQL. Verificarlo antes de decidir una corrección:

```sql
SELECT slug, titulo, descripcion,
       encode(convert_to(titulo, 'UTF8'), 'hex') AS titulo_utf8_hex,
       encode(convert_to(descripcion, 'UTF8'), 'hex') AS descripcion_utf8_hex
FROM SISTEMA_RIEGO.capacitacion_modulo
WHERE slug = 'fundamentos-del-riego';
```

Si la consulta confirma exactamente `Principios para observar el suelo y decidir cuÃ¡ndo revisar la necesidad de agua.`, una corrección puntual propuesta sería:

```sql
UPDATE SISTEMA_RIEGO.capacitacion_modulo
SET titulo = 'Fundamentos del riego',
    descripcion = 'Principios para observar el suelo y decidir cuándo revisar la necesidad de agua.',
    fecha_actualizacion = CURRENT_TIMESTAMP
WHERE slug = 'fundamentos-del-riego'
  AND titulo = 'Fundamentos del riego'
  AND descripcion = 'Principios para observar el suelo y decidir cuÃ¡ndo revisar la necesidad de agua.';
```

Ejecutarlo solo después de confirmar que esas cadenas coinciden exactamente y revisar que afectó una fila. Si el resultado es cero o más de una fila, hacer `ROLLBACK` e investigar. No aplicar `replace()` global; esta actualización debe revisarse y autorizarse por separado porque el módulo no está versionado.
