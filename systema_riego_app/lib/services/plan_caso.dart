/// Convierte las líneas confirmadas por el usuario en pasos persistibles.
/// Solo crea fecha límite y recordatorio cuando la línea declara un plazo
/// relativo explícito; nunca inventa tiempos para casos históricos.
List<Map<String, dynamic>> prepararPasosCaso(
  String plan, {
  DateTime? referencia,
}) {
  final ahora = referencia ?? DateTime.now();
  final pasos = <Map<String, dynamic>>[];
  final vistos = <String>{};
  final regexPlazo = RegExp(
    r'\b(?:en|dentro de|a los)\s+(\d+)\s+d[ií]as?\b',
    caseSensitive: false,
  );

  for (final linea in plan.split(RegExp(r'\r?\n'))) {
    var descripcion = linea
        .replaceFirst(RegExp(r'^\s*(?:[-*•]+|\d+[.)])\s*'), '')
        .trim();
    if (descripcion.length < 3 ||
        RegExp(
          r'^(?:sin pasos de tratamiento registrados|no se requiere ningún plan)',
          caseSensitive: false,
        ).hasMatch(descripcion)) {
      continue;
    }

    final plazo = regexPlazo.firstMatch(descripcion);
    final dias = plazo == null ? null : int.tryParse(plazo.group(1)!);
    final fecha = dias != null && dias > 0 && dias <= 365
        ? ahora.add(Duration(days: dias)).toUtc().toIso8601String()
        : null;
    final clave = '${descripcion.toLowerCase()}|${fecha ?? ''}';
    if (!vistos.add(clave)) continue;

    pasos.add({
      'descripcion': descripcion,
      if (fecha != null) 'fecha_limite': fecha,
      if (fecha != null) 'recordatorio_fecha': fecha,
      if (fecha != null) 'recordatorio_mensaje': 'Seguimiento: $descripcion',
    });
  }
  return pasos;
}
