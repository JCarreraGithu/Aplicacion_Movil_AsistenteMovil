-- SOLO LECTURA. Ejecutar antes y después del diagnóstico, en la MISMA rama
-- de pruebas y sin escrituras concurrentes; guardar y comparar resultados.
SELECT CURRENT_DATABASE() AS base, CURRENT_USER AS rol_actual,
       SESSION_USER AS rol_sesion, CURRENT_SETTING('server_version') AS version;

SELECT c.oid::REGCLASS AS tabla, pg_get_userbyid(c.relowner) AS propietario,
       pg_has_role(CURRENT_USER, c.relowner, 'USAGE') AS hereda_rol_propietario
FROM pg_class c
WHERE c.oid IN ('sistema_riego.capacitacion_ruta'::REGCLASS,
               'sistema_riego.capacitacion_actividad'::REGCLASS)
ORDER BY c.oid::REGCLASS::TEXT;

SELECT 'rutas' AS tabla, COUNT(*) AS filas,
       MD5(COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY TO_JSONB(t)::TEXT)::TEXT, '[]')) AS hash_datos
FROM sistema_riego.capacitacion_ruta t
UNION ALL
SELECT 'actividades', COUNT(*),
       MD5(COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY TO_JSONB(t)::TEXT)::TEXT, '[]'))
FROM sistema_riego.capacitacion_actividad t
UNION ALL
SELECT 'intentos', COUNT(*),
       MD5(COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY TO_JSONB(t)::TEXT)::TEXT, '[]'))
FROM sistema_riego.capacitacion_actividad_intento t
UNION ALL
SELECT 'progreso', COUNT(*),
       MD5(COALESCE(JSONB_AGG(TO_JSONB(t) ORDER BY TO_JSONB(t)::TEXT)::TEXT, '[]'))
FROM sistema_riego.capacitacion_actividad_progreso t;

-- Debe devolver 0 con la base inicial confirmada.
SELECT COUNT(*) AS columnas_nuevas
FROM pg_attribute a
WHERE NOT a.attisdropped AND a.attnum > 0 AND (
    (a.attrelid = 'sistema_riego.capacitacion_ruta'::REGCLASS
     AND a.attname IN ('orden', 'id_ruta_previa'))
    OR (a.attrelid = 'sistema_riego.capacitacion_actividad'::REGCLASS
        AND a.attname = 'configuracion')
);

SELECT id_ruta, ARRAY_AGG(id_actividad ORDER BY orden) AS ids_actividad,
       SUM(xp) AS xp_disponible
FROM sistema_riego.capacitacion_actividad
GROUP BY id_ruta ORDER BY id_ruta;

SELECT c.conrelid::REGCLASS AS tabla, c.oid AS oid_constraint, c.conname,
       c.convalidated, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
WHERE c.conrelid IN ('sistema_riego.capacitacion_ruta'::REGCLASS,
                    'sistema_riego.capacitacion_actividad'::REGCLASS)
ORDER BY c.conrelid, c.conname;

SELECT i.indexrelid AS oid_indice, pg_get_indexdef(i.indexrelid) AS definicion
FROM pg_index i
WHERE i.indrelid IN ('sistema_riego.capacitacion_ruta'::REGCLASS,
                    'sistema_riego.capacitacion_actividad'::REGCLASS)
ORDER BY i.indexrelid;

SELECT t.oid AS oid_trigger, t.tgrelid::REGCLASS AS tabla, t.tgenabled,
       pg_get_triggerdef(t.oid) AS definicion
FROM pg_trigger t
WHERE NOT t.tgisinternal
  AND t.tgrelid IN ('sistema_riego.capacitacion_ruta'::REGCLASS,
                   'sistema_riego.capacitacion_actividad'::REGCLASS)
ORDER BY t.tgrelid, t.tgname;

SELECT MD5(pg_get_functiondef(
    'sistema_riego.proteger_capacitacion_ruta_publicada()'::REGPROCEDURE
)) AS hash_funcion_proteccion;
