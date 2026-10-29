import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lectura_sensor_service.dart';

class DispositivoService {
  static Future<List<dynamic>> obtenerPorSector({
    required String token,
    required int idSector,
  }) async {
    final uri = Uri.parse(
      '${LecturaSensorService.baseUrl}/api/dispositivos',
    ).replace(queryParameters: {'id_sector': '$idSector'});
    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode != 200) {
      throw Exception('No se pudo consultar el contacto del dispositivo.');
    }
    final data = jsonDecode(response.body);
    if (data is! List) {
      throw const FormatException('La respuesta de dispositivos no es válida.');
    }
    return data;
  }
}
