import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ia_service.dart';
import '../services/caso_service.dart';
import '../services/jardin_service.dart';
import '../services/planta_service.dart';
import '../services/plan_caso.dart';
import 'aprender_jardineria_page.dart';

// ============================================================
// CONFIGURACIÓN DE SCROLL
// ============================================================

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

// ============================================================
// PÁGINA DEL ASISTENTE
// ============================================================

class AsistentePage extends StatefulWidget {
  final String token;
  final String? preguntaInicial;
  final String? contextoCaso;
  final XFile? imagenInicialCaso;
  final int? idPlanta;
  final String? nombrePlanta;

  const AsistentePage({
    super.key,
    required this.token,
    this.preguntaInicial,
    this.contextoCaso,
    this.imagenInicialCaso,
    this.idPlanta,
    this.nombrePlanta,
  });

  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  // ==========================================================
  // CONTROLADORES
  // ==========================================================

  final TextEditingController preguntaController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  // ==========================================================
  // IMAGE PICKER
  // ==========================================================

  final ImagePicker imagePicker = ImagePicker();

  // ==========================================================
  // ESTADOS
  // ==========================================================

  List<Map<String, dynamic>> mensajes = [];

  bool cargando = false;
  bool cargandoHistorial = true;
  bool analizandoImagen = false;
  bool _envioInicialProgramado = false;
  bool _mostrarBotonBajar = false;
  bool _modoAprendizaje = false;
  String? _contextoCasoPendiente;

