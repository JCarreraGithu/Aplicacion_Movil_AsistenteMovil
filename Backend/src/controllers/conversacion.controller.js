const service = require('../services/conversacion.service').crearServicio();
const idValido = id => typeof id === 'string' && /^[a-zA-Z0-9:_-]{1,100}$/.test(id);
const cuerpoValido = c => c && typeof c.titulo === 'string' && c.titulo.trim().length > 0 && c.titulo.length <= 200 &&
  (c.contexto == null || typeof c.contexto === 'string') &&
  (c.id_planta == null || Number.isSafeInteger(c.id_planta) && c.id_planta > 0) &&
  Array.isArray(c.mensajes) && c.mensajes.length > 0 && c.mensajes.length <= 1000 &&
  c.mensajes.every(m => m && ['usuario','asistente'].includes(m.tipo) && typeof m.texto === 'string');
const manejar = fn => async (req,res) => {
  try { await fn(req,res); } catch (e) {
    console.error('Conversaciones:',e);
    res.status(e.code === '42P01' ? 503 : 500).json({mensaje:e.code === '42P01' ? 'Conversaciones pendientes de migración' : 'No se pudo guardar o recuperar la conversación'});
  }
};
exports.listar = manejar(async (req,res) => res.json(await service.listar(req.usuario.id_usuario)));
exports.guardar = manejar(async (req,res) => {
  if (!idValido(req.params.id) || !cuerpoValido(req.body)) return res.status(400).json({mensaje:'Conversación inválida'});
  const result = await service.guardar(req.usuario.id_usuario,req.params.id,req.body);
  res.status(result ? 200 : 404).json(result ?? {mensaje:'Conversación o planta no disponible'});
});
exports.eliminar = manejar(async (req,res) => {
  if (!idValido(req.params.id)) return res.status(400).json({mensaje:'Identificador inválido'});
  const result = await service.eliminar(req.usuario.id_usuario,req.params.id);
  res.status(result ? 200 : 404).json(result ?? {mensaje:'Conversación no encontrada'});
});
exports.cuerpoValido = cuerpoValido;
