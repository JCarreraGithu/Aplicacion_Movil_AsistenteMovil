import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ia_service.dart';
import '../services/caso_service.dart';
import '../services/jardin_service.dart';
import '../services/planta_service.dart';

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

  const AsistentePage({
    super.key,
    required this.token,
    this.preguntaInicial,
    this.contextoCaso,
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
  String? _contextoCasoPendiente;

  XFile? imagenSeleccionada;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    _contextoCasoPendiente = widget.contextoCaso;

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
    scrollController.dispose();
    super.dispose();
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
        _contextoCasoPendiente = null;
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
      backgroundColor: const Color(0xFFF5F7F5),

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
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),

              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFF2E7D32),

                    child: Icon(Icons.smart_toy, color: Colors.white, size: 28),
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
                          'Especialista en cuidado de plantas',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  Icon(Icons.circle, size: 10, color: Colors.green),
                ],
              ),
            ),

            Expanded(
              child: cargandoHistorial
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
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

                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),

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
                          color: const Color(0xFFF5F7F5),
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
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),

                          child: IconButton(
                            onPressed: (cargando || analizandoImagen)
                                ? null
                                : tomarFotoPlanta,

                            tooltip: 'Seleccionar planta',

                            icon: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFF2E7D32),
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

                              fillColor: const Color(0xFFF5F7F5),

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
                            color: Color(0xFF2E7D32),
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

          const Icon(Icons.eco, size: 60, color: Color(0xFF2E7D32)),

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

                foregroundColor: const Color(0xFF2E7D32),

                side: const BorderSide(color: Color(0xFF2E7D32)),

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
          color: usuario ? const Color(0xFF2E7D32) : Colors.white,

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

                  color: usuario ? Colors.white70 : const Color(0xFF2E7D32),
                ),

                const SizedBox(width: 6),

                Text(
                  usuario ? 'Tú' : 'Asistente',

                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,

                    color: usuario ? Colors.white70 : const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              texto,

              style: TextStyle(
                fontSize: 15,
                height: 1.45,

                color: usuario ? Colors.white : Colors.black87,
              ),
            ),

            if (tieneProblema) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
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
      planTrabajo =
          'Definir seguimiento y tratamiento recomendado con el asistente.';
    }

    try {
      final plantas = await _obtenerPlantasDelUsuario();
      if (!mounted) return;
      if (plantas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registra primero la planta en un sector para vincularla al caso.',
            ),
          ),
        );
        return;
      }
      final planta = await _elegirPlanta(plantas);
      if (planta == null || !mounted) return;

      await CasoService.crearCaso(
        token: widget.token,
        idPlanta: int.tryParse(planta['id_planta'].toString()),
        idSector: int.tryParse(planta['id_sector'].toString()),
        idConsulta: idConsulta,
        titulo:
            'Recuperación: ${planta['nombre'] ?? planta['nombre_comun'] ?? 'Planta'}',
        diagnostico: diagnostico,
        planTrabajo: planTrabajo,
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

  Future<List<Map<String, dynamic>>> _obtenerPlantasDelUsuario() async {
    final jardines = await JardinService.obtenerJardines(token: widget.token);
    final plantas = <Map<String, dynamic>>[];
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
        plantas.addAll(
          plantasSector.whereType<Map>().map(
            (planta) => {
              ...Map<String, dynamic>.from(planta),
              'id_sector': idSector,
              'nombre_sector': sector['nombre'],
              'nombre_jardin': jardin['nombre'],
            },
          ),
        );
      }
    }
    return plantas;
  }

  Future<Map<String, dynamic>?> _elegirPlanta(
    List<Map<String, dynamic>> plantas,
  ) {
    int? seleccion = int.tryParse(plantas.first['id_planta'].toString());
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vincular planta al caso'),
          content: DropdownButtonFormField<int>(
            value: seleccion,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Planta afectada'),
            items: plantas
                .map((planta) {
                  final id = int.tryParse(planta['id_planta'].toString());
                  final nombre =
                      (planta['nombre'] ?? planta['nombre_comun'] ?? 'Planta')
                          .toString();
                  final sector = (planta['nombre_sector'] ?? '').toString();
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text('$nombre${sector.isEmpty ? '' : ' · $sector'}'),
                  );
                })
                .where((item) => item.value != null)
                .toList(),
            onChanged: (value) => setDialogState(() => seleccion = value),
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
                        (p) =>
                            p['id_planta'].toString() == seleccion.toString(),
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
                color: Color(0xFF2E7D32),
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
