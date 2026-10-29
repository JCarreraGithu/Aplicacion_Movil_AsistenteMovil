import 'package:flutter/foundation.dart';

import 'actuador_configuracion_service.dart';
import 'caso_service.dart';
import 'lectura_sensor_service.dart';
import 'recordatorio_caso.dart';

class AlertaRiego {
  final String titulo;
  final String mensaje;
  final String tipo;
  final DateTime fecha;
  final bool esEjemplo;
  final int? idCaso;
  final int? idRecordatorio;
  final bool esRecordatorio;

  const AlertaRiego({
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.fecha,
    this.esEjemplo = false,
    this.idCaso,
    this.idRecordatorio,
    this.esRecordatorio = false,
  });
}

class ResultadoNotificaciones {
  final List<AlertaRiego> alertas;
  final bool usaDatosDeEjemplo;
  final bool huboError;

  const ResultadoNotificaciones({
    required this.alertas,
    this.usaDatosDeEjemplo = false,
    this.huboError = false,
  });
}

class NotificacionService {
  static const Duration _timeout = Duration(seconds: 10);
  static const double _humedadBaja = 30;
  static const double _temperaturaAlta = 35;

  static Future<ResultadoNotificaciones> obtenerAlertas({
    required String token,
    int idSector = 1,
  }) async {
    List<dynamic> lecturas = [];
    List<dynamic> actuadores = [];
    List<dynamic> recordatorios = [];
    var huboError = false;
    try {
      lecturas = await LecturaSensorService.obtenerUltimasLecturasPorSector(
        token: token,
        idSector: idSector,
      ).timeout(_timeout);
    } catch (error) {
      huboError = true;
      debugPrint('No se pudieron consultar lecturas para alertas: $error');
    }

    try {
      actuadores = await ActuadorConfiguracionService.obtenerActuadores(
        token: token,
        idSector: idSector,
      ).timeout(_timeout);
    } catch (error) {
      huboError = true;
      debugPrint('No se pudieron consultar actuadores para alertas: $error');
    }

    try {
      recordatorios = await CasoService.obtenerRecordatoriosActivos(
        token: token,
      ).timeout(_timeout);
    } catch (error) {
      huboError = true;
      debugPrint('No se pudieron consultar recordatorios: $error');
    }

    final alertas = <AlertaRiego>[];
    final recordatoriosMap = RecordatorioCasoHelper.unicosPorId(
      recordatorios.whereType<Map>().map(
        (recordatorio) => Map<String, dynamic>.from(recordatorio),
      ),
    );
    for (final recordatorio in recordatoriosMap) {
      final idCaso = int.tryParse(recordatorio['id_caso']?.toString() ?? '');
      final idRecordatorio = int.tryParse(
        recordatorio['id_recordatorio']?.toString() ?? '',
      );
      final planta = recordatorio['nombre_planta']?.toString();
      final paso = recordatorio['tarea_descripcion']?.toString() ?? '';
      final fecha = _fecha(recordatorio['fecha_recordatorio']);
      final contexto =
          [
                if (planta != null && planta.isNotEmpty) planta else recordatorio['titulo_caso'],
                if (paso.isNotEmpty) paso,
                if (recordatorio['nombre_sector'] != null)
                  'Sector ${recordatorio['nombre_sector']}',
              ]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' · ');
      alertas.add(
        AlertaRiego(
          titulo:
              recordatorio['mensaje']?.toString() ??
              'Recordatorio de recuperación',
          mensaje: planta == null || planta.isEmpty
              ? (contexto.isEmpty
                    ? 'Seguimiento programado para un caso de recuperación.'
                    : contexto)
              : RecordatorioCasoHelper.mensaje(
                  planta: planta,
                  paso: paso,
                  fecha: fecha,
                ),
          tipo: 'recordatorio',
          fecha: fecha,
          idCaso: idCaso,
          idRecordatorio: idRecordatorio,
          esRecordatorio: true,
        ),
      );
    }
    for (final lectura in lecturas) {
      if (lectura is! Map) continue;
      final tipo = (lectura['tipo_sensor'] ?? '').toString().toLowerCase();
      final valor = double.tryParse(lectura['valor']?.toString() ?? '');
      if (valor == null) continue;

      if (tipo.contains('humedad') &&
          tipo.contains('suelo') &&
          valor < _humedadBaja) {
        alertas.add(
          AlertaRiego(
            titulo: 'Humedad del suelo baja',
            mensaje:
                'La humedad está en ${_formatear(valor)}${lectura['unidad'] ?? '%'}; revisa el riego del sector.',
            tipo: 'humedad',
            fecha: _fecha(lectura['fecha_hora']),
          ),
        );
      } else if (tipo.contains('temperatura') && valor >= _temperaturaAlta) {
        alertas.add(
          AlertaRiego(
            titulo: 'Temperatura alta',
            mensaje:
                'Se registraron ${_formatear(valor)}${lectura['unidad'] ?? '°C'} en el sector.',
            tipo: 'temperatura',
            fecha: _fecha(lectura['fecha_hora']),
          ),
        );
      }
    }

    for (final actuador in actuadores) {
      if (actuador is! Map || !_estaEncendido(actuador['estado'])) continue;
      final nombre = (actuador['tipo_actuador'] ?? 'Bomba de riego').toString();
      final codigo = actuador['codigo']?.toString();
      alertas.add(
        AlertaRiego(
          titulo: '$nombre activada',
          mensaje: codigo == null
              ? 'El actuador está encendido.'
              : 'El actuador $codigo está encendido.',
          tipo: 'bomba',
          fecha: DateTime.now(),
        ),
      );
    }

    alertas.sort((a, b) {
      if (a.esRecordatorio && b.esRecordatorio) {
        return a.fecha.compareTo(b.fecha);
      }
      if (a.esRecordatorio != b.esRecordatorio) {
        return a.esRecordatorio ? -1 : 1;
      }
      return b.fecha.compareTo(a.fecha);
    });
    return ResultadoNotificaciones(alertas: alertas, huboError: huboError);
  }

  static bool _estaEncendido(dynamic estado) {
    final value = estado?.toString().toLowerCase();
    return value == 'encendido' ||
        value == 'on' ||
        value == 'true' ||
        value == '1' ||
        value == 'activo';
  }

  static DateTime _fecha(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

  static String _formatear(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

}
