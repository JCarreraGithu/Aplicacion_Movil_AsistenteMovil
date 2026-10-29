import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jardin_service.dart';

class CapacitacionApiException implements Exception {
  final String message;
  final int? statusCode;

  const CapacitacionApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

int _intValue(dynamic value, String field) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null)
    throw CapacitacionApiException('Respuesta inválida: $field');
  return parsed;
}

double? _doubleValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

Map<String, dynamic> _mapValue(dynamic value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw CapacitacionApiException('Respuesta inválida: $field');
}

List<dynamic> _listValue(dynamic value, String field) {
  if (value is List) return value;
  throw CapacitacionApiException('Respuesta inválida: $field');
}

class CapacitacionModulo {
  final int id;
  final String slug;
  final String titulo;
  final String descripcion;
  final int orden;
  final int totalLecciones;

  const CapacitacionModulo({
    required this.id,
    required this.slug,
    required this.titulo,
    required this.descripcion,
    required this.orden,
    required this.totalLecciones,
  });

  factory CapacitacionModulo.fromJson(Map<String, dynamic> json) =>
      CapacitacionModulo(
        id: _intValue(json['id_modulo'], 'id_modulo'),
        slug: '${json['slug'] ?? ''}',
        titulo: '${json['titulo'] ?? ''}',
        descripcion: '${json['descripcion'] ?? ''}',
        orden: _intValue(json['orden'], 'orden'),
        totalLecciones: _intValue(json['total_lecciones'], 'total_lecciones'),
      );
}

class CapacitacionLeccionResumen {
  final int id;
  final String slug;
  final int orden;
  final int idVersion;
  final int numeroVersion;
  final String titulo;
  final String objetivo;
  final String estadoProgreso;
  final double? ultimaCalificacion;

  const CapacitacionLeccionResumen({
    required this.id,
    required this.slug,
    required this.orden,
    required this.idVersion,
    required this.numeroVersion,
    required this.titulo,
    required this.objetivo,
    required this.estadoProgreso,
    required this.ultimaCalificacion,
  });

  factory CapacitacionLeccionResumen.fromJson(Map<String, dynamic> json) =>
      CapacitacionLeccionResumen(
        id: _intValue(json['id_leccion'], 'id_leccion'),
        slug: '${json['slug'] ?? ''}',
        orden: _intValue(json['orden'], 'orden'),
        idVersion: _intValue(json['id_leccion_version'], 'id_leccion_version'),
        numeroVersion: _intValue(json['numero_version'], 'numero_version'),
        titulo: '${json['titulo'] ?? ''}',
        objetivo: '${json['objetivo'] ?? ''}',
        estadoProgreso: '${json['estado_progreso'] ?? 'no_iniciado'}',
        ultimaCalificacion: _doubleValue(json['ultima_calificacion']),
      );
}

class CapacitacionSeccion {
  final String titulo;
  final String texto;

  const CapacitacionSeccion({required this.titulo, required this.texto});
}

class CapacitacionFuente {
  final String titulo;
  final String entidad;
  final String url;
  final String? fechaConsulta;
  final String? notaEditorial;

  const CapacitacionFuente({
    required this.titulo,
    required this.entidad,
    required this.url,
    this.fechaConsulta,
    this.notaEditorial,
  });
}

class CapacitacionLeccion {
  final int id;
  final int idModulo;
  final int idVersion;
  final int numeroVersion;
  final String titulo;
  final String modulo;
  final String objetivo;
  final List<CapacitacionSeccion> secciones;
  final List<CapacitacionFuente> fuentes;

  const CapacitacionLeccion({
    required this.id,
    required this.idModulo,
    required this.idVersion,
    required this.numeroVersion,
    required this.titulo,
    required this.modulo,
    required this.objetivo,
    required this.secciones,
    required this.fuentes,
  });

