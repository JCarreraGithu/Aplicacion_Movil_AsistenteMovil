import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lectura_sensor_service.dart';

class RiegoService {
  static const _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> obtenerResumenPorSector({
    required String token,
    required int idSector,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${LecturaSensorService.baseUrl}/api/riegos/sector/$idSector/resumen',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      throw const FormatException('La respuesta del resumen no es válida.');
    }
    throw Exception('No se pudo cargar el resumen de riego.');
  }

  static Future<List<dynamic>> obtenerRiegosPorIntervalo({
    required String token,
    required int idSector,
    required int dias,
    String periodo = 'actual',
  }) async {
    if (![7, 15, 30].contains(dias)) {
      throw ArgumentError.value(dias, 'dias', 'Debe ser 7, 15 o 30');
    }
    final uri = Uri.parse(
      '${LecturaSensorService.baseUrl}/api/riegos/sector/$idSector',
    ).replace(queryParameters: {'dias': '$dias', 'periodo': periodo});
    final response = await http
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      throw const FormatException('La respuesta de consumo no es una lista.');
    }
    throw Exception('No se pudo cargar el consumo de agua: ${response.body}');
  }
}
