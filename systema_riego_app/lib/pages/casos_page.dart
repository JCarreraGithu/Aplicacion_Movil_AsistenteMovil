import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

import '../services/caso_service.dart';
import '../services/caso_contexto.dart';
import '../services/diagnostico_presentacion.dart';
import '../services/avance_flow.dart';
import '../widgets/app_components.dart';
import 'asistente_page.dart';

const Color _verde = AppColors.leaf;
const Color _fondo = AppColors.background;

String _etiquetaEstado(String estado) {
  switch (estado) {
    case 'abierto':
      return 'Abierto';
    case 'en_progreso':
      return 'En progreso';
    case 'resuelto':
      return 'Resuelto';
    case 'abandonado':
      return 'Abandonado';
    default:
      return estado;
  }
}

// ================================================================
// LISTA DE CASOS
// ================================================================

class CasosPage extends StatefulWidget {
  final String token;

  const CasosPage({super.key, required this.token});

  @override
  State<CasosPage> createState() => _CasosPageState();
}

class _CasosPageState extends State<CasosPage> {
  List<dynamic> _casos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCasos();
  }

  Future<void> _cargarCasos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final casos = await CasoService.obtenerCasos(token: widget.token);
      setState(() {
        _casos = casos;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar los casos.';
        _cargando = false;
      });
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'abierto':
        return Colors.orange;
      case 'en_progreso':
        return Colors.blue;
      case 'resuelto':
        return _verde;
      case 'abandonado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        elevation: 0,
        title: const Text(
          'Mis Casos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarCasos,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: _verde))
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(_error!)),
                ],
              )
            : _casos.isEmpty
            ? ListView(
                children: [
                  const SizedBox(
                    height: 420,
                    child: EmptyStatePanel(
                      icon: Icons.healing_outlined,
                      title: 'Aún no hay casos de seguimiento',
                      message: 'Cuando registres una planta que necesita atención, podrás seguir aquí su evolución.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _casos.length,
                itemBuilder: (context, index) {
                  final caso = _casos[index];
                  final estado = caso['estado'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: _colorEstado(estado).withOpacity(0.15),
                        child: Icon(Icons.eco, color: _colorEstado(estado)),
                      ),
                      title: Text(
                        caso['titulo'] ?? 'Sin título',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${caso['nombre_planta'] ?? 'Planta sin registrar'}${caso['nombre_sector'] == null ? '' : ' · ${caso['nombre_sector']}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Chip(
                        label: Text(
                          _etiquetaEstado(estado),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: _colorEstado(estado),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CasoDetallePage(
                              token: widget.token,
                              idCaso: caso['id_caso'],
                            ),
                          ),
                        );
                        _cargarCasos();
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ================================================================
// DETALLE DE UN CASO
// ================================================================

class CasoDetallePage extends StatefulWidget {
  final String token;
  final int idCaso;
  final int? idRecordatorioInicio;

  const CasoDetallePage({
    super.key,
    required this.token,
    required this.idCaso,
    this.idRecordatorioInicio,
  });

  @override
  State<CasoDetallePage> createState() => _CasoDetallePageState();
}

class _CasoDetallePageState extends State<CasoDetallePage> {
  Map<String, dynamic>? _caso;
  bool _cargando = true;
  final _notaController = TextEditingController();
  bool _enviandoNota = false;
  bool _guardandoTarea = false;
  bool _mostrarDiagnosticoCompleto = false;
  XFile? _imagenAvance;
  Uint8List? _imagenAvanceBytes;
  int? _recordatorioSeleccionado;
  int? _tareaEvaluadaSeleccionada;
  bool _inicioRecordatorioProcesado = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarCaso();
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCaso() async {
    setState(() => _cargando = true);
    try {
      final caso = await CasoService.obtenerCasoPorId(
        token: widget.token,
        idCaso: widget.idCaso,
      );
      if (!mounted) return;
      setState(() {
        _caso = caso;
        _cargando = false;
      });
      final idInicio = widget.idRecordatorioInicio;
      if (!_inicioRecordatorioProcesado && idInicio != null) {
        _inicioRecordatorioProcesado = true;
        final recordatorio = _recordatorioPorId(idInicio);
        if (recordatorio != null) _iniciarAvanceDesdeRecordatorio(recordatorio);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al cargar el caso')));
    }
  }

  Future<void> _agregarSeguimiento() async {
    final nota = _notaController.text.trim();
    if (nota.isEmpty || _enviandoNota) return;

    setState(() => _enviandoNota = true);
    try {
      await CasoService.agregarSeguimiento(
        token: widget.token,
        idCaso: widget.idCaso,
        nota: nota,
        imagenBytes: _imagenAvanceBytes,
        nombreImagen: _imagenAvance?.name,
        idRecordatorio: _recordatorioSeleccionado,
      );
      if (!mounted) return;
      _notaController.clear();
      setState(() {
        _imagenAvance = null;
        _imagenAvanceBytes = null;
        _recordatorioSeleccionado = null;
        _tareaEvaluadaSeleccionada = null;
      });
      await _cargarCaso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la nota')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoNota = false);
    }
  }

  Future<void> _guardarYConsultarIA() async {
    final nota = _notaController.text.trim();
    if (nota.isEmpty || _enviandoNota) return;
    final imagen = _imagenAvance;
    final bytes = _imagenAvanceBytes;
    final recordatorioId = _recordatorioSeleccionado;
    final tareaEvaluadaId = _tareaEvaluadaSeleccionada;
    final recordatorio = recordatorioId == null
        ? null
        : _recordatorioPorId(recordatorioId);
    final tareaEvaluada = _tareaPorId(tareaEvaluadaId);
    var avanceGuardado = false;
    int? idSeguimientoGuardado;
    setState(() => _enviandoNota = true);
    try {
      await guardarAntesDeConsultar(
        guardar: () async {
          final seguimiento = await CasoService.agregarSeguimiento(
            token: widget.token,
            idCaso: widget.idCaso,
            nota: nota,
            imagenBytes: bytes,
            nombreImagen: imagen?.name,
            idRecordatorio: recordatorioId,
          );
          avanceGuardado = true;
          idSeguimientoGuardado =
              int.tryParse(seguimiento['id_seguimiento']?.toString() ?? '');
        },
        consultar: () async {
          if (!mounted) return;
          _notaController.clear();
          setState(() {
            _imagenAvance = null;
            _imagenAvanceBytes = null;
            _recordatorioSeleccionado = null;
            _tareaEvaluadaSeleccionada = null;
          });
          final actualizado = await CasoService.obtenerCasoPorId(
            token: widget.token,
            idCaso: widget.idCaso,
          );
          if (!mounted) return;
          setState(() => _caso = actualizado);
          final contexto = construirContextoCaso(
            actualizado,
            seguimientoConFotoIncluida: bytes == null
                ? null
                : idSeguimientoGuardado,
            recordatorioEnEvaluacionId: recordatorioId,
            tareaEnEvaluacionId: tareaEvaluadaId,
          );
          final paso = recordatorio?['tarea_descripcion']?.toString() ??
              tareaEvaluada?['descripcion']?.toString();
          final fecha = recordatorio?['fecha_recordatorio']?.toString() ??
              tareaEvaluada?['fecha_limite']?.toString();
          final seguimientoProgramado = recordatorioId != null || tareaEvaluada != null;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AsistentePage(
                token: widget.token,
                preguntaInicial: !seguimientoProgramado
                    ? 'Analiza el nuevo avance guardado y la evolución completa del caso. Indica si la observación cambia la evaluación o requiere ajustar el plan. No recomiendes cambios sin fundamento.'
                    : 'Evalúa el seguimiento programado${paso == null ? '' : ' para el paso: $paso'}${fecha == null ? '' : ' (fecha: $fecha)'}. Considera la nueva observación y la evolución completa. Puedes recomendar continuar, ajustar o finalizar el tratamiento, pero presenta los cambios como propuestas para confirmar por el usuario. No cierres el caso.',
                contextoCaso: contexto,
                imagenInicialCaso: imagen,
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              avanceGuardado
                  ? 'El avance quedó guardado, pero no se pudo abrir la consulta IA: $e'
                  : 'No se guardó el avance; no se consultó a la IA: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoNota = false);
    }
  }

  void _iniciarAvanceDesdeRecordatorio(Map<String, dynamic> recordatorio) {
    if (recordatorio['activo'] != true || _enviandoNota) return;
    final estadoCaso = _caso?['estado']?.toString();
    if (estadoCaso == 'resuelto' || estadoCaso == 'abandonado') return;
    final id = int.tryParse(recordatorio['id_recordatorio']?.toString() ?? '');
    final idTarea = int.tryParse(recordatorio['id_tarea']?.toString() ?? '');
    setState(() {
      _recordatorioSeleccionado = id;
      _tareaEvaluadaSeleccionada = idTarea;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(id == null
            ? 'Describe el avance del paso: ${recordatorio['tarea_descripcion'] ?? 'seguimiento'}.'
            : 'Describe cómo respondió la planta al seguimiento.'),
      ),
    );
  }

  Map<String, dynamic>? _recordatorioPorId(int id) {
    for (final value in _caso?['recordatorios'] as List<dynamic>? ?? []) {
      if (value is Map &&
          value['id_recordatorio']?.toString() == id.toString()) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  Map<String, dynamic>? _tareaPorId(int? id) {
    if (id == null) return null;
    for (final value in _caso?['tareas'] as List<dynamic>? ?? []) {
      if (value is Map && value['id_tarea']?.toString() == id.toString()) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  Map<String, dynamic>? _recordatorioProximo(
    List<dynamic> recordatorios,
    List<dynamic> tareas,
  ) {
    final activos = recordatorios
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => value['activo'] == true)
        .where((value) => DateTime.tryParse(
              value['fecha_recordatorio']?.toString() ?? '',
            ) != null)
        .toList();
    final tareasConRecordatorio = activos
        .map((item) => item['id_tarea']?.toString())
        .whereType<String>()
        .toSet();
    for (final value in tareas) {
      if (value is! Map) continue;
      final tarea = Map<String, dynamic>.from(value);
      final idTarea = tarea['id_tarea']?.toString();
      final fecha = tarea['fecha_limite']?.toString();
      if (tarea['completada'] == true ||
          fecha == null ||
          DateTime.tryParse(fecha) == null ||
          tareasConRecordatorio.contains(idTarea)) {
        continue;
      }
      activos.add({
        'id_tarea': idTarea,
        'tarea_descripcion': tarea['descripcion']?.toString() ?? '',
        'fecha_recordatorio': fecha,
        'mensaje': 'Seguimiento pendiente del paso',
        'activo': true,
      });
    }
    activos.sort((a, b) => DateTime.parse(
      a['fecha_recordatorio'].toString(),
    ).compareTo(DateTime.parse(b['fecha_recordatorio'].toString())));
    return activos.isEmpty ? null : activos.first;
  }

  String _fechaRecordatorio(Object? valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
    if (fecha == null) return 'Fecha no disponible';
    String dos(int numero) => numero.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} · ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Future<void> _seleccionarImagen() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    try {
      final imagen = await _imagePicker.pickImage(
        source: origen,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (imagen == null) return;
      final bytes = await imagen.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imagenAvance = imagen;
        _imagenAvanceBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo seleccionar la fotografía.'),
          ),
        );
      }
    }
  }

  String _urlImagen(String ruta) =>
      Uri.parse(CasoService.baseUrl).resolve(ruta).toString();

  String? _resultadoFinal(List<dynamic> seguimientos) {
    for (final value in seguimientos.reversed) {
      final nota = Map<String, dynamic>.from(value as Map)['nota']?.toString() ?? '';
      const prefijo = 'Resultado final:';
      if (nota.startsWith(prefijo)) return nota.substring(prefijo.length).trim();
    }
    return null;
  }

  String _fechaHoraBitacora(Object? valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '');
    if (fecha == null) return valor?.toString() ?? '';
    final local = fecha.toLocal();
    String dos(int numero) => numero.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} · ${dos(local.hour)}:${dos(local.minute)}';
  }

  Widget _diagnostico(String texto) {
    final expandible = DiagnosticoPresentacion.necesitaExpandir(texto);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔍 Diagnóstico',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            DiagnosticoPresentacion.textoVisible(
              texto,
              expandido: _mostrarDiagnosticoCompleto,
            ),
            maxLines: _mostrarDiagnosticoCompleto ? null : 3,
            overflow: _mostrarDiagnosticoCompleto
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (expandible)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(
                  () => _mostrarDiagnosticoCompleto =
                      !_mostrarDiagnosticoCompleto,
                ),
                child: Text(
                  _mostrarDiagnosticoCompleto
                      ? 'Ver menos'
                      : 'Ver diagnóstico completo',
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _mostrarImagenCompleta(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.9,
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaProximoSeguimiento(
    Map<String, dynamic> recordatorio,
    Map<String, dynamic> caso,
  ) {
    final planta = caso['nombre_planta']?.toString().trim().isNotEmpty == true
        ? caso['nombre_planta'].toString()
        : 'la planta';
    final fecha = DateTime.tryParse(
      recordatorio['fecha_recordatorio']?.toString() ?? '',
    );
    final tarea = recordatorio['tarea_descripcion']?.toString() ?? '';
    final tareas = caso['tareas'] as List<dynamic>? ?? [];
    final idTarea = recordatorio['id_tarea']?.toString();
    final descripcionTarea = tarea.isNotEmpty
        ? tarea
        : tareas.whereType<Map>().map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id_tarea']?.toString() == idTarea)
            .map((item) => item['descripcion']?.toString() ?? '')
            .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    final ahora = DateTime.now();
    final estado = fecha == null
        ? 'Fecha programada no disponible'
        : fecha.isBefore(ahora)
            ? 'Seguimiento pendiente desde ${_fechaRecordatorio(fecha)}'
            : fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day
                ? 'Hoy · ${_fechaRecordatorio(fecha)}'
                : 'Próximo · ${_fechaRecordatorio(fecha)}';
    return Card(
      color: const Color(0xFFEAF5EC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Próximo seguimiento',
              style: TextStyle(fontWeight: FontWeight.bold, color: _verde),
            ),
            const SizedBox(height: 5),
            Text(
              fecha != null && fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day
                  ? 'Hoy corresponde revisar la evolución de $planta. ¿Cómo ha respondido al tratamiento?'
                  : 'Seguimiento programado para $planta.',
            ),
            if (descripcionTarea.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Paso: $descripcionTarea'),
            ],
            const SizedBox(height: 4),
            Text(estado, style: TextStyle(color: Colors.grey.shade700)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _iniciarAvanceDesdeRecordatorio(recordatorio),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Registrar avance'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(String estado) async {
    try {
      await CasoService.cambiarEstadoCaso(
        token: widget.token,
        idCaso: widget.idCaso,
        estado: estado,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el estado')),
        );
      }
    }
  }

  Future<void> _confirmarCierre() async {
    final resultadoController = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar cierre del caso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registra el resultado observado. La IA no puede cerrar el caso.'),
            const SizedBox(height: 12),
            TextField(
              controller: resultadoController,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Resultado final',
                hintText: 'Describe cómo terminó la recuperación',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final texto = resultadoController.text.trim();
              if (texto.isNotEmpty) Navigator.pop(dialogContext, texto);
            },
            child: const Text('Confirmar cierre'),
          ),
        ],
      ),
    );
    resultadoController.dispose();
    if (resultado == null) return;
    try {
      await CasoService.cerrarCasoConResultado(
        token: widget.token,
        idCaso: widget.idCaso,
        resultado: resultado,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cerrar el caso: $e')),
        );
      }
    }
  }

  Future<void> _consultarIA(Map<String, dynamic> caso) async {
    final contexto = construirContextoCaso(caso);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AsistentePage(
          token: widget.token,
          preguntaInicial: 'Ayúdame a evaluar este caso de recuperación y dime cuál debería ser el siguiente paso, teniendo en cuenta la evolución registrada.',
          contextoCaso: contexto,
        ),
      ),
    );
  }

  Future<void> _agregarTarea() async {
    final controller = TextEditingController();
    final descripcion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Añadir paso de tratamiento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej. Revisar humedad del suelo',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (descripcion == null || descripcion.isEmpty) return;
    setState(() => _guardandoTarea = true);
    try {
      await CasoService.crearTarea(
        token: widget.token,
        idCaso: widget.idCaso,
        descripcion: descripcion,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo añadir el paso: $e')),
        );
    } finally {
      if (mounted) setState(() => _guardandoTarea = false);
    }
  }

  Future<void> _cambiarTarea(
    Map<String, dynamic> tarea,
    bool completada,
  ) async {
    try {
      await CasoService.actualizarTarea(
        token: widget.token,
        idCaso: widget.idCaso,
        idTarea: int.parse(tarea['id_tarea'].toString()),
        completada: completada,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el paso: $e')),
        );
    }
  }

  Future<void> _programarRecordatorio() async {
    final mensajeController = TextEditingController(
      text: 'Revisar el avance del tratamiento',
    );
    var fecha = DateTime.now().add(const Duration(days: 1));
    final resultado = await showDialog<(String, DateTime)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Programar recordatorio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mensajeController,
                decoration: const InputDecoration(labelText: 'Recordatorio'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${fecha.day}/${fecha.month}/${fecha.year} · ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final fechaElegida = await showDatePicker(
                    context: context,
                    initialDate: fecha,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (fechaElegida == null || !context.mounted) return;
                  final hora = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(fecha),
                  );
                  if (hora == null) return;
                  setDialogState(
                    () => fecha = DateTime(
                      fechaElegida.year,
                      fechaElegida.month,
                      fechaElegida.day,
                      hora.hour,
                      hora.minute,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final mensaje = mensajeController.text.trim();
                if (mensaje.isNotEmpty)
                  Navigator.pop(dialogContext, (mensaje, fecha));
              },
              child: const Text('Programar'),
            ),
          ],
        ),
      ),
    );
    mensajeController.dispose();
    if (resultado == null) return;
    try {
      await CasoService.crearRecordatorio(
        token: widget.token,
        idCaso: widget.idCaso,
        mensaje: resultado.$1,
        fecha: resultado.$2,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo programar: $e')));
    }
  }

  Future<void> _cerrarRecordatorio(int idRecordatorio) async {
    try {
      await CasoService.cerrarRecordatorio(
        token: widget.token,
        idCaso: widget.idCaso,
        idRecordatorio: idRecordatorio,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cerrar el recordatorio: $e')),
        );
    }
  }

  Future<void> _editarRecordatorio(Map<String, dynamic> recordatorio) async {
    final id = int.tryParse(recordatorio['id_recordatorio'].toString());
    if (id == null) return;
    final mensajeController = TextEditingController(
      text: recordatorio['mensaje']?.toString() ?? '',
    );
    var fecha = DateTime.tryParse(
          recordatorio['fecha_recordatorio']?.toString() ?? '',
        )?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    final cambios = await showDialog<(String, DateTime)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modificar recordatorio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mensajeController,
                decoration: const InputDecoration(labelText: 'Recordatorio'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text('${fecha.day}/${fecha.month}/${fecha.year}'),
                onPressed: () async {
                  final elegida = await showDatePicker(
                    context: context,
                    initialDate: fecha,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (elegida == null || !context.mounted) return;
                  final hora = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(fecha),
                  );
                  if (hora == null) return;
                  setDialogState(() {
                    fecha = DateTime(elegida.year, elegida.month, elegida.day, hora.hour, hora.minute);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final mensaje = mensajeController.text.trim();
                if (mensaje.isNotEmpty && fecha.isAfter(DateTime.now())) {
                  Navigator.pop(dialogContext, (mensaje, fecha));
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
    mensajeController.dispose();
    if (cambios == null) return;
    try {
      await CasoService.actualizarRecordatorio(
        token: widget.token,
        idCaso: widget.idCaso,
        idRecordatorio: id,
        mensaje: cambios.$1,
        fecha: cambios.$2,
      );
      await _cargarCaso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo modificar el recordatorio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: _fondo,
        body: Center(child: CircularProgressIndicator(color: _verde)),
      );
    }

    if (_caso == null) {
      return const Scaffold(
        backgroundColor: _fondo,
        body: Center(child: Text('Caso no encontrado')),
      );
    }

    final caso = _caso!;
    final estado = caso['estado'] as String;
    final seguimientos = caso['seguimientos'] as List<dynamic>;
    final tareas = caso['tareas'] as List<dynamic>? ?? [];
    final recordatorios = caso['recordatorios'] as List<dynamic>? ?? [];
    final recordatorioProximo = _recordatorioProximo(recordatorios, tareas);
    final planTrabajo = caso['plan_trabajo']?.toString().trim() ?? '';
    final planGenerico = RegExp(
      r'definir seguimiento y tratamiento recomendado|sin pasos de tratamiento registrados|no se requiere ningún plan de trabajo',
      caseSensitive: false,
    ).hasMatch(planTrabajo);
    final resultadoFinal = _resultadoFinal(seguimientos);
    final cerrado = estado == 'resuelto' || estado == 'abandonado';

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        elevation: 0,
        title: Text(
          caso['titulo'] ?? 'Caso',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _bloque(
                  '🌿 Planta y ubicación',
                  '${caso['nombre_planta'] ?? 'Planta sin vincular'}\n'
                  'Especie: ${caso['especie_nombre_comun'] ?? 'No registrada'}'
                  '${caso['especie_nombre_cientifico'] == null ? '' : ' (${caso['especie_nombre_cientifico']})'}\n'
                  'Jardín/sector: ${caso['nombre_jardin'] ?? 'No registrado'} / ${caso['nombre_sector'] ?? 'No registrado'}',
                ),
                const SizedBox(height: 10),
                _bloque('Estado', _etiquetaEstado(estado)),
                const SizedBox(height: 10),
                _bloque('Problema registrado', caso['titulo']?.toString()),
                const SizedBox(height: 10),
                _diagnostico(caso['diagnostico']?.toString() ?? ''),
                if (recordatorioProximo != null && !cerrado) ...[
                  const SizedBox(height: 10),
                  _tarjetaProximoSeguimiento(recordatorioProximo, caso),
                ],
                if (resultadoFinal != null && resultadoFinal.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _bloque('Resultado final', resultadoFinal),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _consultarIA(caso),
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Consultar a la IA sobre este caso'),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '🌱 Plan de trabajo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _guardandoTarea ? null : _agregarTarea,
                      icon: const Icon(Icons.add_circle, color: _verde),
                    ),
                  ],
                ),
                if (tareas.isEmpty && planTrabajo.isNotEmpty && !planGenerico)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(planTrabajo),
                  )
                else if (tareas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No hay pasos de tratamiento registrados para este caso.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ...tareas.map((value) {
                  final tarea = Map<String, dynamic>.from(value as Map);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _verde,
                    value: tarea['completada'] == true,
                    title: Text(
                      tarea['descripcion']?.toString() ?? '',
                      style: TextStyle(
                        decoration: tarea['completada'] == true
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: tarea['fecha_limite'] == null
                        ? null
                        : Text('Plazo: ${_fechaRecordatorio(tarea['fecha_limite'])}'),
                    onChanged: cerrado
                        ? null
                        : (value) => _cambiarTarea(tarea, value ?? false),
                  );
                }),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recordatorios',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: cerrado ? null : _programarRecordatorio,
                      icon: const Icon(Icons.alarm_add, color: _verde),
                    ),
                  ],
                ),
                ...(recordatorios.map((value) {
                  final recordatorio = Map<String, dynamic>.from(value as Map);
                  final activo = recordatorio['activo'] == true;
                  final idRecordatorio = int.tryParse(
                    recordatorio['id_recordatorio'].toString(),
                  );
                  return Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          onTap: activo && !cerrado
                              ? () => _iniciarAvanceDesdeRecordatorio(recordatorio)
                              : null,
                          leading: Icon(
                            activo ? Icons.alarm : Icons.alarm_off,
                            color: activo ? _verde : Colors.grey,
                          ),
                          title: Text(
                            recordatorio['mensaje']?.toString() ?? 'Recordatorio',
                          ),
                          subtitle: Text(
                            _fechaRecordatorio(recordatorio['fecha_recordatorio']),
                          ),
                          trailing: activo && idRecordatorio != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Modificar o posponer',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: cerrado
                                          ? null
                                          : () => _editarRecordatorio(recordatorio),
                                    ),
                                    IconButton(
                                      tooltip: 'Cancelar recordatorio',
                                      icon: const Icon(Icons.notifications_off_outlined),
                                      onPressed: () =>
                                          _cerrarRecordatorio(idRecordatorio),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        if (activo && !cerrado)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _iniciarAvanceDesdeRecordatorio(recordatorio),
                              icon: const Icon(Icons.note_add_outlined),
                              label: const Text('Registrar avance de este seguimiento'),
                            ),
                          ),
                      ],
                    ),
                  );
                })),
                const SizedBox(height: 20),
                const Text(
                  'Bitácora de seguimiento',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (seguimientos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Aún no has agregado avances de este caso.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ...seguimientos.map((s) {
                  final idRecordatorioAvance = int.tryParse(
                    s['id_recordatorio']?.toString() ?? '',
                  );
                  final recordatorioAvance = idRecordatorioAvance == null
                      ? null
                      : _recordatorioPorId(idRecordatorioAvance);
                  final origenSeguimiento = idRecordatorioAvance == null
                      ? 'OBSERVACIÓN'
                      : 'SEGUIMIENTO · ${recordatorioAvance?['mensaje'] ?? 'recordatorio #$idRecordatorioAvance'}';
                  final imagenRuta = s['imagen_url']?.toString();
                  final imagenUrl = imagenRuta == null || imagenRuta.isEmpty
                      ? null
                      : _urlImagen(imagenRuta);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(right: 10, top: 2),
                                child: Icon(Icons.notes, color: _verde),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$origenSeguimiento · ${_fechaHoraBitacora(s['fecha'])}',
                                      style: TextStyle(
                                        color: _verde,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(s['nota'] ?? ''),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (imagenUrl != null) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: GestureDetector(
                                onTap: () => _mostrarImagenCompleta(imagenUrl),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 340,
                                    maxHeight: 240,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    imagenUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                          height: 100,
                                          child: Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 90),
              ],
            ),
          ),
          if (!cerrado)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (_recordatorioSeleccionado != null ||
                        _tareaEvaluadaSeleccionada != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          avatar: const Icon(Icons.alarm, size: 18),
                          label: Text(
                            _recordatorioSeleccionado != null
                                ? 'Avance del seguimiento: ${_recordatorioPorId(_recordatorioSeleccionado!)?['mensaje'] ?? 'recordatorio'}'
                                : 'Avance del paso: ${_tareaPorId(_tareaEvaluadaSeleccionada)?['descripcion'] ?? 'tarea'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => setState(
                            () {
                              _recordatorioSeleccionado = null;
                              _tareaEvaluadaSeleccionada = null;
                            },
                          ),
                        ),
                      ),
                    ],
                    if (_imagenAvanceBytes != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _imagenAvanceBytes!,
                                width: 92,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _imagenAvance = null;
                                  _imagenAvanceBytes = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Adjuntar fotografía',
                          onPressed: _enviandoNota ? null : _seleccionarImagen,
                          icon: const Icon(Icons.add_a_photo, color: _verde),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _notaController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Agregar avance del caso...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _enviandoNota ||
                                    _notaController.text.trim().isEmpty
                                ? null
                                : _agregarSeguimiento,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar avance'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _verde,
                            ),
                            onPressed: _enviandoNota ||
                                    _notaController.text.trim().isEmpty
                                ? null
                                : _guardarYConsultarIA,
                            icon: _enviandoNota
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.smart_toy_outlined),
                            label: const Text('Guardar y consultar IA'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (estado == 'abierto')
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cambiarEstado('en_progreso'),
                              child: const Text('Marcar en progreso'),
                            ),
                          ),
                        if (estado == 'abierto') const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _verde,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _confirmarCierre,
                            child: const Text('Cerrar caso y registrar resultado'),
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
    );
  }

  Widget _bloque(String titulo, String? contenido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(contenido ?? ''),
        ],
      ),
    );
  }
}
