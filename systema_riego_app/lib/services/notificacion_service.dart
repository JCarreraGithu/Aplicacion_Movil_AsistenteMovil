import 'package:flutter/foundation.dart';

import 'actuador_configuracion_service.dart';
import 'caso_service.dart';
import 'lectura_sensor_service.dart';

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

  const ResultadoNotificaciones({
    required this.alertas,
    this.usaDatosDeEjemplo = false,
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
    var pudoConsultarBackend = false;

    try {
      lecturas = await LecturaSensorService.obtenerUltimasLecturasPorSector(
        token: token,
        idSector: idSector,
      ).timeout(_timeout);
      pudoConsultarBackend = true;
    } catch (error) {
      debugPrint('No se pudieron consultar lecturas para alertas: $error');
    }

    try {
      actuadores = await ActuadorConfiguracionService.obtenerActuadores(
        token: token,
        idSector: idSector,
      ).timeout(_timeout);
      pudoConsultarBackend = true;
    } catch (error) {
      debugPrint('No se pudieron consultar actuadores para alertas: $error');
    }

    try {
      recordatorios = await CasoService.obtenerRecordatoriosActivos(
        token: token,
      ).timeout(_timeout);
      pudoConsultarBackend = true;
    } catch (error) {
      debugPrint('No se pudieron consultar recordatorios: $error');
    }

    if (lecturas.isEmpty && actuadores.isEmpty && recordatorios.isEmpty) {
      return ResultadoNotificaciones(
        alertas: _alertasDeEjemplo(),
        usaDatosDeEjemplo: true,
      );
    }

    final alertas = <AlertaRiego>[];
    for (final recordatorio in recordatorios) {
      if (recordatorio is! Map) continue;
      final idCaso = int.tryParse(recordatorio['id_caso']?.toString() ?? '');
      final idRecordatorio = int.tryParse(
        recordatorio['id_recordatorio']?.toString() ?? '',
      );
      final planta = recordatorio['nombre_planta']?.toString();
      final sector = recordatorio['nombre_sector']?.toString();
      final contexto =
          [
                recordatorio['titulo_caso'],
                if (planta != null && planta.isNotEmpty) planta,
                if (sector != null && sector.isNotEmpty) 'Sector $sector',
              ]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' · ');
      alertas.add(
        AlertaRiego(
          titulo:
              recordatorio['mensaje']?.toString() ??
              'Recordatorio de recuperación',
          mensaje: contexto.isEmpty
              ? 'Seguimiento programado para un caso de recuperación.'
              : contexto,
          tipo: 'recordatorio',
          fecha: _fecha(recordatorio['fecha_recordatorio']),
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

    alertas.sort((a, b) => b.fecha.compareTo(a.fecha));
    if (!pudoConsultarBackend && alertas.isEmpty) {
      return ResultadoNotificaciones(
        alertas: _alertasDeEjemplo(),
        usaDatosDeEjemplo: true,
      );
    }
    return ResultadoNotificaciones(alertas: alertas);
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

  static List<AlertaRiego> _alertasDeEjemplo() {
    final ahora = DateTime.now();
    return [
      AlertaRiego(
        titulo: 'Humedad del suelo baja',
        mensaje: 'La humedad está por debajo del nivel recomendado. Revisa el riego.',
        tipo: 'humedad',
        fecha: ahora.subtract(const Duration(minutes: 12)),
        esEjemplo: true,
      ),
      AlertaRiego(
        titulo: 'Bomba de riego activada',
        mensaje: 'El sistema inició un ciclo de riego en el sector.',
        tipo: 'bomba',
        fecha: ahora.subtract(const Duration(hours: 1)),
        esEjemplo: true,
      ),
      AlertaRiego(
        titulo: 'Temperatura alta',
        mensaje: 'La temperatura superó el rango recomendado para las plantas.',
        tipo: 'temperatura',
        fecha: ahora.subtract(const Duration(hours: 3)),
        esEjemplo: true,
      ),
    ];
  }
}
