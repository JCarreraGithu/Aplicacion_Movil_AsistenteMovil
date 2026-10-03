import 'package:flutter/material.dart';
import '../services/caso_service.dart';

const Color _verde = Color(0xFF2E7D32);
const Color _fondo = Color(0xFFF5F7F5);

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
                  const SizedBox(height: 100),
                  Icon(
                    Icons.healing_outlined,
                    size: 70,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: Text(
                      'No tienes casos abiertos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Cuando el asistente detecte un problema en\nuna planta, podrás abrir un caso para darle\nseguimiento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
                          caso['nombre_planta'] ?? 'Planta sin registrar',
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
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
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

  const CasoDetallePage({
    super.key,
    required this.token,
    required this.idCaso,
  });

  @override
  State<CasoDetallePage> createState() => _CasoDetallePageState();
}

class _CasoDetallePageState extends State<CasoDetallePage> {
  Map<String, dynamic>? _caso;
  bool _cargando = true;
  final _notaController = TextEditingController();
  bool _enviandoNota = false;

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
      setState(() {
        _caso = caso;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al cargar el caso')));
      }
    }
  }

  Future<void> _agregarSeguimiento() async {
    final nota = _notaController.text.trim();
    if (nota.isEmpty) return;

    setState(() => _enviandoNota = true);
    try {
      await CasoService.agregarSeguimiento(
        token: widget.token,
        idCaso: widget.idCaso,
        nota: nota,
      );
      _notaController.clear();
      await _cargarCaso();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo guardar la nota')));
      }
    } finally {
      setState(() => _enviandoNota = false);
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo actualizar el estado')));
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
    final cerrado = estado == 'resuelto' || estado == 'abandonado';

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        elevation: 0,
        title: Text(
          caso['titulo'] ?? 'Caso',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _bloque('🔍 Diagnóstico', caso['diagnostico']),
                const SizedBox(height: 12),
                _bloque('🌱 Plan de trabajo', caso['plan_trabajo']),
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
                ...seguimientos.map(
                  (s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.notes, color: _verde),
                      title: Text(s['nota'] ?? ''),
                      subtitle: Text(
                        (s['fecha'] ?? '').toString().split('T').first,
                      ),
                    ),
                  ),
                ),
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _notaController,
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
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: _verde),
                          onPressed: _enviandoNota ? null : _agregarSeguimiento,
                          icon: _enviandoNota
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
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
                            onPressed: () => _cambiarEstado('resuelto'),
                            child: const Text('Marcar resuelto'),
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
