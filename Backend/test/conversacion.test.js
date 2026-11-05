const test = require('node:test');
const assert = require('node:assert/strict');
const {crearServicio} = require('../src/services/conversacion.service');
const {cuerpoValido} = require('../src/controllers/conversacion.controller');
test('rechaza conversación vacía, roles y plantas inválidas', () => {
  assert.equal(cuerpoValido({titulo:'Hola',mensajes:[]}),false);
  assert.equal(cuerpoValido({titulo:'Hola',mensajes:[{tipo:'system',texto:'x'}]}),false);
  assert.equal(cuerpoValido({titulo:'Hola',mensajes:[{tipo:'usuario',texto:'x'}],id_planta:-1}),false);
  assert.equal(cuerpoValido({titulo:'Hola',mensajes:[{tipo:'usuario',texto:'x'}],contexto:'Caso 7'}),true);
});
test('listar y eliminar se limitan al propietario; eliminación lógica conserva mensajes', async () => {
  const llamadas = [];
  const service = crearServicio({query: async (sql,p) => { llamadas.push([sql,p]); return {rows:[]}; }});
  assert.deepEqual(await service.listar(7),[]);
  assert.equal(await service.eliminar(7,'otro'),null);
  assert.match(llamadas[0][0],/id_usuario=\$1/);
  assert.deepEqual(llamadas[1][1],[7,'otro']);
  assert.doesNotMatch(llamadas[1][0],/DELETE FROM|TRUNCATE/);
});
test('guardar no permite asociar una planta ajena y conserva contexto del caso', async () => {
  const service = crearServicio({query: async (sql,p) => { assert.match(sql,/j.id_usuario=\$2/); assert.deepEqual(p,[5,7]); return {rows:[]}; }});
  assert.equal(await service.guardar(7,'c',{id_planta:5}),null);
  const propio = crearServicio({query:async(sql,p) => {
    assert.match(sql,/ON CONFLICT\(id_usuario,id\)/);
    assert.match(sql,/eliminada IS NULL/);
    assert.equal(p[4],'Caso Croto');
    return {rows:[{id:'c'}]};
  }});
  assert.deepEqual(await propio.guardar(7,'c',{titulo:'Hola',mensajes:[{tipo:'usuario',texto:'Avance'}],contexto:'Caso Croto'}),{id:'c'});
});
