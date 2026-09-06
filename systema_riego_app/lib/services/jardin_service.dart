import 'dart:convert';
import 'package:http/http.dart' as http;

class JardinService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  static Future<List<dynamic>> obtenerJardines({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jardines'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Error al obtener jardines: ${response.body}',
    );
  }

  static Future<List<dynamic>> obtenerSectores({
    required String token,
    required int idJardin,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/jardines/$idJardin/sectores',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Error al obtener sectores: ${response.body}',
    );
  }
}