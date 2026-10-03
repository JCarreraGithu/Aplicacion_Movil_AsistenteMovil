import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jardin_service.dart';

class ActuadorConfiguracionService {
  static String get _baseUrl => JardinService.baseUrl;
  static const _timeout = Duration(seconds: 10);

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<dynamic>> obtenerActuadores({
    required String token,
    required int idSector,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/actuadores/sector/$idSector'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('No se pudieron obtener los actuadores (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    if (data is! List) throw const FormatException('Respuesta de actuadores inválida.');
    return data;
  }

  static Future<Map<String, dynamic>?> obtenerConfiguracion({
    required String token,
    required int idSector,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/sectores/$idSector/configuracion'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('No se pudo obtener la configuración (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic> ? data : null;
  }

  static Future<Map<String, dynamic>> actualizarEstado({
    required String token,
    required int idActuador,
    required bool encendido,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/api/actuadores/$idActuador/estado'),
          headers: _headers(token),
          body: jsonEncode({'estado': encendido ? 'encendido' : 'apagado'}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      var mensaje = 'No se pudo actualizar el actuador (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['mensaje'] is String) mensaje = body['mensaje'] as String;
      } on FormatException {
        // Mantiene el mensaje genérico cuando el servidor no devuelve JSON.
      }
      throw Exception(mensaje);
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) throw const FormatException('Respuesta de actuador inválida.');
    return data;
  }
}
