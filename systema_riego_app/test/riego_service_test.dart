import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:systema_riego_app/services/riego_service.dart';

void main() {
  test('envía el sector, intervalo y token en la consulta existente', () async {
    await http.runWithClient(
      () async {
        final result = await RiegoService.obtenerRiegosPorIntervalo(
          token: 'token-test',
          idSector: 22,
          dias: 7,
        );
        expect(result, isEmpty);
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/api/riegos/sector/22'));
        expect(request.url.queryParameters, {'dias': '7', 'periodo': 'actual'});
        expect(request.headers['Authorization'], 'Bearer token-test');
        return http.Response('[]', 200);
      }),
    );
  });

  test('propaga un error de conexión sin sustituirlo por datos ficticios', () async {
    await expectLater(
      http.runWithClient(
        () => RiegoService.obtenerRiegosPorIntervalo(
          token: 'token-test',
          idSector: 22,
          dias: 30,
        ),
        () => MockClient((_) async => throw http.ClientException('offline')),
      ),
      throwsA(isA<http.ClientException>()),
    );
  });
}
