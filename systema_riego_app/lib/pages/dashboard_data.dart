class SectorDashboardOption {
  final int id;
  final int idJardin;
  final String nombre;
  final String nombreJardin;

  const SectorDashboardOption({
    required this.id,
    required this.idJardin,
    required this.nombre,
    required this.nombreJardin,
  });

  String get etiqueta => '$nombreJardin · $nombre';
}

const ventanaLecturaReciente = Duration(minutes: 5);

enum EstadoLectura { reciente, antigua, sinLectura, fechaInvalida }

class SensorReadingSnapshot {
  final Map sensor;
  final Map? lectura;
  final DateTime? fechaLectura;

  const SensorReadingSnapshot({
    required this.sensor,
    required this.lectura,
    required this.fechaLectura,
  });

  EstadoLectura estadoEn(DateTime ahora) => clasificarLectura(
        fechaLectura,
        existeLectura: lectura != null,
        ahora: ahora,
      );

  EstadoLectura get estadoLectura => estadoEn(DateTime.now());

  String get tipo => '${sensor['tipo_sensor'] ?? 'Sensor'}';
  String get codigo => '${sensor['codigo'] ?? 'Sin código'}';
}

EstadoLectura clasificarLectura(
  DateTime? fecha, {
  required bool existeLectura,
  DateTime? ahora,
  Duration vigencia = ventanaLecturaReciente,
}) {
  if (!existeLectura) return EstadoLectura.sinLectura;
  if (fecha == null) return EstadoLectura.fechaInvalida;
  final referencia = ahora ?? DateTime.now();
  if (fecha.isAfter(referencia)) return EstadoLectura.fechaInvalida;
  if (referencia.difference(fecha) > vigencia) {
    return EstadoLectura.antigua;
  }
  return EstadoLectura.reciente;
}

List<SensorReadingSnapshot> combinarLecturasSensores(
  List<dynamic> sensores,
  List<dynamic> lecturas,
) {
  final porSensor = <int, Map>{};
  for (final item in lecturas) {
    if (item is! Map) continue;
    final id = int.tryParse('${item['id_sensor']}');
    if (id != null) porSensor[id] = item;
  }
  return sensores.whereType<Map>().map((sensor) {
    final id = int.tryParse('${sensor['id_sensor']}');
    final lectura = id == null ? null : porSensor[id];
    final fecha = DateTime.tryParse('${lectura?['fecha_hora']}');
    return SensorReadingSnapshot(
      sensor: sensor,
      lectura: lectura,
      fechaLectura: fecha,
    );
  }).toList();
}

SensorReadingSnapshot? lecturaRecientePorTipo(
  List<SensorReadingSnapshot> sensores,
  String tipo, {
  DateTime? ahora,
}) {
  final coincidencias = sensores.where((item) =>
      item.tipo.toLowerCase() == tipo.toLowerCase() &&
      clasificarLectura(
            item.fechaLectura,
            existeLectura: item.lectura != null,
            ahora: ahora,
          ) ==
          EstadoLectura.reciente);
  if (coincidencias.isEmpty) return null;
  return coincidencias.reduce((a, b) => a.fechaLectura!.isAfter(b.fechaLectura!) ? a : b);
}

List<SectorDashboardOption> combinarSectores(
  List<dynamic> jardines,
  Map<int, List<dynamic>> sectoresPorJardin,
) {
  final opciones = <SectorDashboardOption>[];
  for (final jardin in jardines) {
    if (jardin is! Map) continue;
    final idJardin = int.tryParse('${jardin['id_jardin']}');
    if (idJardin == null) continue;
    final nombreJardin = '${jardin['nombre'] ?? 'Jardín'}';
    for (final sector in sectoresPorJardin[idJardin] ?? const []) {
      if (sector is! Map) continue;
      final idSector = int.tryParse('${sector['id_sector']}');
      if (idSector == null) continue;
      opciones.add(SectorDashboardOption(
        id: idSector,
        idJardin: idJardin,
        nombre: '${sector['nombre'] ?? 'Sector'}',
        nombreJardin: nombreJardin,
      ));
    }
  }
  return opciones;
}

int? elegirSectorInicial(List<SectorDashboardOption> opciones, int? preferido) {
  if (opciones.any((sector) => sector.id == preferido)) return preferido;
  return opciones.isEmpty ? null : opciones.first.id;
}

double? cantidadAgua(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  final parsed = double.tryParse(text);
  return parsed != null && parsed.isFinite ? parsed : null;
}

double consumoConocido(List<dynamic> rows) => rows.fold<double>(
      0,
      (total, row) => total + (row is Map ? cantidadAgua(row['cantidad_agua']) ?? 0 : 0),
    );

int cantidadesDesconocidas(List<dynamic> rows) => rows.where((row) {
      return row is Map && cantidadAgua(row['cantidad_agua']) == null;
    }).length;

Map<String, double> agruparConsumoPorDia(List<dynamic> rows) {
  final agrupado = <String, double>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final fecha = DateTime.tryParse('${row['fecha_hora']}')?.toLocal();
    final cantidad = cantidadAgua(row['cantidad_agua']);
    if (fecha == null || cantidad == null) continue;
    final key = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    agrupado[key] = (agrupado[key] ?? 0) + cantidad;
  }
  return agrupado;
}