  factory CapacitacionLeccion.fromJson(Map<String, dynamic> json) {
    final contenido = _mapValue(json['contenido'], 'contenido');
    final secciones = _listValue(contenido['secciones'], 'contenido.secciones')
        .map((dynamic item) {
          final section = _mapValue(item, 'sección');
          return CapacitacionSeccion(
            titulo: '${section['titulo'] ?? ''}',
            texto: '${section['texto'] ?? ''}',
          );
        })
        .toList(growable: false);
    final fuentes = _listValue(json['fuentes'], 'fuentes')
        .map((dynamic item) {
          final source = _mapValue(item, 'fuente');
          return CapacitacionFuente(
            titulo: '${source['titulo'] ?? ''}',
            entidad: '${source['entidad'] ?? ''}',
            url: '${source['url'] ?? ''}',
            fechaConsulta: source['fecha_consulta']?.toString(),
            notaEditorial: source['nota_editorial']?.toString(),
          );
        })
        .toList(growable: false);

    return CapacitacionLeccion(
      id: _intValue(json['id_leccion'], 'id_leccion'),
      idModulo: _intValue(json['id_modulo'], 'id_modulo'),
      idVersion: _intValue(json['id_leccion_version'], 'id_leccion_version'),
      numeroVersion: _intValue(json['numero_version'], 'numero_version'),
      titulo: '${json['titulo'] ?? ''}',
      modulo: '${json['modulo'] ?? ''}',
      objetivo: '${json['objetivo'] ?? ''}',
      secciones: secciones,
      fuentes: fuentes,
    );
  }
}

class CapacitacionOpcion {
  final String clave;
  final String texto;

  const CapacitacionOpcion({required this.clave, required this.texto});

  factory CapacitacionOpcion.fromJson(Map<String, dynamic> json) =>
      CapacitacionOpcion(
        clave: '${json['clave'] ?? ''}',
        texto: '${json['texto'] ?? ''}',
      );
}

class CapacitacionPregunta {
  final int id;
  final int orden;
  final String enunciado;
  final String tipo;
  final List<CapacitacionOpcion> opciones;

  const CapacitacionPregunta({
    required this.id,
    required this.orden,
    required this.enunciado,
    required this.tipo,
    required this.opciones,
  });

  factory CapacitacionPregunta.fromJson(Map<String, dynamic> json) {
    final choices = _listValue(json['opciones'], 'pregunta.opciones')
        .map((dynamic item) {
          final choice = _mapValue(item, 'opción');
          return CapacitacionOpcion(
            clave: '${choice['clave'] ?? ''}',
            texto: '${choice['texto'] ?? ''}',
          );
        })
        .toList(growable: false);
    return CapacitacionPregunta(
      id: _intValue(json['id_pregunta_version'], 'id_pregunta_version'),
      orden: _intValue(json['orden'], 'orden'),
      enunciado: '${json['enunciado'] ?? ''}',
      tipo: '${json['tipo'] ?? ''}',
      opciones: choices,
    );
  }
}

class CapacitacionEvaluacion {
  final int idVersion;
  final int numeroVersion;
  final double? calificacionAprobacion;
  final List<CapacitacionPregunta> preguntas;

  const CapacitacionEvaluacion({
    required this.idVersion,
    required this.numeroVersion,
    required this.calificacionAprobacion,
    required this.preguntas,
  });

  factory CapacitacionEvaluacion.fromJson(Map<String, dynamic> json) =>
      CapacitacionEvaluacion(
        idVersion: _intValue(json['id_leccion_version'], 'id_leccion_version'),
        numeroVersion: _intValue(json['numero_version'], 'numero_version'),
        calificacionAprobacion: _doubleValue(json['calificacion_aprobacion']),
        preguntas: _listValue(json['preguntas'], 'preguntas')
            .map(
              (dynamic item) =>
                  CapacitacionPregunta.fromJson(_mapValue(item, 'pregunta')),
            )
            .toList(growable: false),
      );
}

class CapacitacionRespuestaResultado {
  final int idPregunta;
  final dynamic respuesta;
  final bool correcta;
  final dynamic respuestaCorrecta;
  final String explicacion;

  const CapacitacionRespuestaResultado({
    required this.idPregunta,
    required this.respuesta,
    required this.correcta,
    required this.respuestaCorrecta,
    required this.explicacion,
  });

