import 'package:flutter_test/flutter_test.dart';
import 'package:systema_riego_app/services/caso_contexto.dart';
import 'package:systema_riego_app/services/recordatorio_caso.dart';

void main() {
  final ahora = DateTime(2026, 10, 12, 10);

  test('clasifica recordatorios vencidos, de hoy, próximos y futuros', () {
    expect(
      RecordatorioCasoHelper.estadoFecha(ahora.subtract(const Duration(days: 1)), ahora: ahora),
      EstadoFechaRecordatorio.vencido,
    );
    expect(
      RecordatorioCasoHelper.estadoFecha(ahora.add(const Duration(hours: 2)), ahora: ahora),
      EstadoFechaRecordatorio.hoy,
    );
    expect(
      RecordatorioCasoHelper.estadoFecha(ahora.add(const Duration(days: 1)), ahora: ahora),
      EstadoFechaRecordatorio.proximo,
    );
    expect(
      RecordatorioCasoHelper.estadoFecha(ahora.add(const Duration(days: 2)), ahora: ahora),
      EstadoFechaRecordatorio.futuro,
    );
  });

  test('aviso usa nombre real de planta, paso y fecha sin crear avisos futuros', () {
    final mensaje = RecordatorioCasoHelper.mensaje(
      planta: 'Mi Croto',
      paso: 'Revisar manchas en las hojas',
      fecha: ahora,
      ahora: ahora,
    );
    expect(mensaje, contains('Mi Croto'));
    expect(mensaje, contains('Revisar manchas en las hojas'));
    expect(mensaje, contains('Hoy corresponde revisar'));
    expect(
      RecordatorioCasoHelper.requiereAviso(
        ahora.add(const Duration(days: 2)),
        ahora: ahora,
      ),
      isFalse,
    );
  });

  test('el listado de recordatorios no duplica ids y conserva datos reales', () {
    final items = RecordatorioCasoHelper.unicosPorId([
      {'id_recordatorio': 4, 'mensaje': 'Revisar croto'},
      {'id_recordatorio': 4, 'mensaje': 'Duplicado'},
      {'id_recordatorio': 5, 'mensaje': 'Revisar humedad'},
    ]);
    expect(items, hasLength(2));
    expect(items.first['mensaje'], 'Revisar croto');
  });

  test('el contexto de IA incluye paso y fecha del seguimiento evaluado', () {
    final contexto = construirContextoCaso(
      {
        'nombre_planta': 'Mi Croto',
        'especie_nombre_comun': 'Croto',
        'diagnostico': 'Diagnóstico histórico',
        'tareas': [
          {'id_tarea': 12, 'descripcion': 'Revisar manchas', 'completada': false},
        ],
        'recordatorios': [
          {
            'id_recordatorio': 8,
            'id_tarea': 12,
            'mensaje': 'Revisar evolución',
            'tarea_descripcion': 'Revisar manchas',
            'fecha_recordatorio': '2026-10-12T10:00:00.000Z',
            'activo': true,
          },
        ],
        'seguimientos': [
          {'fecha': '2026-10-12', 'nota': 'Las hojas mejoraron'},
        ],
      },
      recordatorioEnEvaluacionId: 8,
    );
    expect(contexto, contains('Mi Croto'));
    expect(contexto, contains('Diagnóstico histórico'));
    expect(contexto, contains('Revisar manchas'));
    expect(contexto, contains('2026-10-12T10:00:00.000Z'));
    expect(contexto, contains('Las hojas mejoraron'));
  });

  test('el contexto reconoce una tarea programada aunque no tenga recordatorio', () {
    final contexto = construirContextoCaso(
      {
        'tareas': [
          {
            'id_tarea': 21,
            'descripcion': 'Revisar humedad del sustrato',
            'fecha_limite': '2026-10-13T09:00:00.000Z',
            'completada': false,
          },
        ],
      },
      tareaEnEvaluacionId: 21,
    );
    expect(contexto, contains('Revisar humedad del sustrato'));
    expect(contexto, contains('2026-10-13T09:00:00.000Z'));
    expect(contexto, contains('estado: pendiente'));
  });
}
