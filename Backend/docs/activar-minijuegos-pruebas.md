# Activación controlada de minijuegos en Neon

No ejecutar en `production`. Seleccionar la rama `pruebas-minijuegos-2026-11`
en el SQL Editor y conservar los resultados de cada paso.

## 1. Preflight y snapshot

Ejecutar, en una sesión limpia:

```sql
-- pegar Backend/docs/verificar-diagnostico-minijuegos.sql
-- pegar Backend/docs/diagnostico-minijuegos-preflight.sql
```

El preflight debe terminar con `Statement executed successfully` y todos los
mensajes `PF00`–`PF14` correctos. Si aparece `25P02`, ejecutar `ROLLBACK;` y
repetir desde una sesión limpia. Si falta cualquier dato, detenerse.

## 2. Migración estructural

Ejecutar como propietario de las tablas/esquema, con detención ante el primer
error:

```powershell
psql -v ON_ERROR_STOP=1 -d NOMBRE_DE_LA_BASE `
  -f Backend/migrations/2026_add_capacitacion_minijuegos_extensibles.sql
```

El archivo abre `BEGIN`/`COMMIT`; un error debe dejar la transacción revertida.
Volver a ejecutar `verificar-diagnostico-minijuegos.sql`: las seis actividades,
sus IDs, intentos, progreso y XP deben coincidir con el snapshot; ahora deben
existir `orden`, `id_ruta_previa`, `configuracion`, la FK, el índice y el CHECK
de ocho tipos.

## 3. Seed en borrador

Solo después de validar la migración:

```powershell
psql -v ON_ERROR_STOP=1 -d NOMBRE_DE_LA_BASE `
  -f Backend/docs/capacitacion-minijuegos-seed.sql
```

Verificar que exista una ruta `orden=2`, `id_ruta_previa=1`, estado
`borrador`, fecha de publicación NULL y exactamente cuatro actividades en el
orden esperado. Repetir el seed: debe terminar correctamente sin duplicar ni
alterar contenido. La ruta 1 debe seguir teniendo 6 actividades y 65 XP.

## 4. Publicación posterior (requiere aprobación)

No publicar en este paso. Solo tras revisión editorial, ejecutar el bloque de
publicación documentado en `integracion-minijuegos-progreso.md`. Después,
probar con un usuario que no completó la ruta 1 (sucesora bloqueada) y otro que
sí la completó (sucesora disponible). Cada acierto nuevo debe otorgar XP una
sola vez mediante el endpoint autenticado.

## Reversión segura

Si solo se aplicó la migración y el seed no se ejecutó, detenerse y revisar el
`.down.sql`; no ejecutarlo automáticamente. Si existe o fue publicada la ruta
sucesora, no borrar actividades, intentos ni progreso: conservar datos y
corregir hacia delante o retirar únicamente la visibilidad de la ruta mediante
un procedimiento aprobado.