  XFile? imagenSeleccionada;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_actualizarBotonBajar);
    _contextoCasoPendiente = widget.contextoCaso;
    imagenSeleccionada = widget.imagenInicialCaso;

    if (widget.preguntaInicial != null &&
        widget.preguntaInicial!.trim().isNotEmpty) {
      preguntaController.text = widget.preguntaInicial!;

      preguntaController.selection = TextSelection.fromPosition(
        TextPosition(offset: preguntaController.text.length),
      );
    }

    cargarHistorial();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    preguntaController.dispose();
    scrollController.removeListener(_actualizarBotonBajar);
    scrollController.dispose();
    super.dispose();
  }

  void _actualizarBotonBajar() {
    if (!scrollController.hasClients || !mounted) return;
    final mostrar =
        scrollController.position.maxScrollExtent -
            scrollController.position.pixels >
        180;
    if (mostrar != _mostrarBotonBajar) {
      setState(() => _mostrarBotonBajar = mostrar);
    }
  }

  // ==========================================================
  // CARGAR HISTORIAL
  // ==========================================================

  Future<void> cargarHistorial() async {
    try {
      final historial = await IaService.obtenerHistorial(token: widget.token);

      final mensajesCargados = <Map<String, dynamic>>[];

      for (final consulta in historial.reversed) {
        mensajesCargados.add({
          'tipo': 'usuario',
          'texto': consulta['pregunta'] ?? '',
        });

        mensajesCargados.add({
          'tipo': 'asistente',
          'texto': consulta['respuesta'] ?? '',
          'idConsulta': consulta['id_consulta'],
        });
      }

      if (!mounted) return;

      setState(() {
        mensajes = mensajesCargados;
        cargandoHistorial = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        bajarChat();
        if (!_envioInicialProgramado &&
            widget.preguntaInicial != null &&
            widget.contextoCaso != null) {
          _envioInicialProgramado = true;
          preguntaController.text = widget.preguntaInicial!;
          enviarMensaje();
        }
      });
    } catch (e) {
      debugPrint('Error cargando historial IA: $e');

      if (!mounted) return;

      setState(() {
        cargandoHistorial = false;
      });
    }
  }

  // ==========================================================
  // ENVIAR MENSAJE
  // ==========================================================

  Future<void> enviarMensaje() async {
    final pregunta = preguntaController.text.trim();

    if (imagenSeleccionada != null) {
      await analizarPlanta(imagenSeleccionada!, pregunta);
      return;
    }

    if (pregunta.isEmpty || cargando || analizandoImagen) {
      return;
    }

    await consultarIA();
  }

  // ==========================================================
  // CONSULTAR IA
  // ==========================================================

  Future<void> consultarIA() async {
    final pregunta = preguntaController.text.trim();

    if (pregunta.isEmpty || cargando || analizandoImagen) {
      return;
    }

    setState(() {
      mensajes.add({'tipo': 'usuario', 'texto': pregunta});

      cargando = true;

      preguntaController.clear();
    });

    bajarChat();

    try {
      debugPrint('====================================');

      debugPrint('ENVIANDO CONSULTA A IA');

      debugPrint('Pregunta: $pregunta');

      debugPrint('====================================');

      final resultado = await IaService.consultarIA(
        pregunta: pregunta,
        token: widget.token,
        contextoCaso: _contextoCasoPendiente,
      );

      debugPrint('RESPUESTA IA: $resultado');

      final respuesta =
          resultado['respuesta'] ??
          'No se recibió una respuesta del asistente.';
      final idConsulta = int.tryParse(
        resultado['id_consulta']?.toString() ?? '',
      );

      if (!mounted) return;

      setState(() {
        mensajes.add({
          'tipo': 'asistente',
          'texto': respuesta.toString(),
          'idConsulta': idConsulta,
        });

        cargando = false;
      });

      bajarChat();
    } catch (e) {
      debugPrint('ERROR CONSULTANDO IA: $e');

      if (!mounted) return;

      setState(() {
        mensajes.add({
          'tipo': 'asistente',
          'texto': 'No se pudo conectar con el asistente.\n\n$e',
        });

        cargando = false;
      });

      bajarChat();
    }
  }

  // ============================================================
  // SELECCIONAR FOTO
  // ============================================================

  Future<void> tomarFotoPlanta() async {
    if (cargando || analizandoImagen) {
      return;
    }

    try {
      final XFile? imagen = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (imagen == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        imagenSeleccionada = imagen;
      });
    } catch (e) {
      debugPrint('ERROR TOMANDO FOTO: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la fotografía: $e')),
      );
    }
  }

  // ============================================================
  // ANALIZAR PLANTA CON IA
  // ============================================================

  Future<void> analizarPlanta(XFile imagen, String preguntaUsuario) async {
    if (analizandoImagen) {
      return;
    }

    final pregunta = preguntaUsuario.trim();

    if (!mounted) return;

    setState(() {
      analizandoImagen = true;

      String textoUsuario = '📷 Fotografía de mi planta.';

      if (pregunta.isNotEmpty) {
        textoUsuario += '\n\n$pregunta';
      }

      mensajes.add({'tipo': 'usuario', 'texto': textoUsuario});

      preguntaController.clear();

      imagenSeleccionada = null;
    });

    bajarChat();

    try {
      debugPrint('====================================');

      debugPrint('ANALIZANDO IMAGEN DE PLANTA');

      debugPrint('Ruta: ${imagen.path}');

      debugPrint('Pregunta: $pregunta');

      debugPrint('====================================');

      final bytes = await imagen.readAsBytes();

      final resultado = await IaService.analizarPlanta(
        imagen: bytes,
        nombreArchivo: imagen.name,
        token: widget.token,
        pregunta: pregunta,
        contextoCaso: _contextoCasoPendiente,
      );

      debugPrint('RESPUESTA ANALISIS PLANTA: $resultado');

      final respuesta =
          resultado['respuesta'] ?? 'No se recibió un análisis de la planta.';

      final idConsulta = resultado['consulta'] != null
          ? resultado['consulta']['id_consulta']
          : null;

      if (!mounted) return;

      setState(() {
        mensajes.add({
          'tipo': 'asistente',
          'texto': respuesta.toString(),
          'idConsulta': idConsulta,
        });

        analizandoImagen = false;
      });

      bajarChat();
    } catch (e) {
      debugPrint('ERROR ANALIZANDO PLANTA: $e');

      if (!mounted) return;

      setState(() {
        mensajes.add({
          'tipo': 'asistente',
          'texto': 'No pude analizar la fotografía de la planta.\n\n$e',
        });

        analizandoImagen = false;
      });

      bajarChat();
    }
  }

  // ============================================================
  // BAJAR CHAT
  // ============================================================

  void bajarChat() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // USAR SUGERENCIA
  // ============================================================

  void usarSugerencia(String texto) {
    if (!mounted) return;

    preguntaController.text = texto;

    preguntaController.selection = TextSelection.fromPosition(
      TextPosition(offset: preguntaController.text.length),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Asistente de Jardinería',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: ScrollConfiguration(
        behavior: AppScrollBehavior(),

        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 5, 20, 10),
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),

              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.leaf,

                    child: Icon(
                      _modoAprendizaje ? Icons.menu_book : Icons.smart_toy,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Asistente de Jardinería',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 3),

                        Text(
                          _modoAprendizaje
                              ? 'Lecciones, evaluaciones y progreso'
                              : 'Especialista en cuidado de plantas',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  if (!_modoAprendizaje)
                    const Icon(Icons.circle, size: 10, color: Colors.green),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.chat_bubble_outline),
                      label: Text('Consultar IA'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.menu_book_outlined),
                      label: Text('Aprender jardinería'),
                    ),
                  ],
                  selected: {_modoAprendizaje},
                  onSelectionChanged: (selection) =>
                      setState(() => _modoAprendizaje = selection.first),
                ),
              ),
            ),

            if (_modoAprendizaje)
              Expanded(child: AprenderJardineriaPage(token: widget.token))
            else ...[
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: cargandoHistorial
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.leaf,
                              ),
                            )
                          : mensajes.isEmpty
                          ? _pantallaInicial()
                          : Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              interactive: true,
                              thickness: 6,
                              radius: const Radius.circular(10),

                              child: ListView.builder(
                                controller: scrollController,

                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),

                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  15,
                                ),

                                itemCount:
                                    mensajes.length +
                                    ((cargando || analizandoImagen) ? 1 : 0),

                                itemBuilder: (context, index) {
                                  if ((cargando || analizandoImagen) &&
                                      index == mensajes.length) {
                                    return _mensajeCargando(
                                      analizandoImagen: analizandoImagen,
                                    );
                                  }

                                  final mensaje = mensajes[index];

                                  return _burbujaMensaje(
                                    tipo: mensaje['tipo'] as String,
                                    texto: mensaje['texto'] as String,
                                    idConsulta: mensaje['idConsulta'] as int?,
                                  );
                                },
                              ),
                            ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: 14,
                      child: IgnorePointer(
                        ignoring: !_mostrarBotonBajar,
                        child: AnimatedSlide(
                          offset: _mostrarBotonBajar
                              ? Offset.zero
                              : const Offset(0, 0.35),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: AnimatedOpacity(
                            opacity: _mostrarBotonBajar ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: FloatingActionButton.small(
                              heroTag: 'chat-scroll-down',
                              tooltip: 'Ir al mensaje más reciente',
                              backgroundColor: AppColors.leaf,
                              foregroundColor: Colors.white,
                              onPressed: bajarChat,
                              child: const Icon(Icons.keyboard_arrow_down),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),

                decoration: const BoxDecoration(
                  color: Colors.white,

                  boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
                ),

                child: SafeArea(
                  top: false,

                  child: Column(
                    children: [
                      if (imagenSeleccionada != null)
                        Container(
                          width: double.infinity,

                          margin: const EdgeInsets.only(bottom: 10),

                          padding: const EdgeInsets.all(8),

                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),

                          child: Row(
                            children: [
                              FutureBuilder(
                                future: imagenSeleccionada!.readAsBytes(),

                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.done &&
                                      snapshot.hasData) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(10),

                                      child: Image.memory(
                                        snapshot.data!,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }

                                  return Container(
                                    width: 70,
                                    height: 70,

                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(10),
                                    ),

                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(width: 10),

                              const Expanded(
                                child: Text(
                                  'Foto de planta seleccionada',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),

                              IconButton(
                                onPressed: () {
                                  if (!mounted) {
                                    return;
                                  }

                                  setState(() {
                                    imagenSeleccionada = null;
                                  });
                                },

                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,

                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.mint,
                              shape: BoxShape.circle,
                            ),

                            child: IconButton(
                              onPressed: (cargando || analizandoImagen)
                                  ? null
                                  : tomarFotoPlanta,

                              tooltip: 'Seleccionar planta',

                              icon: const Icon(
                                Icons.camera_alt,
                                color: AppColors.leaf,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: TextField(
                              controller: preguntaController,

                              minLines: 1,
                              maxLines: 4,

                              decoration: InputDecoration(
                                hintText: imagenSeleccionada != null
                                    ? 'Escribe qué quieres saber...'
                                    : 'Escribe tu pregunta...',

                                filled: true,

                                fillColor: AppColors.background,

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: BorderSide.none,
                                ),

                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),

                              onSubmitted: (_) {
                                enviarMensaje();
                              },
                            ),
                          ),

                          const SizedBox(width: 8),

                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.leaf,
                              shape: BoxShape.circle,
                            ),

                            child: IconButton(
                              onPressed: (cargando || analizandoImagen)
                                  ? null
                                  : enviarMensaje,

                              icon: const Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA INICIAL
  // ============================================================

  Widget _pantallaInicial() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),

      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),

      child: Column(
        children: [
          const SizedBox(height: 15),

          const Icon(Icons.eco, size: 60, color: AppColors.leaf),

          const SizedBox(height: 12),

          const Text(
            '¿En qué puedo ayudarte?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            'Pregúntame sobre riego, plantas, '
            'cuidados y problemas de tu jardín.',
            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade600),
          ),

          const SizedBox(height: 25),

          Container(
            width: double.infinity,

            margin: const EdgeInsets.only(bottom: 10),

            child: OutlinedButton.icon(
              onPressed: (cargando || analizandoImagen)
                  ? null
                  : tomarFotoPlanta,

              icon: const Icon(Icons.camera_alt),

              label: const Text('Seleccionar foto de mi planta'),

              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(15),

                foregroundColor: AppColors.leaf,

                side: const BorderSide(color: AppColors.leaf),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _suggestion('¿Cuándo debo regar mi Croto?'),

          _suggestion('¿Qué cuidados necesita mi planta?'),

          _suggestion('¿Por qué las hojas están amarillas?'),
        ],
      ),
    );
  }

  // ============================================================
  // BURBUJA DE MENSAJE
  // ============================================================

  Widget _burbujaMensaje({
    required String tipo,
    required String texto,
    int? idConsulta,
  }) {
    final bool usuario = tipo == 'usuario';

    final textoNormalizado = texto.toLowerCase();
    final mencionaProblema = RegExp(
      r'\b(manchas?|plaga|hongo|enfermedad|podredumbre|marchit|amarill|dañad|infectad|problem|deficiencia|necrosis|deshidrat|quemad|sequía|carencia|bacteria|virus|falta de riego|exceso de riego)\w*',
    ).hasMatch(textoNormalizado);
    final indicaSalud =
        textoNormalizado.contains('luce saludable') ||
        textoNormalizado.contains('no se observa ningún problema') ||
        textoNormalizado.contains('no parece presentar problemas') ||
        textoNormalizado.contains('no detecto problemas') ||
        textoNormalizado.contains('no requiere tratamiento');
    final tieneProblema =
        !usuario &&
        !indicaSalud &&
        ((texto.contains('🌱 Plan de trabajo:') &&
                !texto.contains('No se requiere ningún plan de trabajo')) ||
            mencionaProblema);

    return Align(
      alignment: usuario ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),

        margin: const EdgeInsets.only(bottom: 12),

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        decoration: BoxDecoration(
          color: usuario ? AppColors.leaf : Colors.white,

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(usuario ? 18 : 4),
            bottomRight: Radius.circular(usuario ? 4 : 18),
          ),

          boxShadow: usuario
              ? null
              : const [BoxShadow(blurRadius: 4, color: Colors.black12)],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(
                  usuario ? Icons.person : Icons.smart_toy,

                  size: 16,

                  color: usuario ? Colors.white70 : AppColors.leaf,
                ),

                const SizedBox(width: 6),

                Text(
                  usuario ? 'Tú' : 'Asistente',

                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,

                    color: usuario ? Colors.white70 : AppColors.leaf,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (usuario)
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.white,
                ),
              )
            else
              MarkdownBody(
                data: texto,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                  strong: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  em: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                  listBullet: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  code: const TextStyle(fontSize: 13, color: Color(0xFF1B5E20)),
                ),
              ),

            if (tieneProblema) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.leaf,
                    side: const BorderSide(color: AppColors.leaf),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.healing_outlined, size: 18),
                  label: const Text('Convertir en Caso de Seguimiento'),
                  onPressed: () => _abrirCaso(texto, idConsulta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ABRIR CASO DE SEGUIMIENTO (a partir de un diagnóstico)
  // ============================================================

  Future<void> _abrirCaso(String texto, int? idConsulta) async {
    String diagnostico = texto;
    String planTrabajo = texto;

    final marcaPlan = '🌱 Plan de trabajo:';
    final indicePlan = texto.indexOf(marcaPlan);

    if (indicePlan != -1) {
      diagnostico = texto
          .substring(0, indicePlan)
          .replaceFirst('🔍 Diagnóstico:', '')
          .trim();
      planTrabajo = texto.substring(indicePlan + marcaPlan.length).trim();
    } else {
      planTrabajo = '';
    }

    try {
      Map<String, dynamic>? planta;
      final idPlantaContextual = widget.idPlanta;
      if (idPlantaContextual != null && idPlantaContextual > 0) {
        planta = {
          'id_planta': idPlantaContextual,
          'nombre': widget.nombrePlanta,
        };
      } else {
        final opcion = await _elegirTipoSeguimiento();
        if (opcion == null || opcion == 'cancelar' || !mounted) return;
        if (opcion == 'asociar') {
          final plantas = await _obtenerPlantasDelUsuario();
          if (!mounted) return;
          if (plantas.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No tienes plantas registradas para asociar.'),
              ),
            );
            return;
          }
          planta = await _elegirPlanta(plantas);
          if (planta == null || !mounted) return;
        }
      }

      final planConfirmado = await _revisarPlan(planTrabajo);
      if (planConfirmado == null || !mounted) return;
      final pasos = prepararPasosCaso(planConfirmado);

      await CasoService.crearCaso(
        token: widget.token,
        idPlanta: planta == null
            ? null
            : int.tryParse(planta['id_planta'].toString()),
        idSector: planta == null
            ? null
            : int.tryParse('${planta['id_sector']}'),
        idConsulta: idConsulta,
        titulo: planta == null
            ? 'Seguimiento general'
            : 'Recuperación: ${planta['nombre'] ?? planta['nombre_comun'] ?? 'Planta'}',
        diagnostico: diagnostico,
        planTrabajo: planConfirmado.trim().isEmpty
            ? 'Sin pasos de tratamiento registrados.'
            : planConfirmado.trim(),
        pasos: pasos,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caso creado. Podrás darle seguimiento desde "Mis Casos".',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear el caso: $e')));
    }
  }

  Future<String?> _elegirTipoSeguimiento() => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Crear ticket de seguimiento'),
      content: const Text(
        'Puedes guardar este diagnóstico como seguimiento general o asociarlo a una planta registrada.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'cancelar'),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'asociar'),
          child: const Text('Asociar a una planta'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'general'),
          child: const Text('Seguimiento general'),
        ),
      ],
    ),
  );

  Future<String?> _revisarPlan(String planInicial) async {
    final controller = TextEditingController(text: planInicial);
    final plan = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final pasos = prepararPasosCaso(controller.text);
          final recordatorios = pasos.where(
            (paso) => paso['recordatorio_fecha'] != null,
          );
          return AlertDialog(
            title: const Text('Revisa el plan de tratamiento'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirma o ajusta cada paso. Solo se programan recordatorios cuando el texto indica un plazo explícito, por ejemplo “revisar en 3 días”.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 4,
                      maxLines: 8,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Pasos propuestos por la IA',
                        hintText: 'Un paso por línea; puedes dejarlo vacío si no hay tratamiento propuesto.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recordatorios.isEmpty
                          ? 'No hay recordatorios propuestos porque el plan no especifica plazos.'
                          : 'Recordatorios que se programarán:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...recordatorios.map((paso) {
                      final fecha = DateTime.parse(
                        paso['recordatorio_fecha'] as String,
                      ).toLocal();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.alarm_add_outlined),
                        title: Text(paso['recordatorio_mensaje'] as String),
                        subtitle: Text(
                          '${fecha.day}/${fecha.month}/${fecha.year}',
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Confirmar plan'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return plan;
  }

  Future<List<Map<String, dynamic>>> _obtenerPlantasDelUsuario() async {
    final jardines = await JardinService.obtenerJardines(token: widget.token);
    final plantasPorId = <int, Map<String, dynamic>>{};
    for (final jardin in jardines) {
      final idJardin = int.tryParse(jardin['id_jardin'].toString());
      if (idJardin == null) continue;
      final sectores = await JardinService.obtenerSectores(
        token: widget.token,
        idJardin: idJardin,
      );
      for (final sector in sectores) {
        final idSector = int.tryParse(sector['id_sector'].toString());
        if (idSector == null) continue;
        final plantasSector = await PlantaService.obtenerPlantasPorSector(
          token: widget.token,
          idSector: idSector,
        );
        for (final planta in plantasSector.whereType<Map>()) {
          final registro = Map<String, dynamic>.from(planta);
          final idPlanta = int.tryParse('${registro['id_planta']}');
          if (idPlanta == null || idPlanta < 1) continue;
          plantasPorId.putIfAbsent(
            idPlanta,
            () => {
              ...registro,
              'id_planta': idPlanta,
              'id_sector': idSector,
              'nombre_sector': sector['nombre'],
              'nombre_jardin': jardin['nombre'],
            },
          );
        }
      }
    }
    return plantasPorId.values.toList();
  }

  Future<Map<String, dynamic>?> _elegirPlanta(
    List<Map<String, dynamic>> plantas,
  ) {
    int? seleccion;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('Vincular planta al ticket'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: plantas.map((planta) {
                  final id = int.parse(planta['id_planta'].toString());
                  final nombre =
                      (planta['nombre'] ?? planta['nombre_comun'] ?? 'Planta')
                          .toString();
                  final especie =
                      (planta['nombre_comun'] ??
                              planta['nombre_cientifico'] ??
                              '')
                          .toString();
                  final ubicacion =
                      [planta['nombre_jardin'], planta['nombre_sector']]
                          .where(
                            (parte) => parte != null && '$parte'.isNotEmpty,
                          )
                          .join(' · ');
                  return ListTile(
                    onTap: () => setDialogState(() => seleccion = id),
                    leading: Icon(
                      seleccion == id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: seleccion == id ? AppColors.leaf : null,
                    ),
                    title: Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (especie.isNotEmpty && especie != nombre) especie,
                        if (ubicacion.isNotEmpty) ubicacion,
                        'ID $id',
                      ].join(' · '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: seleccion == null
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      plantas.firstWhere(
                        (planta) =>
                            int.parse(planta['id_planta'].toString()) ==
                            seleccion,
                      ),
                    ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MENSAJE CARGANDO
  // ============================================================

  Widget _mensajeCargando({required bool analizandoImagen}) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),

        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(18),

          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            const SizedBox(
              width: 18,
              height: 18,

              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.leaf,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              analizandoImagen
                  ? 'Analizando la planta...'
                  : 'El asistente está escribiendo...',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUGERENCIA
  // ============================================================

  Widget _suggestion(String text) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      child: OutlinedButton(
        onPressed: (cargando || analizandoImagen)
            ? null
            : () {
                usarSugerencia(text);
              },

        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(15),

          alignment: Alignment.centerLeft,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        child: Text(text),
      ),
    );
  }
}
