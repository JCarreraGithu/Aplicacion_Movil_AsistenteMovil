const pool = require('../config/database');
const crearServicio = (db = pool) => ({
  listar: async usuario => (await db.query(`SELECT id,titulo,mensajes,contexto,id_planta,actualizada FROM sistema_riego.conversacion_ia WHERE id_usuario=$1 AND eliminada IS NULL ORDER BY actualizada DESC`, [usuario])).rows,
  guardar: async (usuario, id, c) => {
    if (c.id_planta != null) {
      const planta = await db.query(`SELECT p.id_planta FROM sistema_riego.planta p JOIN sistema_riego.sector s ON s.id_sector=p.id_sector JOIN sistema_riego.jardin j ON j.id_jardin=s.id_jardin WHERE p.id_planta=$1 AND j.id_usuario=$2`, [c.id_planta, usuario]);
      if (!planta.rows.length) return null;
    }
    return (await db.query(`INSERT INTO sistema_riego.conversacion_ia(id_usuario,id,titulo,mensajes,contexto,id_planta) VALUES($1,$2,$3,$4,$5,$6)
      ON CONFLICT(id_usuario,id) DO UPDATE SET titulo=EXCLUDED.titulo,mensajes=EXCLUDED.mensajes,contexto=EXCLUDED.contexto,id_planta=EXCLUDED.id_planta,actualizada=NOW()
      WHERE conversacion_ia.eliminada IS NULL RETURNING id`, [usuario,id,c.titulo,JSON.stringify(c.mensajes),c.contexto ?? null,c.id_planta ?? null])).rows[0] ?? null;
  },
  eliminar: async (usuario,id) => (await db.query(`UPDATE sistema_riego.conversacion_ia SET eliminada=NOW() WHERE id_usuario=$1 AND id=$2 AND eliminada IS NULL RETURNING id`, [usuario,id])).rows[0] ?? null,
});
module.exports = {crearServicio};
