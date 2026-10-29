# Piloto de capacitación: revisión y validación PostgreSQL

La migración `migrations/2026_add_capacitacion.sql` es aditiva e idempotente. **No se ejecutó** durante esta implementación. El contenido del módulo piloto queda en borrador y no se incluye en el catálogo API hasta su revisión/publicación.

## Aplicación manual en una base de desarrollo o staging

1. Confirma que la base seleccionada es la correcta y que existe `SISTEMA_RIEGO.usuario(id_usuario)`.
2. Haz un respaldo de esa base según el procedimiento del proyecto.
3. Desde la carpeta `Backend`, aplica el archivo manualmente con `psql` y detén la ejecución ante el primer error:

   ```powershell
   psql -v ON_ERROR_STOP=1 -d NOMBRE_BASE -f .\migrations\2026_add_capacitacion.sql
   ```

   Si la conexión requiere host/puerto/usuario, usa las opciones seguras de tu entorno; no coloques contraseñas en el historial del shell.

4. Comprueba las tablas, llaves y borrador:

   ```sql
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = 'sistema_riego'
     AND table_name LIKE 'capacitacion_%'
   ORDER BY table_name;

   SELECT id_modulo, slug, publicado
   FROM SISTEMA_RIEGO.capacitacion_modulo;

   SELECT l.slug, v.numero_version, v.estado,
          COUNT(DISTINCT q.id_pregunta_version) AS preguntas,
          COUNT(DISTINCT f.id_fuente) AS fuentes
   FROM SISTEMA_RIEGO.capacitacion_leccion l
   JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion)
   LEFT JOIN SISTEMA_RIEGO.capacitacion_pregunta_version q USING (id_leccion_version)
   LEFT JOIN SISTEMA_RIEGO.capacitacion_fuente f USING (id_leccion_version)
   GROUP BY l.slug, v.numero_version, v.estado;
   ```

   Debe aparecer el módulo con `publicado = false`, versión `borrador`, cuatro preguntas y tres referencias. Si se aplica de nuevo, no debe duplicar el piloto.

5. Valida la inmutabilidad y concurrencia en una base PostgreSQL de prueba, con dos sesiones `psql`, usando una versión borrador de prueba. No uses producción para el ensayo.

   **Sesión A**: sustituye `ID_VERSION_BORRADOR` por una versión no publicada. Inserta una pregunta; el trigger bloquea la fila de la versión hasta terminar la transacción.

   ```sql
   BEGIN;
   INSERT INTO SISTEMA_RIEGO.capacitacion_pregunta_version
       (id_leccion_version, orden, enunciado, tipo, opciones, respuesta_correcta, explicacion)
   VALUES
       (ID_VERSION_BORRADOR, 99, 'Prueba de serialización', 'opcion_multiple',
        '[{"clave":"a","texto":"A"}]'::jsonb, '"a"'::jsonb, 'Prueba');
   -- Deja esta sesión abierta mientras ejecutas la sentencia de la sesión B.
   ```

   **Sesión B**, mientras A sigue abierta: intenta publicar la misma versión. La sentencia debe esperar al bloqueo de A.

   ```sql
   BEGIN;
   UPDATE SISTEMA_RIEGO.capacitacion_leccion_version
   SET estado = 'publicada', fecha_publicacion = CURRENT_TIMESTAMP
   WHERE id_leccion_version = ID_VERSION_BORRADOR;
   ```

   Vuelve a **Sesión A** y ejecuta `COMMIT;`. B debe continuar y luego se ejecuta `COMMIT;` en B. La pregunta de A quedó insertada antes de la publicación. En una versión borrador distinta, invierte el orden: B inicia la publicación sin confirmar; A intenta insertar y queda esperando; B confirma; el `INSERT` de A debe despertar y fallar por el trigger porque ya ve la versión publicada. Ejecuta `ROLLBACK;` en A tras el error. Finalmente prueba `UPDATE` y `DELETE` sobre pregunta/fuente publicada; ambos deben fallar. Una versión publicada no se debe volver a borrador: usa una versión de prueba independiente para cada orden.

## Revisión y publicación del contenido

El borrador incluye fuentes enlazadas a Oregon State University Extension y Utah State University Extension. Una persona con conocimiento de horticultura debe revisar afirmaciones, adaptación al clima y especies locales, preguntas/respuestas y enlaces antes de publicar. Las URLs no reemplazan la revisión editorial.

Después de aprobar el contenido en el entorno correspondiente, un responsable debe publicar la versión y el módulo en una transacción controlada. El cambio de borrador a publicada se realiza una sola vez; desde entonces la versión, preguntas y fuentes quedan protegidas contra `UPDATE`, `DELETE` e inserciones nuevas. Las correcciones posteriores requieren una versión nueva con nuevas preguntas y fuentes.

Ejemplo **solo después de la revisión** (ajusta el `slug`/versión tras verificar los IDs; no lo ejecutes como parte de la migración):

```sql
BEGIN;
UPDATE SISTEMA_RIEGO.capacitacion_leccion_version v
SET estado = 'publicada', fecha_publicacion = CURRENT_TIMESTAMP
FROM SISTEMA_RIEGO.capacitacion_leccion l
WHERE v.id_leccion = l.id_leccion
  AND l.slug = 'cuando-debemos-regar-una-planta'
  AND v.numero_version = 1
  AND v.estado = 'borrador';

UPDATE SISTEMA_RIEGO.capacitacion_modulo
SET publicado = TRUE, fecha_actualizacion = CURRENT_TIMESTAMP
WHERE slug = 'fundamentos-del-riego';
COMMIT;
```

## Prueba HTTP después de publicar

Con el backend conectado a esa base y un JWT válido:

```powershell
curl.exe -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/capacitacion/modulos
curl.exe -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/capacitacion/modulos/1/lecciones
curl.exe -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/capacitacion/lecciones/1
curl.exe -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/capacitacion/lecciones/1/evaluacion
```

La evaluación no debe incluir respuestas correctas ni explicaciones. Envía luego un `POST /api/capacitacion/lecciones/1/intentos` con encabezado `Idempotency-Key` único (8–128 caracteres) y JSON `{ "id_leccion_version": 1, "respuestas": [{"id_pregunta_version": 1, "respuesta": "a"}] }`, incluyendo una respuesta por pregunta. La respuesta del POST sí contiene calificación, corrección y explicaciones. Repetir la petición con la misma clave, usuario, lección, versión y respuestas devuelve el intento original; reutilizarla con otro contenido o una ruta de lección distinta responde `409`. La misma clave de idempotencia queda aislada por `id_usuario`.

`GET /api/capacitacion/progreso` deriva siempre el usuario del JWT. No admite `id_usuario` enviado por el cliente.
