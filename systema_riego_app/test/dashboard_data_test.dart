import 'package:flutter_test/flutter_test.dart';
import 'package:systema_riego_app/pages/dashboard_data.dart';

void main() {
  group('datos del dashboard por sector', () {
    test('maneja usuario sin jardines o sectores', () {
      expect(combinarSectores([], {}).toList(), isEmpty);
      expect(elegirSectorInicial([], null), isNull);
    });

    test('clasifica las lecturas antiguas y los sensores sin datos', () {
      final ahora = DateTime(2026, 10, 12, 12);
      expect(
        clasificarLectura(
          ahora.subtract(const Duration(minutes: 4)),
          existeLectura: true,
          ahora: ahora,
        ),
        EstadoLectura.reciente,
      );
      expect(
        clasificarLectura(
          ahora.subtract(const Duration(minutes: 6)),
          existeLectura: true,
          ahora: ahora,
        ),
        EstadoLectura.antigua,
      );
      expect(
        clasificarLectura(null, existeLectura: false, ahora: ahora),
        EstadoLectura.sinLectura,
      );
    });

    test('combina sensores registrados con su última lectura o ausencia de datos', () {
      final ahora = DateTime(2026, 10, 12, 12);
      final sensores = combinarLecturasSensores(
        [
          {'id_sensor': 3, 'tipo_sensor': 'Humedad del suelo', 'codigo': 'S-3'},
          {'id_sensor': 4, 'tipo_sensor': 'Temperatura', 'codigo': 'S-4'},
        ],
        [
          {
            'id_sensor': 3,
            'valor': 42,
            'unidad': '%',
            'fecha_hora': '2026-10-12T11:00:00',
          },
        ],
      );

      expect(sensores[0].estadoEn(ahora), EstadoLectura.antigua);
      expect(sensores[0].fechaLectura, DateTime(2026, 10, 12, 11));
      expect(sensores[1].estadoEn(ahora), EstadoLectura.sinLectura);
      expect(sensores[1].lectura, isNull);
    });

    test('combina jardines y sectores y conserva la selección válida', () {
      final options = combinarSectores(
        [
          {'id_jardin': 4, 'nombre': 'Huerto'},
          {'id_jardin': 5, 'nombre': 'Patio'},
        ],
        {
          4: [
            {'id_sector': 8, 'nombre': 'Tomates'},
            {'id_sector': 9, 'nombre': 'Lechugas'},
          ],
          5: [
            {'id_sector': 10, 'nombre': 'Macetas'},
          ],
        },
      );

      expect(options.map((sector) => sector.id).toList(), [8, 9, 10]);
      expect(options.first.etiqueta, 'Huerto · Tomates');
      expect(elegirSectorInicial(options, 9), 9);
      expect(elegirSectorInicial(options, 100), 8);
    });

    test('preserva cantidades nulas y excluye desconocidas de las sumas', () {
      final rows = [
        {'cantidad_agua': '12.5'},
        {'cantidad_agua': null},
        {'cantidad_agua': 'null'},
        {'cantidad_agua': 'NaN'},
        {'cantidad_agua': 2},
      ];

      expect(consumoConocido(rows), 14.5);
      expect(cantidadesDesconocidas(rows), 3);
      expect(cantidadAgua(null), isNull);
    });

    test('agrupa cantidades conocidas por fecha y omite fechas/cantidades desconocidas', () {
      final rows = [
        {'fecha_hora': '2026-10-11T09:00:00Z', 'cantidad_agua': 3},
        {'fecha_hora': '2026-10-11T12:00:00Z', 'cantidad_agua': '4.5'},
        {'fecha_hora': '2026-10-11T13:00:00Z', 'cantidad_agua': null},
        {'fecha_hora': 'fecha incorrecta', 'cantidad_agua': 100},
      ];

      final grouped = agruparConsumoPorDia(rows);
      expect(grouped.values.single, 7.5);
    });
  });
}