  factory CapacitacionRespuestaResultado.fromJson(Map<String, dynamic> json) =>
      CapacitacionRespuestaResultado(
        idPregunta: _intValue(
          json['id_pregunta_version'],
          'id_pregunta_version',
        ),
        respuesta: json['respuesta'],
        correcta: json['correcta'] == true,
        respuestaCorrecta: json['respuesta_correcta'],
        explicacion: '${json['explicacion'] ?? ''}',
      );
}

class CapacitacionResultado {
  final int idIntento;
  final int idLeccion;
  final int idVersion;
  final int respuestasCorrectas;
  final int totalPreguntas;
  final double calificacion;
  final bool aprobado;
  final bool repetido;
  final List<CapacitacionRespuestaResultado> respuestas;

  const CapacitacionResultado({
    required this.idIntento,
    required this.idLeccion,
    required this.idVersion,
    required this.respuestasCorrectas,
    required this.totalPreguntas,
    required this.calificacion,
    required this.aprobado,
    required this.repetido,
    required this.respuestas,
  });

  factory CapacitacionResultado.fromJson(Map<String, dynamic> json) =>
      CapacitacionResultado(
        idIntento: _intValue(json['id_intento'], 'id_intento'),
        idLeccion: _intValue(json['id_leccion'], 'id_leccion'),
        idVersion: _intValue(json['id_leccion_version'], 'id_leccion_version'),
        respuestasCorrectas: _intValue(
          json['respuestas_correctas'],
          'respuestas_correctas',
        ),
        totalPreguntas: _intValue(json['total_preguntas'], 'total_preguntas'),
        calificacion: _doubleValue(json['calificacion']) ?? 0,
        aprobado: json['aprobado'] == true,
        repetido: json['repetido'] == true,
        respuestas: _listValue(json['respuestas'], 'respuestas')
            .map(
              (dynamic item) => CapacitacionRespuestaResultado.fromJson(
                _mapValue(item, 'respuesta'),
              ),
            )
            .toList(growable: false),
      );
}

class CapacitacionProgreso {
  final int idModulo;
  final String modulo;
  final int idLeccion;
  final String slug;
  final int idVersion;
  final int numeroVersion;
  final String leccion;
  final String estado;
  final double? ultimaCalificacion;
  final String? fechaInicio;
  final String? fechaCompletado;

  const CapacitacionProgreso({
    required this.idModulo,
    required this.modulo,
    required this.idLeccion,
    required this.slug,
    required this.idVersion,
    required this.numeroVersion,
    required this.leccion,
    required this.estado,
    required this.ultimaCalificacion,
    required this.fechaInicio,
    required this.fechaCompletado,
  });

  factory CapacitacionProgreso.fromJson(Map<String, dynamic> json) =>
      CapacitacionProgreso(
        idModulo: _intValue(json['id_modulo'], 'id_modulo'),
        modulo: '${json['modulo'] ?? ''}',
        idLeccion: _intValue(json['id_leccion'], 'id_leccion'),
        slug: '${json['slug'] ?? ''}',
        idVersion: _intValue(json['id_leccion_version'], 'id_leccion_version'),
        numeroVersion: _intValue(json['numero_version'], 'numero_version'),
        leccion: '${json['leccion'] ?? ''}',
        estado: '${json['estado'] ?? 'no_iniciado'}',
        ultimaCalificacion: _doubleValue(json['ultima_calificacion']),
        fechaInicio: json['fecha_inicio']?.toString(),
        fechaCompletado: json['fecha_completado']?.toString(),
      );
}

class CapacitacionActividad {
  final int id;
  final int orden;
  final String tipo;
  final String titulo;
  final String enunciado;
  final String icono;
  final List<CapacitacionOpcion> opciones;
  final int xp;
  final bool completada;
  final int intentos;

  const CapacitacionActividad({
    required this.id,
    required this.orden,
    required this.tipo,
    required this.titulo,
    required this.enunciado,
    required this.icono,
    required this.opciones,
    required this.xp,
    required this.completada,
    required this.intentos,
  });

