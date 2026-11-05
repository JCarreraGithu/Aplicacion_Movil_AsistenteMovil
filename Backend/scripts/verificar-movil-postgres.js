// Solo clúster desechable local 55433; nunca lee .env para elegir destino.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {Pool} = require('pg');
const express = require('express');
const jwt = require('jsonwebtoken');
const raiz = path.resolve(__dirname,'../..');
const db = new Pool({host:'127.0.0.1',port:55433,user:'postgres',database:'postgres',password:'',ssl:false});
async function main() {
  assert.equal((await db.query("SELECT to_regnamespace('sistema_riego') AS s")).rows[0].s,null,'Requiere clúster vacío');
  await db.query('CREATE SCHEMA sistema_riego');
  await db.query(fs.readFileSync(path.join(raiz,'DB'),'utf8'));
  await db.query('ALTER TABLE sistema_riego.planta ADD COLUMN foto_url text');
  await db.query(fs.readFileSync(path.join(raiz,'Backend/migrations/2026_add_case_followup.sql'),'utf8'));
  await db.query(`SET search_path=sistema_riego,public;
    INSERT INTO usuario(nombre,apellido,correo,contrasena) VALUES ('Uno','Test','uno@test','fixture'),('Dos','Test','dos@test','fixture');
    INSERT INTO jardin(id_usuario,nombre) VALUES (1,'J1'),(2,'J2');
    INSERT INTO sector(id_jardin,nombre) VALUES (1,'A'),(2,'B');
    INSERT INTO planta(id_sector,nombre) VALUES (1,'Croto'),(2,'Rosa');
    INSERT INTO consulta_ia(id_usuario,pregunta,respuesta) VALUES (1,'Consulta antigua','Diagnostico histórico');
    INSERT INTO caso_planta(id_usuario,id_planta,id_consulta,titulo,diagnostico,plan_trabajo) VALUES(1,1,1,'Caso','Diagnostico','Plan');
    INSERT INTO seguimiento_caso(id_caso,nota,imagen_url) VALUES(1,'Evolucion','/foto.jpg');
    INSERT INTO caso_tarea(id_caso,descripcion) VALUES(1,'Observar');
    INSERT INTO recordatorio_caso(id_caso,id_tarea,mensaje,fecha_recordatorio) VALUES(1,1,'Revisar',now());
    INSERT INTO historial_planta(id_planta,observacion) VALUES(1,'Historial');
    INSERT INTO identificacion_planta(id_planta,nombre_identificado) VALUES(1,'Croto');`);
  const tablas=['usuario','jardin','sector','planta','consulta_ia','caso_planta','seguimiento_caso','caso_tarea','recordatorio_caso','historial_planta','identificacion_planta'];
  async function snapshot() {
    const result={};
    for(const t of tablas) result[t]=(await db.query(`SELECT to_jsonb(t)-'fecha_eliminacion' AS fila FROM sistema_riego.${t} t ORDER BY to_jsonb(t)::text`)).rows;
    return result;
  }
  const antes=await snapshot();
  const migraciones=['2026_add_conversacion_ia.sql','2026_add_planta_archivada.sql'];
  for(const m of migraciones) await db.query(fs.readFileSync(path.join(raiz,'Backend/migrations',m),'utf8'));
  assert.deepEqual(await snapshot(),antes);
  const catalogo=()=>db.query("SELECT oid,conname,pg_get_constraintdef(oid) AS def FROM pg_constraint WHERE conrelid IN ('sistema_riego.planta'::regclass,'sistema_riego.conversacion_ia'::regclass) ORDER BY oid");
  const constraints=(await catalogo()).rows;
  for(const m of migraciones) await db.query(fs.readFileSync(path.join(raiz,'Backend/migrations',m),'utf8'));
  assert.deepEqual((await catalogo()).rows,constraints);
  assert.deepEqual(await snapshot(),antes);
  console.log('PASS migraciones x2, OID/constraints intactos y datos anteriores idénticos');
  // Consulta de listado de la versión anterior: sigue válida tras ambos DDL.
  assert.equal((await db.query('SELECT id_planta,id_sector,nombre FROM sistema_riego.planta WHERE id_sector=1')).rowCount,1);
  await db.query(`CREATE ROLE mobile_app LOGIN; GRANT USAGE ON SCHEMA sistema_riego TO mobile_app;
    GRANT SELECT ON ALL TABLES IN SCHEMA sistema_riego TO mobile_app;
    GRANT INSERT,UPDATE ON sistema_riego.conversacion_ia TO mobile_app;
    GRANT UPDATE(fecha_eliminacion) ON sistema_riego.planta TO mobile_app;`);
  const appDb=new Pool({host:'127.0.0.1',port:55433,user:'mobile_app',database:'postgres',password:'',ssl:false,options:'-c search_path=sistema_riego,public'});
  const pool=require('../src/config/database');
  const original=pool.query;
  pool.query=appDb.query.bind(appDb);
  process.env.JWT_SECRET='solo-fixture-local';
  const app=express();app.use(express.json());
  app.use('/api/ia/conversaciones',require('../src/routes/conversacion.routes'));
  app.use('/api/plantas',require('../src/routes/planta.routes'));
  const server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  async function call(method,ruta,usuario,body) {
    const headers={'Content-Type':'application/json'};
    if(usuario) headers.Authorization='Bearer '+jwt.sign({id_usuario:usuario},process.env.JWT_SECRET);
    return fetch(`http://127.0.0.1:${server.address().port}${ruta}`,{method,headers,...(body?{body:JSON.stringify(body)}:{})});
  }
  try {
    assert.equal((await call('GET','/api/ia/conversaciones')).status,401);
    const c={titulo:'Croto',mensajes:[{tipo:'usuario',texto:'Avance'}],contexto:'Caso Croto',id_planta:1};
    assert.equal((await call('PUT','/api/ia/conversaciones/uno',1,c)).status,200);
    assert.equal((await call('PUT','/api/ia/conversaciones/ajena',2,c)).status,404);
    assert.deepEqual(await (await call('GET','/api/ia/conversaciones',2)).json(),[]);
    assert.equal((await call('DELETE','/api/ia/conversaciones/uno',2)).status,404);
    // El mismo id con otro usuario representa otra conversación independiente.
    assert.equal((await call('PUT','/api/ia/conversaciones/uno',2,{...c,id_planta:null,titulo:'Otra'})).status,200);
    const propias=await (await call('GET','/api/ia/conversaciones',1)).json();
    assert.equal(propias[0].titulo,'Croto');
    assert.equal((await call('DELETE','/api/plantas/1/plantas/1',2)).status,404);
    assert.equal((await call('DELETE','/api/plantas/2/plantas/1',1)).status,404);
    assert.equal((await call('DELETE','/api/plantas/1/plantas/1',1)).status,200);
    assert.deepEqual(await snapshot(),antes,'archivar debe conservar todos los históricos');
    assert.equal((await (await call('GET','/api/plantas/1/plantas',1)).json()).length,0);
    assert.equal((await call('GET','/api/plantas/1/plantas/1',1)).status,200);
    assert.equal((await call('DELETE','/api/ia/conversaciones/uno',1)).status,200);
    assert.equal((await call('PUT','/api/ia/conversaciones/uno',1,c)).status,404);
    assert.equal((await db.query('SELECT count(*)::int n FROM sistema_riego.consulta_ia')).rows[0].n,1);
    console.log('PASS HTTP/JWT/rol limitado: aislamiento, renombrado, borrado lógico, no resurrección e historial de plantas conservado');
  } finally {
    await new Promise(resolve=>server.close(resolve));pool.query=original;
    await appDb.end();await pool.end();
  }
}
main().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>db.end());
