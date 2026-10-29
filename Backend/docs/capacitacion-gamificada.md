# Capacitación gamificada

La migración `migrations/2026_add_capacitacion_gamificada.sql` agrega un camino, actividades y tablas de intentos/progreso. Es aditiva respecto de las tablas tradicionales de capacitación. **No se ha ejecutado** en PostgreSQL.

El seed liga el camino a la versión publicada vigente de «¿Cuándo debemos regar una planta?» y crea seis desafíos como `borrador`. No publica rutas ni crea versiones de lección. Si la lección y el módulo no están publicados cuando se ejecute, el seed no insertará el camino; después se puede volver a ejecutar la migración, que usa inserciones idempotentes.

## Revisión y aplicación manual

Revisar el SQL y el contenido de las seis actividades antes de aplicarlo. Aplicación sugerida con `psql` (la migración contiene `BEGIN`/`COMMIT`):

```powershell
psql -v ON_ERROR_STOP=1 -d "nombre_real_de_la_base" -f Backend/migrations/2026_add_capacitacion_gamificada.sql
```

Verificar la ruta y cada actividad:

```sql
SELECT r.id_ruta, r.slug, r.titulo, r.estado, v.numero_version,
       l.titulo AS leccion, m.titulo AS modulo
FROM SISTEMA_RIEGO.capacitacion_ruta r
JOIN SISTEMA_RIEGO.capacitacion_leccion_version v USING (id_leccion_version)
JOIN SISTEMA_RIEGO.capacitacion_leccion l USING (id_leccion)
JOIN SISTEMA_RIEGO.capacitacion_modulo m USING (id_modulo)
ORDER BY r.id_ruta;

SELECT a.id_actividad, a.orden, a.tipo, a.titulo, a.enunciado,
       a.opciones, a.xp, a.explicacion
FROM SISTEMA_RIEGO.capacitacion_actividad a
JOIN SISTEMA_RIEGO.capacitacion_ruta r USING (id_ruta)
ORDER BY r.id_ruta, a.orden;
```

Los endpoints autenticados ocultan rutas en borrador y no exponen respuestas correctas antes de resolver una actividad. Tras revisión editorial y funcional, publicar la ruta de forma explícita en una transacción manual. Sustituir `:id_ruta` por el identificador revisado y confirmar que hay seis actividades:

```sql
BEGIN;
UPDATE SISTEMA_RIEGO.capacitacion_ruta r
SET estado = 'publicada', fecha_publicacion = CURRENT_TIMESTAMP
WHERE r.id_ruta = :id_ruta
  AND r.estado = 'borrador'
  AND (SELECT COUNT(*) FROM SISTEMA_RIEGO.capacitacion_actividad a
       WHERE a.id_ruta = r.id_ruta) = 6
RETURNING id_ruta, estado, fecha_publicacion;
COMMIT;
```

Una ruta publicada y sus actividades quedan inmutables por trigger. Si el contenido necesita correcciones, prepara otra versión editorial y revisa la estrategia para una ruta nueva; no edites esta ruta.

## Reversión

`migrations/2026_add_capacitacion_gamificada.down.sql` elimina solo las cuatro tablas nuevas y la protección asociada. Su ejecución borra el progreso y los intentos gamificados; requiere respaldo y decisión explícita. No es necesaria para el uso normal y no se ejecuta automáticamente.

## API para Flutter

- `GET /api/capacitacion/modulos/:idModulo/rutas`
- `GET /api/capacitacion/rutas/:idRuta`
- `POST /api/capacitacion/rutas/:idRuta/actividades/:idActividad/respuestas`

Los tres endpoints requieren JWT. El POST requiere `Idempotency-Key` y `{ "respuesta": "clave" }` o `{ "respuesta": ["clave1", "clave2"] }` para ordenar. La calificación, explicación y XP provienen del backend; cada usuario solo consulta y cambia su propio progreso.
