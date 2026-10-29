/// Serializa el registro vigente de un caso para consultarlo con la IA.
/// Los campos ausentes se indican como no registrados; nunca se completan
/// con inferencias. El diagnóstico y la bitácora se conservan como historial.
String construirContextoCaso(
  Map<String, dynamic> caso, {
  int? seguimientoConFotoIncluida,
  int? recordatorioEnEvaluacionId,
  int? tareaEnEvaluacionId,
}) {
  String valor(Object? value) =>
      value == null || value.toString().trim().isEmpty
      ? 'No registrado'
      : value.toString().trim();

  final seguimientosRaw = (caso['seguimientos'] as List<dynamic>? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final seguimientos = seguimientosRaw.map((item) {
    var notaImagen = '';
    if (item['imagen_url'] != null) {
      final esFotoActual = seguimientoConFotoIncluida != null &&
          item['id_seguimiento']?.toString() ==
              seguimientoConFotoIncluida.toString();
      notaImagen = esFotoActual
          ? ' [La fotografía adjunta de esta observación se envía para análisis visual en esta consulta]'
          : ' [Hay una fotografía histórica adjunta; su contenido visual no se incluye en esta consulta]';
    }
    return '- ${valor(item['fecha'])}: ${valor(item['nota'])}$notaImagen';
  }).join('\n');
  String? resultadoFinal;
  for (final item in seguimientosRaw.reversed) {
    final nota = item['nota']?.toString() ?? '';
    const prefijo = 'Resultado final:';
    if (nota.startsWith(prefijo)) {
      resultadoFinal = nota.substring(prefijo.length).trim();
      break;
    }
  }
  final tareas = (caso['tareas'] as List<dynamic>? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .map((item) =>
          '- [${item['completada'] == true ? 'Completada' : 'Pendiente'}] '
          '${valor(item['descripcion'])}; fecha límite: ${valor(item['fecha_limite'])}')
      .join('\n');
  final recordatorios = (caso['recordatorios'] as List<dynamic>? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .map((item) =>
          '- ${valor(item['mensaje'])}; fecha: ${valor(item['fecha_recordatorio'])}; '
          '${item['activo'] == true ? 'activo' : 'inactivo'}')
      .join('\n');
  Map<String, dynamic>? recordatorioEvaluado;
  if (recordatorioEnEvaluacionId != null) {
    for (final item in caso['recordatorios'] as List<dynamic>? ?? []) {
      if (item is Map &&
          item['id_recordatorio']?.toString() ==
              recordatorioEnEvaluacionId.toString()) {
        recordatorioEvaluado = Map<String, dynamic>.from(item);
        break;
      }
    }
  }
  Map<String, dynamic>? tareaEvaluada;
  if (tareaEnEvaluacionId != null) {
    for (final item in caso['tareas'] as List<dynamic>? ?? []) {
      if (item is Map &&
          item['id_tarea']?.toString() == tareaEnEvaluacionId.toString()) {
        tareaEvaluada = Map<String, dynamic>.from(item);
        break;
      }
    }
  }
  final seguimientoEvaluado = recordatorioEvaluado != null
      ? '- ${valor(recordatorioEvaluado['mensaje'])}; paso: '
          '${valor(recordatorioEvaluado['tarea_descripcion'])}; fecha programada: '
          '${valor(recordatorioEvaluado['fecha_recordatorio'])}'
      : tareaEvaluada != null
          ? '- Paso: ${valor(tareaEvaluada['descripcion'])}; estado: '
              '${tareaEvaluada['completada'] == true ? 'completado' : 'pendiente'}; '
              'fecha programada: ${valor(tareaEvaluada['fecha_limite'])}'
          : 'No aplica.';

  return '''ID del caso: ${valor(caso['id_caso'])}
Título: ${valor(caso['titulo'])}
Planta registrada: ${valor(caso['nombre_planta'])}
Especie registrada (nombre común): ${valor(caso['especie_nombre_comun'])}
Especie registrada (nombre científico): ${valor(caso['especie_nombre_cientifico'])}
Jardín: ${valor(caso['nombre_jardin'])}
Sector: ${valor(caso['nombre_sector'])}
Estado actual: ${valor(caso['estado'])}
Diagnóstico inicial guardado (histórico): ${valor(caso['diagnostico'])}
Plan de tratamiento guardado: ${valor(caso['plan_trabajo'])}
Tareas:
${tareas.isEmpty ? 'No hay tareas registradas.' : tareas}
Recordatorios:
${recordatorios.isEmpty ? 'No hay recordatorios registrados.' : recordatorios}
Seguimiento programado en evaluación:
$seguimientoEvaluado
Bitácora cronológica:
${seguimientos.isEmpty ? 'No hay notas de evolución registradas.' : seguimientos}
Resultado final registrado: ${resultadoFinal ?? 'No hay resultado final registrado.'}''';
}
