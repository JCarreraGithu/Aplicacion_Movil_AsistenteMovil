enum EstadoFechaRecordatorio { vencido, hoy, proximo, futuro }

class RecordatorioCasoHelper {
  static EstadoFechaRecordatorio estadoFecha(
    DateTime fecha, {
    DateTime? ahora,
  }) {
    final actual = ahora ?? DateTime.now();
    if (fecha.isBefore(actual)) {
      if (fecha.year == actual.year &&
          fecha.month == actual.month &&
          fecha.day == actual.day) {
        return EstadoFechaRecordatorio.hoy;
      }
      return EstadoFechaRecordatorio.vencido;
    }
    if (fecha.year == actual.year &&
        fecha.month == actual.month &&
        fecha.day == actual.day) {
      return EstadoFechaRecordatorio.hoy;
    }
    if (fecha.difference(actual) <= const Duration(hours: 24)) {
      return EstadoFechaRecordatorio.proximo;
    }
    return EstadoFechaRecordatorio.futuro;
  }

  static bool requiereAviso(
    DateTime fecha, {
    DateTime? ahora,
  }) =>
      estadoFecha(fecha, ahora: ahora) != EstadoFechaRecordatorio.futuro;

  static String mensaje({
    required String planta,
    required String paso,
    required DateTime fecha,
    DateTime? ahora,
  }) {
    final estado = estadoFecha(fecha, ahora: ahora);
    final pregunta = '¿Cómo ha respondido $planta al tratamiento?';
    final tarea = paso.trim().isEmpty ? '' : ' Paso: ${paso.trim()}.';
    return switch (estado) {
      EstadoFechaRecordatorio.vencido =>
        'El seguimiento de $planta está pendiente.$tarea $pregunta',
      EstadoFechaRecordatorio.hoy => 'Hoy corresponde revisar la evolución de '
          '$planta.$tarea $pregunta',
      EstadoFechaRecordatorio.proximo => 'Próximo seguimiento de $planta.$tarea '
          '$pregunta',
      EstadoFechaRecordatorio.futuro => 'Seguimiento programado de $planta.$tarea',
    };
  }

  static List<Map<String, dynamic>> unicosPorId(
    Iterable<Map<String, dynamic>> recordatorios,
  ) {
    final ids = <String>{};
    return recordatorios.where((recordatorio) {
      final id = recordatorio['id_recordatorio']?.toString();
      return id != null && id.isNotEmpty && ids.add(id);
    }).toList();
  }
}
