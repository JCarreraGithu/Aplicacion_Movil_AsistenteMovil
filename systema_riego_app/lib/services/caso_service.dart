import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
    int? idSector,
    int? idConsulta,
    required String titulo,
    required String diagnostico,
    required String planTrabajo,
    List<Map<String, dynamic>> pasos = const [],
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/casos'),
          headers: _headers(token),
          body: jsonEncode({
            if (idPlanta != null) 'id_planta': idPlanta,
            if (idSector != null) 'id_sector': idSector,
            if (idConsulta != null) 'id_consulta': idConsulta,
            'titulo': titulo,
            'diagnostico': diagnostico,
            'plan_trabajo': planTrabajo,
            'pasos': pasos,
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
        .get(Uri.parse('$baseUrl/api/casos/$idCaso'), headers: _headers(token))
        .timeout(_timeout, onTimeout: () => throw Exception('Timeout'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener el caso: ${response.body}');
  }

  static Future<List<dynamic>> obtenerRecordatoriosActivos({
    required String token,
  }) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/casos/recordatorios'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode == 200)
      return jsonDecode(response.body) as List<dynamic>;
    throw Exception(
      'Error al obtener notificaciones de casos: ${response.body}',
    );
  }

  // ==========================================================
  // AGREGAR SEGUIMIENTO
  // ==========================================================
  static Future<Map<String, dynamic>> agregarSeguimiento({
    required String token,
    required int idCaso,
    required String nota,
    Uint8List? imagenBytes,
    String? nombreImagen,
    int? idRecordatorio,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/casos/$idCaso/seguimientos'),
    )..headers['Authorization'] = 'Bearer $token';
    request.fields['nota'] = nota;
    if (idRecordatorio != null) {
      request.fields['id_recordatorio'] = idRecordatorio.toString();
    }
    if (imagenBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'imagen',
          imagenBytes,
          filename: nombreImagen ?? 'avance.jpg',
          contentType: _tipoImagen(nombreImagen),
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
      _timeout,
      onTimeout: () => throw Exception('Timeout'),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al agregar el seguimiento: ${response.body}');
  }

  static MediaType _tipoImagen(String? nombre) {
    final extension = nombre?.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  static Future<List<dynamic>> obtenerTareas({
    required String token,
    required int idCaso,
  }) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/casos/$idCaso/tareas'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode == 200)
      return jsonDecode(response.body) as List<dynamic>;
    throw Exception('Error al obtener las tareas: ${response.body}');
  }

  static Future<Map<String, dynamic>> crearTarea({
    required String token,
    required int idCaso,
    required String descripcion,
    DateTime? fechaLimite,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/casos/$idCaso/tareas'),
          headers: _headers(token),
          body: jsonEncode({
            'descripcion': descripcion,
            if (fechaLimite != null)
              'fecha_limite': fechaLimite.toUtc().toIso8601String(),
          }),
        )
        .timeout(_timeout);
    if (response.statusCode == 201)
      return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Error al crear la tarea: ${response.body}');
  }

  static Future<Map<String, dynamic>> actualizarTarea({
    required String token,
    required int idCaso,
    required int idTarea,
    required bool completada,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/api/casos/$idCaso/tareas/$idTarea'),
          headers: _headers(token),
          body: jsonEncode({'completada': completada}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200)
      return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Error al actualizar la tarea: ${response.body}');
  }

  static Future<Map<String, dynamic>> crearRecordatorio({
    required String token,
    required int idCaso,
    required String mensaje,
    required DateTime fecha,
    int? idTarea,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/casos/$idCaso/recordatorios'),
          headers: _headers(token),
          body: jsonEncode({
            'mensaje': mensaje,
            'fecha_recordatorio': fecha.toUtc().toIso8601String(),
            if (idTarea != null) 'id_tarea': idTarea,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode == 201)
      return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Error al programar el recordatorio: ${response.body}');
  }

  static Future<Map<String, dynamic>> cerrarRecordatorio({
    required String token,
    required int idCaso,
    required int idRecordatorio,
  }) async {
    final response = await http
        .patch(
          Uri.parse(
            '$baseUrl/api/casos/$idCaso/recordatorios/$idRecordatorio/cerrar',
          ),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode == 200)
      return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Error al cerrar el recordatorio: ${response.body}');
  }

  static Future<Map<String, dynamic>> actualizarRecordatorio({
    required String token,
    required int idCaso,
    required int idRecordatorio,
    required String mensaje,
    required DateTime fecha,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/api/casos/$idCaso/recordatorios/$idRecordatorio'),
          headers: _headers(token),
          body: jsonEncode({
            'mensaje': mensaje,
            'fecha_recordatorio': fecha.toUtc().toIso8601String(),
          }),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al actualizar el recordatorio: ${response.body}');
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

  static Future<Map<String, dynamic>> cerrarCasoConResultado({
    required String token,
    required int idCaso,
    required String resultado,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/casos/$idCaso/cerrar'),
          headers: _headers(token),
          body: jsonEncode({'resultado': resultado}),
        )
        .timeout(_timeout, onTimeout: () => throw Exception('Timeout'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al cerrar el caso: ${response.body}');
  }
}
