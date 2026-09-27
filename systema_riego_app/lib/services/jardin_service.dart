import 'dart:convert';
import 'package:http/http.dart' as http;

class JardinService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  // 👇 FIX: timeout para no quedar colgado indefinidamente
  // si el backend no responde.
  static const Duration _timeout = Duration(seconds: 10);

  static Future<List<dynamic>> obtenerJardines({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jardines'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(
      _timeout,
      onTimeout: () {
        throw Exception(
          'El servidor no respondió a tiempo al obtener jardines (timeout).',
        );
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
    ).timeout(
      _timeout,
      onTimeout: () {
        throw Exception(
          'El servidor no respondió a tiempo al obtener sectores (timeout).',
        );
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