  factory CapacitacionActividad.fromJson(Map<String, dynamic> json) =>
      CapacitacionActividad(
        id: _intValue(json['id_actividad'], 'id_actividad'),
        orden: _intValue(json['orden'], 'orden'),
        tipo: '${json['tipo'] ?? ''}',
        titulo: '${json['titulo'] ?? ''}',
        enunciado: '${json['enunciado'] ?? ''}',
        icono: '${json['icono'] ?? 'eco'}',
        opciones: _listValue(json['opciones'], 'actividad.opciones')
            .map(
              (item) => CapacitacionOpcion.fromJson(
                _mapValue(item, 'actividad.opción'),
              ),
            )
            .toList(growable: false),
        xp: _intValue(json['xp'], 'xp'),
        completada: json['completada'] == true,
        intentos: _intValue(json['intentos'] ?? 0, 'intentos'),
      );
}

class CapacitacionRuta {
  final int id;
  final String titulo;
  final String descripcion;
  final int numeroVersion;
  final int idLeccion;
  final int idModulo;
  final int xpGanado;
  final int xpTotal;
  final List<CapacitacionActividad> actividades;

  const CapacitacionRuta({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.numeroVersion,
    required this.idLeccion,
    required this.idModulo,
    required this.xpGanado,
    required this.xpTotal,
    required this.actividades,
  });

  factory CapacitacionRuta.fromJson(Map<String, dynamic> json) =>
      CapacitacionRuta(
        id: _intValue(json['id_ruta'], 'id_ruta'),
        titulo: '${json['titulo'] ?? ''}',
        descripcion: '${json['descripcion'] ?? ''}',
        numeroVersion: _intValue(json['numero_version'], 'numero_version'),
        idLeccion: _intValue(json['id_leccion'], 'id_leccion'),
        idModulo: _intValue(json['id_modulo'], 'id_modulo'),
        xpGanado: _intValue(json['xp_ganado'] ?? 0, 'xp_ganado'),
        xpTotal: _intValue(json['xp_total'] ?? 0, 'xp_total'),
        actividades: _listValue(json['actividades'], 'actividades')
            .map(
              (item) =>
                  CapacitacionActividad.fromJson(_mapValue(item, 'actividad')),
            )
            .toList(growable: false),
      );
}

class CapacitacionRespuestaActividad {
  final bool correcta;
  final dynamic respuestaCorrecta;
  final String explicacion;
  final int xpOtorgado;
  final int xpTotal;
  final bool repetido;

  const CapacitacionRespuestaActividad({
    required this.correcta,
    required this.respuestaCorrecta,
    required this.explicacion,
    required this.xpOtorgado,
    required this.xpTotal,
    required this.repetido,
  });

  factory CapacitacionRespuestaActividad.fromJson(Map<String, dynamic> json) =>
      CapacitacionRespuestaActividad(
        correcta: json['correcta'] == true,
        respuestaCorrecta: json['respuesta_correcta'],
        explicacion: '${json['explicacion'] ?? ''}',
        xpOtorgado: _intValue(json['xp_otorgado'] ?? 0, 'xp_otorgado'),
        xpTotal: _intValue(json['xp_total'] ?? 0, 'xp_total'),
        repetido: json['repetido'] == true,
      );
}

class CapacitacionService {
  final String token;
  final http.Client? client;
  final String baseUrl;
  final Duration timeout;

  CapacitacionService({
    required this.token,
    this.client,
    this.baseUrl = JardinService.baseUrl,
    this.timeout = const Duration(seconds: 12),
  });

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _get(String path) =>
      (client?.get(Uri.parse('$baseUrl$path'), headers: _headers) ??
              http.get(Uri.parse('$baseUrl$path'), headers: _headers))
          .timeout(timeout);

  Future<http.Response> _post(
    String path, {
    required String idempotencyKey,
    required String body,
  }) =>
      (client?.post(
                Uri.parse('$baseUrl$path'),
                headers: {..._headers, 'Idempotency-Key': idempotencyKey},
                body: body,
              ) ??
              http.post(
                Uri.parse('$baseUrl$path'),
                headers: {..._headers, 'Idempotency-Key': idempotencyKey},
                body: body,
              ))
          .timeout(timeout);

