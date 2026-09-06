import 'dart:convert';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;

class IaService {
  static const String baseUrl =
      'http://10.0.2.2:3000';

  // ============================================================
  // CONSULTAR GEMINI
  // ============================================================

  static Future<Map<String, dynamic>> consultarIA({
    required String pregunta,
    required String token,
  }) async {

    final response = await http.post(
      Uri.parse(
        '$baseUrl/api/ia/consultas',
      ),

      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },

      body: jsonEncode({
        'pregunta': pregunta,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(
        response.body,
      );
    }

    throw Exception(
      'Error al consultar IA: '
          '${response.body}',
    );
  }

  // ============================================================
  // ANALIZAR PLANTA CON FOTOGRAFÍA
  // ============================================================

  static Future<Map<String, dynamic>> analizarPlanta({
    required Uint8List imagen,
    required String nombreArchivo,
    required String token,
    String pregunta = '',
  }) async {

    final uri = Uri.parse(
      '$baseUrl/api/ia/analizar-planta',
    );

    final request =
    http.MultipartRequest(
      'POST',
      uri,
    );

    // ==========================================================
    // TOKEN
    // ==========================================================

    request.headers[
    'Authorization'] =
    'Bearer $token';

    // ==========================================================
    // PREGUNTA OPCIONAL
    // ==========================================================

    request.fields[
    'pregunta'] = pregunta;

    // ==========================================================
    // IMAGEN
    // ==========================================================

    request.files.add(
      http.MultipartFile.fromBytes(
        'imagen',
        imagen,
        filename: nombreArchivo,
        contentType: nombreArchivo.toLowerCase().endsWith('.png')
            ? MediaType('image', 'png')
            : nombreArchivo.toLowerCase().endsWith('.webp')
            ? MediaType('image', 'webp')
            : MediaType('image', 'jpeg'),
      ),
    );
    // ==========================================================
    // ENVIAR
    // ==========================================================

    final streamedResponse =
    await request.send();

    final response =
    await http.Response.fromStream(
      streamedResponse,
    );

    print(
      'STATUS ANALISIS PLANTA: '
          '${response.statusCode}',
    );

    print(
      'RESPUESTA ANALISIS PLANTA: '
          '${response.body}',
    );

    if (response.statusCode == 201) {

      return jsonDecode(
        response.body,
      );
    }

    throw Exception(
      'Error al analizar la planta: '
          '${response.body}',
    );
  }

  // ============================================================
  // OBTENER HISTORIAL
  // ============================================================

  static Future<List<dynamic>> obtenerHistorial({
    required String token,
  }) async {

    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/ia/consultas',
      ),

      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print(
      'STATUS HISTORIAL: '
          '${response.statusCode}',
    );

    print(
      'RESPUESTA HISTORIAL: '
          '${response.body}',
    );

    if (response.statusCode == 200) {

      return jsonDecode(
        response.body,
      );
    }

    throw Exception(
      'Error al obtener historial: '
          '${response.body}',
    );
  }
}