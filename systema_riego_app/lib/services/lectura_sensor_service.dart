
import 'dart:convert';
import 'package:http/http.dart' as http;

class LecturaSensorService {
static const String baseUrl =
'http://localhost:3000';

static Future<List<dynamic>> obtenerSensoresPorSector({
required String token,
required int idSector,
}) async {
final response = await http.get(
Uri.parse('$baseUrl/api/sensores/sector/$idSector'),
headers: {
'Content-Type': 'application/json',
'Authorization': 'Bearer $token',
},
);
if (response.statusCode != 200) {
throw Exception('No se pudo cargar la lista de sensores.');
}
final data = jsonDecode(response.body);
if (data is! List) throw const FormatException('La lista de sensores no es válida.');
return data;
}

// ============================================================
// OBTENER ÚLTIMAS LECTURAS DE UN SECTOR
// ============================================================

static Future<List<dynamic>> obtenerUltimasLecturasPorSector({
required String token,
required int idSector,
}) async {

final response = await http.get(
Uri.parse(
'$baseUrl/api/lecturas/sector/$idSector',
),
headers: {
'Content-Type': 'application/json',
'Authorization': 'Bearer $token',
},
);

print(
'STATUS LECTURAS SECTOR: ${response.statusCode}',
);

print(
'RESPUESTA LECTURAS: ${response.body}',
);

if (response.statusCode == 200) {
return jsonDecode(response.body);
}

throw Exception(
'Error al obtener lecturas: ${response.body}',
);
}

// ============================================================
// OBTENER HISTORIAL DE UN SENSOR
// ============================================================

static Future<List<dynamic>> obtenerLecturasPorSensor({
required String token,
required int idSensor,
}) async {

final response = await http.get(
Uri.parse(
'$baseUrl/api/lecturas/sensor/$idSensor',
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
'Error al obtener lecturas del sensor: '
'${response.body}',
);
}
}