  dynamic _decode(http.Response response) {
    dynamic decoded;
    try {
      // `Response.body` puede elegir Latin-1 si el backend omite charset.
      // JSON de Express/PostgreSQL se transporta en UTF-8; decodificamos los
      // bytes explícitamente para conservar tildes y caracteres españoles.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    final message = decoded is Map && decoded['mensaje'] != null
        ? decoded['mensaje'].toString()
        : 'No se pudo completar la solicitud (HTTP ${response.statusCode}).';
    throw CapacitacionApiException(message, statusCode: response.statusCode);
  }

  Future<List<CapacitacionModulo>> obtenerModulos() async {
    final data = _listValue(
      _decode(await _get('/api/capacitacion/modulos')),
      'módulos',
    );
    return data
        .map(
          (dynamic item) =>
              CapacitacionModulo.fromJson(_mapValue(item, 'módulo')),
        )
        .toList(growable: false);
  }

  Future<List<CapacitacionLeccionResumen>> obtenerLecciones(
    int idModulo,
  ) async {
    final data = _listValue(
      _decode(await _get('/api/capacitacion/modulos/$idModulo/lecciones')),
      'lecciones',
    );
    return data
        .map(
          (dynamic item) =>
              CapacitacionLeccionResumen.fromJson(_mapValue(item, 'lección')),
        )
        .toList(growable: false);
  }

  Future<List<CapacitacionRuta>> obtenerRutasModulo(int idModulo) async {
    final data = _listValue(
      _decode(await _get('/api/capacitacion/modulos/$idModulo/rutas')),
      'rutas',
    );
    return data
        .map((item) => CapacitacionRuta.fromJson(_mapValue(item, 'ruta')))
        .toList(growable: false);
  }

  Future<CapacitacionRuta> obtenerRuta(int idRuta) async =>
      CapacitacionRuta.fromJson(
        _mapValue(
          _decode(await _get('/api/capacitacion/rutas/$idRuta')),
          'ruta',
        ),
      );

  Future<CapacitacionRespuestaActividad> responderActividad({
    required int idRuta,
    required int idActividad,
    required dynamic respuesta,
    required String idempotencyKey,
  }) async {
    final response = await _post(
      '/api/capacitacion/rutas/$idRuta/actividades/$idActividad/respuestas',
      idempotencyKey: idempotencyKey,
      body: jsonEncode({'respuesta': respuesta}),
    );
    return CapacitacionRespuestaActividad.fromJson(
      _mapValue(_decode(response), 'resultado de actividad'),
    );
  }

  Future<CapacitacionLeccion> obtenerLeccion(int idLeccion) async =>
      CapacitacionLeccion.fromJson(
        _mapValue(
          _decode(await _get('/api/capacitacion/lecciones/$idLeccion')),
          'lección',
        ),
      );

  Future<CapacitacionEvaluacion> obtenerEvaluacion(int idLeccion) async =>
      CapacitacionEvaluacion.fromJson(
        _mapValue(
          _decode(
            await _get('/api/capacitacion/lecciones/$idLeccion/evaluacion'),
          ),
          'evaluación',
        ),
      );

  Future<CapacitacionResultado> enviarIntento({
    required int idLeccion,
    required int idVersion,
    required List<Map<String, dynamic>> respuestas,
    required String idempotencyKey,
  }) async {
    final body = jsonEncode({
      'id_leccion_version': idVersion,
      'respuestas': respuestas,
    });
    return enviarIntentoCodificado(
      idLeccion: idLeccion,
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<CapacitacionResultado> enviarIntentoCodificado({
    required int idLeccion,
    required String body,
    required String idempotencyKey,
  }) async => CapacitacionResultado.fromJson(
    _mapValue(
      _decode(
        await _post(
          '/api/capacitacion/lecciones/$idLeccion/intentos',
          idempotencyKey: idempotencyKey,
          body: body,
        ),
      ),
      'resultado',
    ),
  );

  Future<List<CapacitacionProgreso>> obtenerProgreso() async {
    final data = _listValue(
      _decode(await _get('/api/capacitacion/progreso')),
      'progreso',
    );
    return data
        .map(
          (dynamic item) =>
              CapacitacionProgreso.fromJson(_mapValue(item, 'progreso')),
        )
        .toList(growable: false);
  }
}
