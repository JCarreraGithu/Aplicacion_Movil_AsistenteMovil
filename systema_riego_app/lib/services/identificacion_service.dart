import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class IdentificacionService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  // ============================================================
  // IDENTIFICAR PLANTA
  // ============================================================

  static Future<Map<String, dynamic>> identificarPlanta({
    required File imagen,
    required String token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/identificacion/identificar'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath(
        'imagen',
        imagen.path,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al identificar planta: ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  // ============================================================
  // REGISTRAR PLANTA
  // ============================================================

  static Future<Map<String, dynamic>> registrarPlanta({
    required String token,
    required int idSector,
    required String nombre,
    required String nombreCientifico,
    String? descripcion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/identificacion/registrar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'idSector': idSector,
        'nombre': nombre,
        'nombreCientifico': nombreCientifico,
        'descripcion': descripcion,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Error al registrar planta: ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }
}