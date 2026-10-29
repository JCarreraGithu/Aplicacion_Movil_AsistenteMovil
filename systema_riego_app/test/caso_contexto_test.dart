import 'package:flutter_test/flutter_test.dart';
import 'package:systema_riego_app/services/caso_contexto.dart';

void main() {
  test('mantiene la planta del caso y su historial sin mezclar otro caso', () {
    final contexto = construirContextoCaso({
      'id_caso': 41,
      'titulo': 'Recuperación: Mi Croto',
      'nombre_planta': 'Mi Croto',
      'especie_nombre_comun': 'Croto',
      'especie_nombre_cientifico': 'Codiaeum variegatum',
      'nombre_sector': 'Sector B',
      'estado': 'en_progreso',
      'diagnostico': 'Histórico: menciona una rosa.',
      'plan_trabajo': 'Revisar el drenaje.',
      'seguimientos': [
        {'id_seguimiento': 1, 'fecha': '2026-10-10', 'nota': 'Las hojas nuevas están verdes.', 'imagen_url': '/uploads/historica.jpg'},
        {'fecha': '2026-10-12', 'nota': 'Resultado final: Hojas recuperadas.'},
      ],
      'tareas': [
        {'descripcion': 'Revisar humedad', 'completada': false},
      ],
      'recordatorios': [
        {'mensaje': 'Revisión semanal', 'fecha_recordatorio': '2026-10-13', 'activo': true},
      ],
    });

    expect(contexto, contains('ID del caso: 41'));
    expect(contexto, contains('Planta registrada: Mi Croto'));
    expect(contexto, contains('Codiaeum variegatum'));
    expect(contexto, contains('menciona una rosa'));
    expect(contexto, contains('Las hojas nuevas están verdes'));
    expect(contexto, contains('fotografía histórica adjunta'));
    expect(contexto, contains('Resultado final registrado: Hojas recuperadas.'));
    expect(contexto, contains('Revisar humedad'));
    expect(contexto, contains('Revisión semanal'));
    expect(contexto, contains('Diagnóstico inicial guardado (histórico)'));
  });

  test('el contexto identifica una fotografía actual que sí se envía a la IA', () {
    final contexto = construirContextoCaso(
      {
        'seguimientos': [
          {'id_seguimiento': 7, 'fecha': '2026-10-12', 'nota': 'Nueva mancha', 'imagen_url': '/uploads/nueva.jpg'},
        ],
      },
      seguimientoConFotoIncluida: 7,
    );

    expect(contexto, contains('se envía para análisis visual'));
  });

  test('marca como no registrado lo que no existe y conserva bitácora vacía', () {
    final contexto = construirContextoCaso({'id_caso': 9});

    expect(contexto, contains('Planta registrada: No registrado'));
    expect(contexto, contains('Especie registrada (nombre común): No registrado'));
    expect(contexto, contains('No hay notas de evolución registradas.'));
    expect(contexto, contains('No hay tareas registradas.'));
    expect(contexto, contains('No hay recordatorios registrados.'));
  });
}
