import 'dart:convert';
import 'package:http/http.dart' as http;

class CasoService {
  static const String baseUrl = 'http://localhost:3000';

  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ==========================================================
  // CREAR CASO
  // ==========================================================
  static Future<Map<String, dynamic>> crearCaso({
    required String token,
    int? idPlanta,
    int? idConsulta,
    required String titulo,
    required String diagnostico,
    required String planTrabajo,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/casos'),
          headers: _headers(token),
          body: jsonEncode({
            if (idPlanta != null) 'id_planta': idPlanta,
            if (idConsulta != null) 'id_consulta': idConsulta,
            'titulo': titulo,
            'diagnostico': diagnostico,
            'plan_trabajo': planTrabajo,
          }),
        )
        .timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('El servidor no respondió al crear el caso.'),
        );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al crear el caso: ${response.body}');
  }

  // ==========================================================
  // OBTENER CASOS (opcionalmente filtrados por estado)
  // ==========================================================
  static Future<List<dynamic>> obtenerCasos({
    required String token,
    String? estado,
  }) async {
    final uri = estado == null
        ? Uri.parse('$baseUrl/api/casos')
        : Uri.parse('$baseUrl/api/casos?estado=$estado');

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('El servidor no respondió al obtener casos.'),
        );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener los casos: ${response.body}');
  }

  // ==========================================================
  // CONTAR CASOS ACTIVOS (para el badge del dashboard)
  // ==========================================================
  static Future<int> contarCasosActivos({required String token}) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/casos/activos/contador'),
          headers: _headers(token),
        )
        .timeout(_timeout, onTimeout: () => throw Exception('Timeout'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['total'] ?? 0;
    }

    throw Exception('Error al contar casos activos: ${response.body}');
  }

  // ==========================================================
  // OBTENER UN CASO (con su bitácora)
  // ==========================================================
  static Future<Map<String, dynamic>> obtenerCasoPorId({
    required String token,
    required int idCaso,
  }) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/casos/$idCaso'),
          headers: _headers(token),
        )
        .timeout(_timeout, onTimeout: () => throw Exception('Timeout'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener el caso: ${response.body}');
  }

  // ==========================================================
  // AGREGAR SEGUIMIENTO
  // ==========================================================
  static Future<Map<String, dynamic>> agregarSeguimiento({
    required String token,
    required int idCaso,
    required String nota,
    String? imagenUrl,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/casos/$idCaso/seguimientos'),
          headers: _headers(token),
          body: jsonEncode({
            'nota': nota,
            if (imagenUrl != null) 'imagen_url': imagenUrl,
          }),
        )
        .timeout(_timeout, onTimeout: () => throw Exception('Timeout'));

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al agregar el seguimiento: ${response.body}');
  }

  // ==========================================================
  // CAMBIAR ESTADO DEL CASO
  // ==========================================================
  static Future<Map<String, dynamic>> cambiarEstadoCaso({
    required String token,
    required int idCaso,
    required String estado,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/api/casos/$idCaso/estado'),
          headers: _headers(token),
          body: jsonEncode({'estado': estado}),
        )
        .timeout(_timeout, onTimeout: () => throw Exception('Timeout'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al cambiar el estado: ${response.body}');
  }
}
