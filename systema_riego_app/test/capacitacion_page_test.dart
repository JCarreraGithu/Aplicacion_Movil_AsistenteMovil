import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:systema_riego_app/pages/aprender_jardineria_page.dart';
import 'package:systema_riego_app/pages/asistente_page.dart';
import 'package:systema_riego_app/services/capacitacion_service.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const modulo = {
  'id_modulo': 1,
  'slug': 'fundamentos-riego',
  'titulo': 'Fundamentos del riego',
  'descripcion': 'Bases para identificar cuándo regar.',
  'orden': 1,
  'total_lecciones': 1,
};

const resumen = {
  'id_leccion': 7,
  'slug': 'cuando-regar',
  'orden': 1,
  'id_leccion_version': 12,
  'numero_version': 1,
  'titulo': '¿Cuándo debemos regar una planta?',
  'objetivo': 'Reconocer señales de necesidad de agua.',
  'estado_progreso': 'no_iniciado',
  'ultima_calificacion': null,
};

const leccion = {
  'id_leccion': 7,
  'slug': 'cuando-regar',
  'orden': 1,
  'id_modulo': 1,
  'modulo': 'Fundamentos del riego',
  'id_leccion_version': 12,
  'numero_version': 1,
  'titulo': '¿Cuándo debemos regar una planta?',
  'objetivo': 'Reconocer señales de necesidad de agua.',
  'contenido': {
    'secciones': [
      {
        'titulo': 'Revisar el suelo',
        'texto': 'Comprueba la humedad antes de regar.',
      },
    ],
  },
  'fuentes': [
    {
      'titulo': 'Guía educativa',
      'entidad': 'Fuente técnica',
      'url': 'https://example.org',
      'fecha_consulta': null,
      'nota_editorial': null,
    },
  ],
  'calificacion_aprobacion': 70,
};

const evaluacion = {
  'id_leccion_version': 12,
  'numero_version': 1,
  'calificacion_aprobacion': 70,
  'preguntas': [
    {
      'id_pregunta_version': 101,
      'orden': 1,
      'enunciado': '¿Qué conviene hacer antes de regar?',
      'tipo': 'opcion_multiple',
      'opciones': [
        {'clave': 'a', 'texto': 'Comprobar la humedad del suelo'},
        {'clave': 'b', 'texto': 'Regar todos los días'},
      ],
    },
    {
      'id_pregunta_version': 102,
      'orden': 2,
      'enunciado': 'La frecuencia depende solamente de la especie.',
      'tipo': 'verdadero_falso',
      'opciones': [
        {'clave': 'verdadero', 'texto': 'Verdadero'},
        {'clave': 'falso', 'texto': 'Falso'},
      ],
    },
    {
      'id_pregunta_version': 103,
      'orden': 3,
      'enunciado': '¿Qué puede reducir un suelo saturado?',
      'tipo': 'opcion_multiple',
      'opciones': [
        {'clave': 'a', 'texto': 'El oxígeno disponible para las raíces'},
        {'clave': 'b', 'texto': 'La luz de la planta'},
      ],
    },
    {
      'id_pregunta_version': 104,
      'orden': 4,
      'enunciado': 'La marchitez con suelo húmedo demuestra falta de agua.',
      'tipo': 'verdadero_falso',
      'opciones': [
        {'clave': 'verdadero', 'texto': 'Verdadero'},
        {'clave': 'falso', 'texto': 'Falso'},
      ],
    },
  ],
};

const rutaGamificada = {
  'id_ruta': 31,
  'slug': 'fundamentos-del-riego-v1',
  'titulo': 'Camino del riego consciente',
  'descripcion': 'Desafíos breves para observar antes de decidir.',
  'numero_version': 1,
  'id_leccion': 7,
  'id_modulo': 1,
  'xp_ganado': 0,
  'xp_total': 20,
  'actividades': [
    {
      'id_actividad': 301,
      'orden': 1,
      'tipo': 'opcion_multiple',
      'titulo': 'Observa antes de actuar',
      'enunciado': '¿Qué conviene comprobar antes de regar?',
      'icono': 'search',
      'opciones': [
        {'clave': 'a', 'texto': 'Humedad del suelo y contexto'},
        {'clave': 'b', 'texto': 'Regar cada día'},
      ],
      'xp': 10,
      'completada': false,
      'intentos': 0,
    },
    {
      'id_actividad': 302,
      'orden': 2,
      'tipo': 'ordenar_pasos',
      'titulo': 'Ordena la decisión',
      'enunciado': 'Ordena estos pasos.',
      'icono': 'sort',
      'opciones': [
        {'clave': 'contexto', 'texto': 'Considerar el contexto'},
        {'clave': 'suelo', 'texto': 'Comprobar el suelo'},
      ],
      'xp': 10,
      'completada': false,
      'intentos': 0,
    },
  ],
};

