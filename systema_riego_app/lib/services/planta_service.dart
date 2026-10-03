import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jardin_service.dart';

class PlantaService {
  static Future<List<dynamic>> obtenerPlantasPorSector({
    required String token,
    required int idSector,
  }) async {
    final response = await http
        .get(
          Uri.parse('${JardinService.baseUrl}/api/plantas/$idSector/plantas'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200)
      return jsonDecode(response.body) as List<dynamic>;
    throw Exception('No se pudieron cargar las plantas: ${response.body}');
  }
}
