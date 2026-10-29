import 'package:flutter_test/flutter_test.dart';
import 'package:systema_riego_app/services/avance_flow.dart';
import 'package:systema_riego_app/services/diagnostico_presentacion.dart';
import 'package:systema_riego_app/services/plan_caso.dart';

void main() {
  test('vista breve no altera el diagnóstico y expandir devuelve el original', () {
    final prefijo = List.filled(20, 'Texto histórico del diagnóstico. ').join();
    final original = '${prefijo}Conclusión original.';
    final breve = DiagnosticoPresentacion.textoVisible(
      original,
      expandido: false,
    );

    expect(DiagnosticoPresentacion.necesitaExpandir(original), isTrue);
    expect(breve.length, lessThan(original.length));
    expect(original, contains('Conclusión original.'));
    expect(
      DiagnosticoPresentacion.textoVisible(original, expandido: true),
      original,
    );
  });

  test('persiste pasos revisados y propone recordatorio solo con plazo explícito', () {
    final pasos = prepararPasosCaso(
      '1. Revisar hojas y anotar cambios (revisar en 3 días)\n'
      '2. Revisar hojas y anotar cambios (revisar en 3 días)\n'
      '3. Mantener observación sin plazo\n'
      'Sin pasos de tratamiento registrados.',
      referencia: DateTime.utc(2026, 10, 12, 10),
    );

    expect(pasos, hasLength(2));
    expect(pasos.first['fecha_limite'], '2026-10-15T10:00:00.000Z');
    expect(pasos.first['recordatorio_fecha'], pasos.first['fecha_limite']);
    expect(pasos.last.containsKey('recordatorio_fecha'), isFalse);
  });

  test('consulta solo ocurre si guardar termina correctamente', () async {
    final eventos = <String>[];
    await guardarAntesDeConsultar(
      guardar: () async => eventos.add('guardado'),
      consultar: () async => eventos.add('consulta'),
    );
    expect(eventos, ['guardado', 'consulta']);

    eventos.clear();
    await expectLater(
      guardarAntesDeConsultar(
        guardar: () async => throw StateError('falló'),
        consultar: () async => eventos.add('consulta'),
      ),
      throwsStateError,
    );
    expect(eventos, isEmpty);
  });
}