void main() {
  testWidgets('Asistente cambia entre Consultar IA y catálogo educativo', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/ia/consultas') return jsonResponse([]);
      if (request.url.path == '/api/capacitacion/modulos')
        return jsonResponse([]);
      if (request.url.path == '/api/capacitacion/progreso')
        return jsonResponse([]);
      return jsonResponse({'mensaje': 'No encontrado'}, 404);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: AsistentePage(token: 'token')),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿En qué puedo ayudarte?'), findsOneWidget);
      await tester.tap(find.text('Aprender jardinería'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no hay cursos publicados'), findsOneWidget);
      await tester.tap(find.text('Consultar IA'));
      await tester.pumpAndSettle();
      expect(find.text('¿En qué puedo ayudarte?'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
    'catálogo presenta lecciones ordenadas y abre lectura con fuentes',
    (tester) async {
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/capacitacion/modulos':
            return jsonResponse([modulo]);
          case '/api/capacitacion/progreso':
            return jsonResponse([]);
          case '/api/capacitacion/modulos/1/lecciones':
            return jsonResponse([resumen]);
          case '/api/capacitacion/modulos/1/rutas':
            return jsonResponse([]);
          case '/api/capacitacion/lecciones/7':
            return jsonResponse(leccion);
          default:
            return jsonResponse({'mensaje': 'No encontrado'}, 404);
        }
      });
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AprenderJardineriaPage(token: 'token', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fundamentos del riego'), findsOneWidget);
      await tester.tap(find.text('Fundamentos del riego'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material de consulta'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cuándo debemos regar una planta?'), findsOneWidget);
      await tester.tap(find.text('¿Cuándo debemos regar una planta?'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar el suelo'), findsOneWidget);
      expect(find.text('Comprueba la humedad antes de regar.'), findsOneWidget);
      expect(find.text('Guía educativa'), findsOneWidget);
      expect(find.text('Fuentes'), findsOneWidget);
    },
  );

  testWidgets(
    'camino gamificado envía una actividad, muestra feedback inmediato y XP',
    (tester) async {
      final posts = <http.Request>[];
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/capacitacion/modulos':
            return jsonResponse([modulo]);
          case '/api/capacitacion/progreso':
            return jsonResponse([]);
          case '/api/capacitacion/modulos/1/lecciones':
            return jsonResponse([resumen]);
          case '/api/capacitacion/modulos/1/rutas':
            return jsonResponse([rutaGamificada]);
          case '/api/capacitacion/rutas/31/actividades/301/respuestas':
            posts.add(request);
            if (posts.length == 1) throw http.ClientException('sin conexión');
            return jsonResponse({
              'id_ruta': 31,
              'id_actividad': 301,
              'respuesta': 'a',
              'correcta': true,
              'respuesta_correcta': 'a',
              'explicacion': 'La humedad y el contexto ayudan a decidir.',
              'xp_otorgado': 10,
              'xp_total': 10,
              'repetido': false,
            }, 201);
          default:
            return jsonResponse({'mensaje': 'No encontrado'}, 404);
        }
      });
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AprenderJardineriaPage(token: 'token', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundamentos del riego'));
      await tester.pumpAndSettle();
      expect(find.text('Tu aventura de jardinería'), findsOneWidget);
      await tester.tap(find.text('Continuar desafío'));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Qué conviene comprobar antes de regar?'),
        findsOneWidget,
      );
      expect(find.text('¿Ordena estos pasos.'), findsNothing);
      await tester.tap(find.text('Humedad del suelo y contexto'));
      await tester.tap(find.byKey(const ValueKey('comprobar-desafio')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
      expect(posts, hasLength(1));
      final idempotencyKey = posts.first.headers['Idempotency-Key'];
      final body = posts.first.body;
      await tester.tap(find.byKey(const ValueKey('comprobar-desafio')));
      await tester.pumpAndSettle();
      expect(posts, hasLength(2));
      expect(
        posts[0].url.path,
        '/api/capacitacion/rutas/31/actividades/301/respuestas',
      );
      expect(posts[0].headers['Authorization'], 'Bearer token');
      expect(idempotencyKey, isNotEmpty);
      expect(posts[1].headers['Idempotency-Key'], idempotencyKey);
      expect(posts[1].body, body);
      expect(jsonDecode(body), {'respuesta': 'a'});
      expect(find.text('¡Muy bien! +10 XP'), findsOneWidget);
      expect(
        find.text('La humedad y el contexto ayudan a decidir.'),
        findsOneWidget,
      );
      expect(find.textContaining('10 XP'), findsWidgets);
      await tester.tap(find.text('Siguiente desafío'));
      await tester.pumpAndSettle();
      expect(find.text('Ordena estos pasos.'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    },
  );

  testWidgets(
    'Comprobar muestra validación visible y errores HTTP sin ocultarlos',
    (tester) async {
      final posts = <http.Request>[];
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/capacitacion/modulos':
            return jsonResponse([modulo]);
          case '/api/capacitacion/progreso':
            return jsonResponse([]);
          case '/api/capacitacion/modulos/1/lecciones':
            return jsonResponse([resumen]);
          case '/api/capacitacion/modulos/1/rutas':
            return jsonResponse([rutaGamificada]);
          case '/api/capacitacion/rutas/31/actividades/301/respuestas':
            posts.add(request);
            return jsonResponse({
              'mensaje': 'Servicio temporal no disponible',
            }, 503);
          default:
            return jsonResponse({'mensaje': 'No encontrado'}, 404);
        }
      });
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AprenderJardineriaPage(token: 'token', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundamentos del riego'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar desafío'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('comprobar-desafio')));
      await tester.pumpAndSettle();
      expect(find.text('Elige una respuesta para continuar.'), findsOneWidget);
      expect(
        posts,
        isEmpty,
        reason: 'La validación local no debe enviar una petición.',
      );

      await tester.tap(find.text('Humedad del suelo y contexto'));
      await tester.tap(find.byKey(const ValueKey('comprobar-desafio')));
      await tester.pumpAndSettle();
      expect(find.text('Servicio temporal no disponible'), findsOneWidget);
      expect(posts, hasLength(1));
      expect(posts.single.headers['Authorization'], 'Bearer token');
      expect(posts.single.headers['Idempotency-Key'], isNotEmpty);
      expect(jsonDecode(posts.single.body), {'respuesta': 'a'});
    },
  );

  testWidgets(
    'respuesta incorrecta presenta explicación y XP real devuelto por servidor',
    (tester) async {
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/capacitacion/modulos':
            return jsonResponse([modulo]);
          case '/api/capacitacion/progreso':
            return jsonResponse([]);
          case '/api/capacitacion/modulos/1/lecciones':
            return jsonResponse([resumen]);
          case '/api/capacitacion/modulos/1/rutas':
            return jsonResponse([rutaGamificada]);
          case '/api/capacitacion/rutas/31/actividades/301/respuestas':
            return jsonResponse({
              'id_ruta': 31,
              'id_actividad': 301,
              'respuesta': 'b',
              'correcta': false,
              'respuesta_correcta': 'a',
              'explicacion': 'Conviene observar el suelo y el contexto.',
              'xp_otorgado': 0,
              'xp_total': 0,
              'repetido': false,
            }, 201);
          default:
            return jsonResponse({'mensaje': 'No encontrado'}, 404);
        }
      });
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AprenderJardineriaPage(token: 'token', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundamentos del riego'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar desafío'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regar cada día'));
      await tester.tap(find.byKey(const ValueKey('comprobar-desafio')));
      await tester.pumpAndSettle();

      expect(find.text('Vamos a aprender de este intento'), findsOneWidget);
      expect(
        find.text('Conviene observar el suelo y el contexto.'),
        findsOneWidget,
      );
      expect(
        find.text('Respuesta sugerida: Humedad del suelo y contexto'),
        findsOneWidget,
      );
      expect(find.textContaining('0 XP'), findsWidgets);
      expect(find.text('Intentar de nuevo'), findsOneWidget);
    },
  );

  testWidgets('al volver al camino restaura niveles y XP desde el backend', (
    tester,
  ) async {
    var completed = false;
    Map<String, dynamic> routeResponse() {
      final activities = (rutaGamificada['actividades'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      activities[0]['completada'] = completed;
      return {
        ...rutaGamificada,
        'xp_ganado': completed ? 10 : 0,
        'actividades': activities,
      };
    }

    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/api/capacitacion/modulos':
          return jsonResponse([modulo]);
        case '/api/capacitacion/progreso':
          return jsonResponse([]);
        case '/api/capacitacion/modulos/1/lecciones':
          return jsonResponse([resumen]);
        case '/api/capacitacion/modulos/1/rutas':
          return jsonResponse([routeResponse()]);
        case '/api/capacitacion/rutas/31/actividades/301/respuestas':
          completed = true;
          return jsonResponse({
            'id_ruta': 31,
            'id_actividad': 301,
            'respuesta': 'a',
            'correcta': true,
            'respuesta_correcta': 'a',
            'explicacion': '¡Bien observado!',
            'xp_otorgado': 10,
            'xp_total': 10,
            'repetido': false,
          }, 201);
        default:
          return jsonResponse({'mensaje': 'No encontrado'}, 404);
      }
    });
    final service = CapacitacionService(
      token: 'token',
      client: client,
      baseUrl: 'http://test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AprenderJardineriaPage(token: 'token', service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fundamentos del riego'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar desafío'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Humedad del suelo y contexto'));
    await tester.tap(find.byKey(const ValueKey('comprobar-desafio')));
    await tester.pumpAndSettle();
    expect(find.text('¡Muy bien! +10 XP'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    expect(find.text('Nivel 1 · Observa antes de actuar'), findsOneWidget);
    expect(find.text('Completado · 10 XP'), findsOneWidget);
    expect(find.textContaining('10 XP'), findsWidgets);
    expect(find.byKey(const ValueKey('planta-virtual')), findsOneWidget);
  });

  testWidgets(
    'valida pendientes, reintenta con idéntico cuerpo y clave y muestra resultado y progreso',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      var postCount = 0;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/capacitacion/modulos':
            return jsonResponse([modulo]);
          case '/api/capacitacion/progreso':
            return jsonResponse(
              postCount > 0
                  ? [
                      {
                        'id_modulo': 1,
                        'modulo': 'Fundamentos del riego',
                        'id_leccion': 7,
                        'slug': 'cuando-regar',
                        'id_leccion_version': 12,
                        'numero_version': 1,
                        'leccion': '¿Cuándo debemos regar una planta?',
                        'estado': 'completado',
                        'ultima_calificacion': 100,
                        'fecha_inicio': null,
                        'fecha_completado': null,
                      },
                    ]
                  : [],
            );
          case '/api/capacitacion/modulos/1/lecciones':
            return jsonResponse([resumen]);
          case '/api/capacitacion/modulos/1/rutas':
            return jsonResponse([]);
          case '/api/capacitacion/lecciones/7':
            return jsonResponse(leccion);
          case '/api/capacitacion/lecciones/7/evaluacion':
            return jsonResponse(evaluacion);
          case '/api/capacitacion/lecciones/7/intentos':
            requests.add(request);
            postCount++;
            if (postCount == 1) throw http.ClientException('sin conexión');
            return jsonResponse({
              'id_intento': 33,
              'id_leccion': 7,
              'id_leccion_version': 12,
              'respuestas_correctas': 4,
              'total_preguntas': 4,
              'calificacion': 100,
              'aprobado': true,
              'fecha_intento': '2026-10-13T12:00:00Z',
              'repetido': true,
              'respuestas': [
                {
                  'id_pregunta_version': 101,
                  'respuesta': 'a',
                  'correcta': true,
                  'respuesta_correcta': 'a',
                  'explicacion': 'Revisa la humedad.',
                },
                {
                  'id_pregunta_version': 102,
                  'respuesta': 'falso',
                  'correcta': true,
                  'respuesta_correcta': 'falso',
                  'explicacion': 'El clima influye.',
                },
                {
                  'id_pregunta_version': 103,
                  'respuesta': 'a',
                  'correcta': true,
                  'respuesta_correcta': 'a',
                  'explicacion': 'El suelo saturado reduce aire.',
                },
                {
                  'id_pregunta_version': 104,
                  'respuesta': 'falso',
                  'correcta': true,
                  'respuesta_correcta': 'falso',
                  'explicacion': 'La marchitez no confirma la causa.',
                },
              ],
            }, 200);
          default:
            return jsonResponse({'mensaje': 'No encontrado'}, 404);
        }
      });
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AprenderJardineriaPage(token: 'token', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundamentos del riego'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material de consulta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Cuándo debemos regar una planta?'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('iniciar-evaluacion')));
      await tester.pumpAndSettle();
      expect(find.text('No se encontró la respuesta'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('enviar-evaluacion')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Responde todas las preguntas antes de enviar.'),
        findsOneWidget,
      );
      expect(find.textContaining('preguntas: 1, 2, 3, 4'), findsOneWidget);
      expect(
        requests,
        isEmpty,
        reason: 'No debe enviar respuestas incompletas.',
      );
      for (final key in [
        'respuesta-101-a',
        'respuesta-102-falso',
        'respuesta-103-a',
        'respuesta-104-falso',
      ]) {
        final answer = find.byKey(ValueKey(key));
        await tester.ensureVisible(answer);
        await tester.tap(answer);
      }
      await tester.tap(find.byKey(const ValueKey('enviar-evaluacion')));
      await tester.pumpAndSettle();
      expect(find.textContaining('sin conexión'), findsOneWidget);
      final key1 = requests.first.headers['Idempotency-Key'];
      final body1 = requests.first.body;
      expect(requests.first.url.path, '/api/capacitacion/lecciones/7/intentos');
      expect(requests.first.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(body1), {
        'id_leccion_version': 12,
        'respuestas': [
          {'id_pregunta_version': 101, 'respuesta': 'a'},
          {'id_pregunta_version': 102, 'respuesta': 'falso'},
          {'id_pregunta_version': 103, 'respuesta': 'a'},
          {'id_pregunta_version': 104, 'respuesta': 'falso'},
        ],
      });
      await tester.tap(find.byKey(const ValueKey('enviar-evaluacion')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests[1].headers['Idempotency-Key'], key1);
      expect(requests[1].body, body1);
      expect(find.text('Evaluación aprobada'), findsOneWidget);
      expect(find.textContaining('Calificación: 100'), findsOneWidget);
      expect(find.textContaining('Revisa la humedad.'), findsOneWidget);
      expect(find.textContaining('Completado'), findsOneWidget);
    },
  );

  test(
    'decodifica respuestas JSON UTF-8 aunque el servidor omita charset',
    () async {
      final bytes = utf8.encode(jsonEncode([modulo]));
      final client = MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );

      final catalogo = await service.obtenerModulos();

      expect(catalogo.single.titulo, 'Fundamentos del riego');
      expect(
        catalogo.single.descripcion,
        'Bases para identificar cuándo regar.',
      );
    },
  );

  test('muestra errores HTTP del backend como error de API', () async {
    final client = MockClient(
      (_) async =>
          jsonResponse({'mensaje': 'Debe responder cada pregunta'}, 400),
    );
    final service = CapacitacionService(
      token: 'token',
      client: client,
      baseUrl: 'http://test',
    );

    await expectLater(
      service.enviarIntentoCodificado(
        idLeccion: 7,
        body: jsonEncode({
          'id_leccion_version': 12,
          'respuestas': [
            {'id_pregunta_version': 101, 'respuesta': 'a'},
          ],
        }),
        idempotencyKey: 'cap-test-key-123',
      ),
      throwsA(
        isA<CapacitacionApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              'Debe responder cada pregunta',
            ),
      ),
    );
  });

  testWidgets(
    'vista de progreso presenta únicamente el estado devuelto por API',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/capacitacion/modulos')
          return jsonResponse([modulo]);
        if (request.url.path == '/api/capacitacion/progreso') {
          return jsonResponse([
            {
              'id_modulo': 1,
              'modulo': 'Fundamentos del riego',
              'id_leccion': 7,
              'slug': 'cuando-regar',
              'id_leccion_version': 12,
              'numero_version': 1,
              'leccion': '¿Cuándo debemos regar una planta?',
              'estado': 'en_progreso',
              'ultima_calificacion': null,
              'fecha_inicio': null,
              'fecha_completado': null,
            },
          ]);
        }
        return jsonResponse([]);
      });
      final service = CapacitacionService(
        token: 'token',
        client: client,
        baseUrl: 'http://test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AprenderJardineriaPage(token: 'token', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capacitacion-progreso')));
      await tester.pumpAndSettle();
      expect(find.text('¿Cuándo debemos regar una planta?'), findsOneWidget);
      expect(find.textContaining('En progreso'), findsOneWidget);
    },
  );

  testWidgets('error del catálogo ofrece reintentar', (tester) async {
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/capacitacion/modulos') {
        calls++;
        return calls == 1
            ? jsonResponse({'mensaje': 'Servicio no disponible'}, 503)
            : jsonResponse([modulo]);
      }
      if (request.url.path == '/api/capacitacion/progreso')
        return jsonResponse([]);
      return jsonResponse([]);
    });
    final service = CapacitacionService(
      token: 'token',
      client: client,
      baseUrl: 'http://test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AprenderJardineriaPage(token: 'token', service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Servicio no disponible'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Fundamentos del riego'), findsOneWidget);
  });
}
