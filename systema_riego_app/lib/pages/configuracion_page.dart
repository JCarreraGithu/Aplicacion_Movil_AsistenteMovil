import 'package:flutter/material.dart';

import '../services/actuador_configuracion_service.dart';
import '../services/jardin_service.dart';

class ConfiguracionPage extends StatefulWidget {
  final String token;

  const ConfiguracionPage({super.key, required this.token});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  List<dynamic> jardines = [];
  List<dynamic> sectores = [];
  List<dynamic> actuadores = [];
  int? idJardin;
  int? idSector;
  bool cargando = true;
  bool guardandoActuador = false;
  String? error;
  bool notificaciones = true;
  bool modoAutomatico = true;

  @override
  void initState() {
    super.initState();
    _cargarJardines();
  }

  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');

  Future<void> _cargarJardines() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final resultado = await JardinService.obtenerJardines(token: widget.token);
      if (!mounted) return;
      setState(() {
        jardines = resultado;
        idJardin = resultado.isEmpty ? null : _id(resultado.first['id_jardin']);
      });
      if (idJardin != null) await _cargarSectores(idJardin!);
      else if (mounted) setState(() => cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  Future<void> _cargarSectores(int jardinId) async {
    setState(() {
      cargando = true;
      error = null;
      sectores = [];
      actuadores = [];
      idSector = null;
    });
    try {
      final resultado = await JardinService.obtenerSectores(
        token: widget.token,
        idJardin: jardinId,
      );
      if (!mounted) return;
      setState(() {
        sectores = resultado;
        idSector = resultado.isEmpty ? null : _id(resultado.first['id_sector']);
      });
      if (idSector != null) await _cargarSector(idSector!);
      else if (mounted) setState(() => cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  Future<void> _cargarSector(int sectorId) async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final resultado = await Future.wait([
        ActuadorConfiguracionService.obtenerActuadores(
          token: widget.token,
          idSector: sectorId,
        ),
        ActuadorConfiguracionService.obtenerConfiguracion(
          token: widget.token,
          idSector: sectorId,
        ),
      ]);
      if (!mounted) return;
      final config = resultado[1] as Map<String, dynamic>?;
      setState(() {
        actuadores = resultado[0] as List<dynamic>;
        if (config?['modo_automatico'] != null) {
          modoAutomatico = config!['modo_automatico'] == true ||
              config['modo_automatico'].toString() == 'true';
        }
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  Future<void> _cambiarEstado(int index, bool encendido) async {
    final actuador = actuadores[index] as Map<String, dynamic>;
    final id = _id(actuador['id_actuador']);
    if (id == null || guardandoActuador) return;
    setState(() => guardandoActuador = true);
    try {
      final actualizado = await ActuadorConfiguracionService.actualizarEstado(
        token: widget.token,
        idActuador: id,
        encendido: encendido,
      );
      if (!mounted) return;
      setState(() => actuadores[index] = {...actuador, ...actualizado});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar la bomba: $e')),
      );
    } finally {
      if (mounted) setState(() => guardandoActuador = false);
    }
  }

  bool _estaEncendido(dynamic estado) {
    final value = estado.toString().toLowerCase();
    return value == 'encendido' || value == 'on' || value == 'true' || value == '1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : error != null
              ? _mensajeError()
              : _contenido(),
    );
  }

  Widget _mensajeError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _cargarJardines, child: const Text('Reintentar')),
          ]),
        ),
      );

  Widget _contenido() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Riego', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          const SizedBox(height: 10),
          if (jardines.isEmpty)
            _settingCard(Icons.grass, 'Jardines', 'Aún no tienes jardines registrados', const SizedBox.shrink())
          else
            _selector<int>(
              label: 'Jardín',
              value: idJardin,
              items: jardines,
              idKey: 'id_jardin',
              labelKey: 'nombre',
              onChanged: (value) { if (value != null) { setState(() => idJardin = value); _cargarSectores(value); } },
            ),
          if (jardines.isNotEmpty && sectores.isNotEmpty)
            _selector<int>(
              label: 'Sector',
              value: idSector,
              items: sectores,
              idKey: 'id_sector',
              labelKey: 'nombre',
              onChanged: (value) { if (value != null) { setState(() => idSector = value); _cargarSector(value); } },
            ),
          const SizedBox(height: 10),
          _settingCard(
            Icons.auto_mode,
            'Modo automático',
            'Estado registrado para el sector seleccionado',
            Switch(value: modoAutomatico, onChanged: null),
          ),
          const SizedBox(height: 10),
          _settingCard(
            Icons.notifications_outlined,
            'Notificaciones',
            'Recibir alertas del sistema',
            Switch(value: notificaciones, onChanged: (value) => setState(() => notificaciones = value)),
          ),
          const SizedBox(height: 25),
          const Text('Bombas y actuadores', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          const SizedBox(height: 10),
          if (idSector == null)
            _settingCard(Icons.water, 'Sin sectores', 'Selecciona un jardín que tenga sectores', const SizedBox.shrink())
          else if (actuadores.isEmpty)
            _settingCard(Icons.water, 'Sin actuadores', 'Este sector no tiene bombas registradas', const SizedBox.shrink())
          else
            ...actuadores.asMap().entries.map((entry) {
              final actuator = entry.value as Map<String, dynamic>;
              final title = (actuator['tipo_actuador'] ?? actuator['codigo'] ?? 'Bomba').toString();
              final on = _estaEncendido(actuator['estado']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _settingCard(
                  Icons.water,
                  title,
                  '${actuator['codigo'] ?? 'Actuador'} · ${on ? 'Encendida' : 'Apagada'}',
                  Switch(value: on, onChanged: guardandoActuador ? null : (value) => _cambiarEstado(entry.key, value)),
                ),
              );
            }),
        ],
      );

  Widget _selector<T>({
    required String label,
    required T? value,
    required List<dynamic> items,
    required String idKey,
    required String labelKey,
    required ValueChanged<T?> onChanged,
  }) {
    final validValue = items.any((item) => _id(item[idKey]) == value) ? value : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: DropdownButtonFormField<T>(
        value: validValue,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        items: items.map((item) => DropdownMenuItem<T>(
          value: _id(item[idKey]) as T?,
          child: Text((item[labelKey] ?? '$label sin nombre').toString()),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _settingCard(IconData icon, String title, String subtitle, Widget trailing) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 26),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ])),
          trailing,
        ]),
      );
}
