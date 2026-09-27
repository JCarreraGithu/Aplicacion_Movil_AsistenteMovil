
import 'dart:convert';
import 'package:http/http.dart' as http;

class LecturaSensorService {
static const String baseUrl =
'http://10.0.2.2:3000';

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

