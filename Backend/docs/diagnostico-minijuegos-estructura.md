# Diagnóstico estructural con reversión obligatoria

No se ejecutó este procedimiento en Neon. La causa del fallo original sigue
sin determinarse: un error tardío también revierte las columnas anteriores.

## Archivos

- diagnostico-minijuegos-estructura.sql: instrucciones de la migración actual,
  etiquetadas por etapa, dentro de un bloque con reversión obligatoria.
- verificar-diagnostico-minijuegos.sql: consultas de solo lectura para comparar
  datos y estructura antes/después.
- La migración original se conserva sin cambios. Si se edita posteriormente,
  revisar esta copia antes de reutilizar el diagnóstico.

## Ejecución manual en Neon

1. Abrir un editor dedicado y seleccionar explícitamente la rama de **pruebas**
   **pruebas-minijuegos-2026-11**. Confirmarlo en la interfaz de Neon: el nombre
   de la base no identifica por sí solo una rama. No seleccionar production ni
   la rama de respaldo. Usar el mismo rol que ejecutó la migración fallida;
   cambiar a un propietario podría ocultar un error de permisos.
   Evitar escrituras concurrentes durante la comparación.
2. Si la sesión aparece abortada, ejecutar **solo ROLLBACK;**.
   Una advertencia de que no existe una transacción activa es inocua en este
   editor dedicado.
3. Ejecutar todo verificar-diagnostico-minijuegos.sql y guardar sus resultados.
   Confirmar 1 ruta, 6 actividades, 14 intentos, 4 progresos, cero columnas
   nuevas y los seis IDs originales con 65 XP disponibles. Guardar también los
   hashes de datos y función, y los OID/definiciones de restricciones, índices
   y triggers. Si la referencia difiere de lo confirmado, detenerse.
4. Pegar **todo diagnostico-minijuegos-estructura.sql** en una consulta de la
   misma rama y ejecutarlo en una sola selección, incluidos BEGIN;, el DO
   completo y ROLLBACK;. No ejecutar los fragmentos interiores por separado
   ni eliminar el manejador de errores.
5. **Siempre se espera un error**, incluso si todas las instrucciones funcionan:
   - **ZD101 / DIAGNOSTICO COMPLETO:** todas las etapas pasaron y sus cambios
     se revirtieron. No significa que la migración se haya aplicado.
   - **Otro SQLSTATE con Dxx:** guardar el primer error completo. MESSAGE incluye
     la etapa, SQLSTATE y mensaje original. DETAIL conserva el detalle original,
     tabla/restricción/columna cuando PostgreSQL las informa, pistas y CONTEXT.
     Expandir/copiar los detalles del error en Neon.
   - **25P02 sin etapa Dxx:** la sesión ya estaba abortada. Ese no es el error
     original. Guardar el error previo si aparece, ejecutar ROLLBACK; y repetir
     el diagnóstico completo desde una sesión limpia.
   - Si se cancela o desconecta la consulta, guardar el error nativo y comprobar
     el estado antes de repetir; no inferir una etapa.
6. Después de guardar el error, ejecutar **solo ROLLBACK;**. El editor puede
   detener el lote en el error del DO y no enviar el ROLLBACK del final.
   Si ya no hay transacción activa, PostgreSQL solo lo advertirá.
7. Volver a ejecutar verificar-diagnostico-minijuegos.sql en la misma rama.
   Comparar todo con el paso 3: mismos conteos y hashes de las cuatro tablas,
   cero columnas nuevas, mismos IDs/XP y mismos OID/definiciones de constraints,
   índices y triggers, y mismo hash de la función. Si algo difiere, detenerse.
8. Compartir el primer error Dxx con sus detalles para corregir su causa.
   No ejecutar aún la migración real, el seed ni la publicación.

## Por qué no confirma cambios

El archivo contiene una transacción explícita que termina en ROLLBACK, pero su
seguridad no depende de cómo Neon divida el lote o conserve la sesión del editor.
Las instrucciones de prueba se ejecutan dentro de un bloque PL/pgSQL interno con
EXCEPTION, que constituye una subtransacción:

- Si falla una instrucción, PostgreSQL revierte las escrituras anteriores del
  bloque **antes de entrar al manejador**, que recoge el primer error.
- Si todas funcionan, una excepción intencional obliga a revertirlas.
- Después se emite siempre una excepción hacia el editor. En caso de fallo real
  se conserva su SQLSTATE. Tampoco se puede confirmar la transacción exterior.

La protección funciona incluso con autocommit o si el editor no llega al ROLLBACK
final. Ese ROLLBACK adicional limpia una posible sesión exterior abortada.
No se depende de mantener una sesión entre clics para garantizar la reversión.
No hay COMMIT, cambios de función/triggers ni operaciones no transaccionales
como CREATE INDEX CONCURRENTLY. Se adquieren locks de DDL durante la prueba:
ejecutar únicamente en la rama de pruebas indicada.

## Etapas y posibles causas

| Etapa | Instrucción | Posibles causas |
|---|---|---|
| D00 | Preflight original completo | Datos, metadatos o rol diferentes desde la verificación anterior. |
| D01 | Agregar actividad.configuracion | Falta de propiedad de la tabla (42501), bloqueo o conflicto de columna. |
| D02 | Agregar ruta.orden / id_ruta_previa | Propiedad, bloqueo o conflicto de columnas. |
| D03 | Verificar forma de columnas | Tipo, nullabilidad o default incompatibles. |
| D04 | Quitar uq_capacitacion_ruta_version | FK/objeto dependiente del índice (2BP01), propiedad o bloqueo. No usa CASCADE. |
| D05 | UNIQUE, CHECK, FK y validación de rutas | Nombres ocupados, datos incompatibles, permisos REFERENCES o definición distinta. CONTEXT identifica el DDL interno. |
| D06 | Crear índice parcial | Nombre ocupado, permisos o bloqueo. |
| D07 | Verificar índice | Forma/estado/predicado distinto. |
| D08 | Ampliar CHECK de tipos | Forma/casts/conjunto de valores inesperados, nombre ocupado, permisos o filas fuera de los ocho tipos. |

Estas posibilidades todavía no identifican la causa real en Neon.

## Validación local en PostgreSQL 18

Se creó un fixture local con el esquema del repositorio, seis actividades/65 XP,
14 intentos y cuatro progresos. No se ejecutó el seed. Se probaron:

1. D00-D08 completas: ZD101 y reversión de todos los cambios.
2. El DO solo, sin envoltura de transacción (autocommit): mismo resultado.
3. FK de prueba dependiente de la unicidad antigua: primer error D04/2BP01.
   Las columnas agregadas antes del error tampoco quedaron persistidas.
4. Rol lector sin propiedad: primer error D01/42501.

En los cuatro casos el archivo de verificación dio resultados idénticos antes y
después. Se detuvo y eliminó el clúster temporal. No se accedió a Neon.
