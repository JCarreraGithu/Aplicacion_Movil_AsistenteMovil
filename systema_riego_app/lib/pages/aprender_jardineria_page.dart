import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/capacitacion_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class AprenderJardineriaPage extends StatefulWidget {
  final String token;
  final CapacitacionService? service;

  const AprenderJardineriaPage({super.key, required this.token, this.service});

  @override
  State<AprenderJardineriaPage> createState() => _AprenderJardineriaPageState();
}

class _AprenderJardineriaPageState extends State<AprenderJardineriaPage> {
  late final CapacitacionService _service =
      widget.service ?? CapacitacionService(token: widget.token);
  late Future<List<CapacitacionModulo>> _modulosFuture;
  late Future<List<CapacitacionProgreso>> _progresoFuture;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _modulosFuture = _service.obtenerModulos();
    _progresoFuture = _service.obtenerProgreso();
  }

  Future<void> _reintentar() async {
    setState(_cargar);
  }

  Future<void> _abrirModulo(CapacitacionModulo modulo) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(name: _rutaModulo(modulo.id)),
        builder: (_) => _ModuloCapacitacionPage(
          modulo: modulo,
          service: _service,
          rutaModulo: _rutaModulo(modulo.id),
        ),
      ),
    );
    if (mounted) setState(_cargar);
  }

  String _resumenProgreso(
    CapacitacionModulo modulo,
    List<CapacitacionProgreso> progreso,
  ) {
    final lecciones = progreso.where((item) => item.idModulo == modulo.id);
    final completadas = lecciones
        .where((item) => item.estado == 'completado')
        .length;
    return '$completadas de ${modulo.totalLecciones} lecciones completadas';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Elige tu aventura',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('capacitacion-progreso'),
              tooltip: 'Ver mi progreso',
              onPressed: _abrirProgreso,
              icon: const Icon(Icons.insights_outlined),
            ),
            IconButton(
              tooltip: 'Actualizar catálogo',
              onPressed: _reintentar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<CapacitacionModulo>>(
          future: _modulosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorCapacitacion(
                error: snapshot.error,
                onRetry: _reintentar,
              );
            }
            final modulos = snapshot.data ?? const <CapacitacionModulo>[];
            if (modulos.isEmpty) {
              return EmptyStatePanel(
                icon: Icons.menu_book_outlined,
                title: 'Aún no hay cursos publicados',
                message: 'Cuando haya módulos educativos disponibles aparecerán aquí.',
                action: OutlinedButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              );
            }

            return FutureBuilder<List<CapacitacionProgreso>>(
              future: _progresoFuture,
              builder: (context, progressSnapshot) {
                final progreso =
                    progressSnapshot.data ?? const <CapacitacionProgreso>[];
                return ListView.separated(
                  key: const ValueKey('capacitacion-catalogo'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: modulos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final modulo = modulos[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _abrirModulo(modulo),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: AppColors.mint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  color: AppColors.leaf,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      modulo.titulo,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(modulo.descripcion),
                                    const SizedBox(height: 8),
                                    Text(
                                      progressSnapshot.hasError
                                          ? 'Progreso no disponible'
                                          : progressSnapshot.connectionState !=
                                                ConnectionState.done
                                          ? 'Cargando progreso…'
                                          : _resumenProgreso(modulo, progreso),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Future<void> _abrirProgreso() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ProgresoCapacitacionPage(service: _service),
      ),
    );
    if (mounted) setState(_cargar);
  }
}

String _rutaModulo(int id) => 'capacitacion-modulo-$id';

class _ModuloCapacitacionPage extends StatefulWidget {
  final CapacitacionModulo modulo;
  final CapacitacionService service;
  final String rutaModulo;

  const _ModuloCapacitacionPage({
    required this.modulo,
    required this.service,
    required this.rutaModulo,
  });

  @override
  State<_ModuloCapacitacionPage> createState() =>
      _ModuloCapacitacionPageState();
}

class _ModuloCapacitacionPageState extends State<_ModuloCapacitacionPage> {
  late Future<List<CapacitacionLeccionResumen>> _future;
  late Future<List<CapacitacionRuta>> _rutasFuture;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = widget.service.obtenerLecciones(widget.modulo.id);
    _rutasFuture = widget.service.obtenerRutasModulo(widget.modulo.id);
  }

  Future<void> _abrirLeccion(CapacitacionLeccionResumen resumen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _LeccionCapacitacionPage(
          resumen: resumen,
          service: widget.service,
          rutaModulo: widget.rutaModulo,
        ),
      ),
    );
    if (mounted) setState(_cargar);
  }

  Future<void> _abrirRuta(CapacitacionRuta ruta) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _DesafioCapacitacionPage(ruta: ruta, service: widget.service),
      ),
    );
    if (mounted) setState(_cargar);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.modulo.titulo)),
    body: FutureBuilder<List<CapacitacionLeccionResumen>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorCapacitacion(
            error: snapshot.error,
            onRetry: () => setState(_cargar),
          );
        }
        final lecciones = snapshot.data ?? const <CapacitacionLeccionResumen>[];
        return FutureBuilder<List<CapacitacionRuta>>(
          future: _rutasFuture,
          builder: (context, routeSnapshot) {
            final rutas = routeSnapshot.data ?? const <CapacitacionRuta>[];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (routeSnapshot.hasError)
                  Card(
                    color: AppColors.mint,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'El camino interactivo necesita la migración de capacitación gamificada. Las lecciones publicadas siguen disponibles abajo.',
                      ),
                    ),
                  )
                else if (routeSnapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (rutas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'El camino interactivo está pendiente de revisión y publicación.',
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Tu aventura de jardinería',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('Completa desafíos cortos y ayuda a crecer tu planta.'),
                  const SizedBox(height: 14),
                  for (final ruta in rutas) ...[
                    _CaminoCapacitacionCard(
                      ruta: ruta,
                      onStart: () => _abrirRuta(ruta),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 10),
                const SizedBox(height: 8),
                Card(
                  child: ExpansionTile(
                    key: const ValueKey('material-consulta'),
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Material de consulta'),
                    subtitle: const Text(
                      'Lecciones y evaluaciones tradicionales',
                    ),
                    children: [
                      if (lecciones.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Todavía no hay lecciones publicadas.'),
                        )
                      else
                        for (final leccion in lecciones)
                          ListTile(
                            key: ValueKey('leccion-${leccion.id}'),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.mint,
                              foregroundColor: AppColors.forest,
                              child: Text('${leccion.orden}'),
                            ),
                            title: Text(leccion.titulo),
                            subtitle: Text(
                              '${_estadoVisible(leccion.estadoProgreso)} · ${leccion.objetivo}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _abrirLeccion(leccion),
                          ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _CaminoCapacitacionCard extends StatelessWidget {
  final CapacitacionRuta ruta;
  final VoidCallback onStart;

  const _CaminoCapacitacionCard({required this.ruta, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final terminadas = ruta.actividades.where((item) => item.completada).length;
    final siguienteIndice = ruta.actividades.indexWhere(
      (item) => !item.completada,
    );
    final siguiente = siguienteIndice < 0
        ? null
        : ruta.actividades[siguienteIndice];
    final avance = ruta.actividades.isEmpty
        ? 0.0
        : terminadas / ruta.actividades.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('camino-${ruta.id}'),
        onTap: siguiente == null ? null : onStart,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlantaVirtual(progreso: avance, tamano: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVENTURA',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                letterSpacing: 1.2,
                                color: AppColors.forest,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ruta.titulo,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.stars_rounded, color: Colors.amber),
                  Text(' ${ruta.xpGanado} XP'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '¡Tu planta ya creció ${_porcentaje(avance)}%!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: avance, minHeight: 9),
              ),
              const SizedBox(height: 8),
              Text(
                '$terminadas de ${ruta.actividades.length} desafíos · ${ruta.xpTotal} XP disponibles',
              ),
              const SizedBox(height: 12),
              if (ruta.actividades.isNotEmpty)
                for (var index = 0; index < ruta.actividades.length; index++)
                  _NivelCamino(
                    actividad: ruta.actividades[index],
                    completado: ruta.actividades[index].completada,
                    disponible: index == siguienteIndice,
                    numero: index + 1,
                    ultimo: index == ruta.actividades.length - 1,
                  ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: siguiente == null ? null : onStart,
                  icon: Icon(
                    siguiente == null
                        ? Icons.verified
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    siguiente == null
                        ? 'Camino completado'
                        : 'Continuar desafío',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _porcentaje(double avance) => (avance * 100).round();

class _NivelCamino extends StatelessWidget {
  final CapacitacionActividad actividad;
  final bool completado;
  final bool disponible;
  final int numero;
  final bool ultimo;

  const _NivelCamino({
    required this.actividad,
    required this.completado,
    required this.disponible,
    required this.numero,
    required this.ultimo,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 42,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: completado
                    ? AppColors.leaf
                    : disponible
                    ? AppColors.mint
                    : Colors.black12,
                shape: BoxShape.circle,
                border: Border.all(
                  color: disponible ? AppColors.forest : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                completado
                    ? Icons.check_rounded
                    : disponible
                    ? _iconoActividad(actividad.icono)
                    : Icons.lock_outline,
                color: completado ? Colors.white : AppColors.forest,
                size: 19,
              ),
            ),
            if (!ultimo)
              Container(
                width: 3,
                height: 28,
                color: completado ? AppColors.leaf : Colors.black12,
              ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nivel $numero · ${actividad.titulo}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                completado
                    ? 'Completado · ${actividad.xp} XP'
                    : disponible
                    ? 'Disponible ahora · ${actividad.xp} XP'
                    : 'Bloqueado',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: disponible ? AppColors.forest : null),
              ),
            ],
          ),
        ),
      ),
      if (completado)
        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
    ],
  );
}

class PlantaVirtual extends StatelessWidget {
  final double progreso;
  final double tamano;

  const PlantaVirtual({super.key, required this.progreso, this.tamano = 80});

  @override
  Widget build(BuildContext context) {
    final scale = 0.62 + progreso.clamp(0.0, 1.0).toDouble() * 0.38;
    return SizedBox(
      key: const ValueKey('planta-virtual'),
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: tamano * .58,
            height: tamano * .34,
            decoration: BoxDecoration(
              color: const Color(0xFFB8794A),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(tamano * .14),
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: tamano * .07,
                decoration: BoxDecoration(
                  color: const Color(0xFF8D5A38),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: tamano * .26,
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: tamano * .72,
                height: tamano * .67,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 4,
                      height: tamano * .53,
                      color: AppColors.forest,
                    ),
                    Positioned(
                      left: 3,
                      bottom: tamano * .25,
                      child: Icon(
                        Icons.eco,
                        size: tamano * .34,
                        color: AppColors.leaf,
                      ),
                    ),
                    Positioned(
                      right: 1,
                      bottom: tamano * .38,
                      child: Transform.scale(
                        scaleX: -1,
                        child: Icon(
                          Icons.eco,
                          size: tamano * .32,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    if (progreso >= .5)
                      Positioned(
                        top: 0,
                        child: Icon(
                          Icons.eco,
                          size: tamano * .3,
                          color: AppColors.leaf,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesafioCapacitacionPage extends StatefulWidget {
  final CapacitacionRuta ruta;
  final CapacitacionService service;

  const _DesafioCapacitacionPage({required this.ruta, required this.service});

  @override
  State<_DesafioCapacitacionPage> createState() =>
      _DesafioCapacitacionPageState();
}

class _DesafioCapacitacionPageState extends State<_DesafioCapacitacionPage> {
  late final List<CapacitacionActividad> _actividades = widget.ruta.actividades;
  late final Set<int> _completadas = _actividades
      .where((item) => item.completada)
      .map((item) => item.id)
      .toSet();
  late int _indice = _primerPendiente();
  List<CapacitacionOpcion> _ordenActual = [];
  String? _seleccion;
  String? _clavePendiente;
  String? _respuestaPendiente;
  String? _error;
  bool _enviando = false;
  CapacitacionRespuestaActividad? _resultado;
  int _xpTotal;

  _DesafioCapacitacionPageState() : _xpTotal = 0;

  int _primerPendiente() {
    final index = _actividades.indexWhere((item) => !item.completada);
    return index < 0 ? _actividades.length : index;
  }

  @override
  void initState() {
    super.initState();
    _xpTotal = widget.ruta.xpGanado;
    if (_indice < _actividades.length) _prepararOrden();
  }

  void _prepararOrden() {
    final actividad = _actual;
    if (actividad?.tipo == 'ordenar_pasos') {
      _ordenActual = List<CapacitacionOpcion>.of(actividad!.opciones);
    }
  }

  CapacitacionActividad? get _actual =>
      _indice < _actividades.length ? _actividades[_indice] : null;

  void _cambiarActividad(int index) {
    setState(() {
      _indice = index;
      _seleccion = null;
      _resultado = null;
      _error = null;
      _clavePendiente = null;
      _respuestaPendiente = null;
      _prepararOrden();
    });
  }

  dynamic _respuesta(CapacitacionActividad actividad) =>
      actividad.tipo == 'ordenar_pasos'
      ? _ordenActual.map((item) => item.clave).toList(growable: false)
      : _seleccion;

  String _claveNueva() =>
      'ruta-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> _comprobar() async {
    final actividad = _actual;
    if (actividad == null) return;
    final answer = _respuesta(actividad);
    if (answer == null || (answer is List && answer.isEmpty)) {
      setState(() => _error = 'Elige una respuesta para continuar.');
      return;
    }
    _clavePendiente ??= _claveNueva();
    _respuestaPendiente ??= jsonEncode(answer);
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final outcome = await widget.service.responderActividad(
        idRuta: widget.ruta.id,
        idActividad: actividad.id,
        respuesta: jsonDecode(_respuestaPendiente!),
        idempotencyKey: _clavePendiente!,
      );
      if (!mounted) return;
      setState(() {
        _resultado = outcome;
        _xpTotal = outcome.xpTotal;
        if (outcome.correcta) _completadas.add(actividad.id);
        _enviando = false;
        _clavePendiente = null;
        _respuestaPendiente = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = _mensajeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final actividad = _actual;
    if (actividad == null) return _resultadoCamino();
    final progreso = _actividades.isEmpty
        ? 0.0
        : _completadas.length / _actividades.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ruta.titulo),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text('✨ $_xpTotal XP', key: const ValueKey('xp-total')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progreso,
                                minHeight: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${_indice + 1}/${_actividades.length}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Desafío ${_indice + 1} de ${_actividades.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PlantaVirtual(
                            progreso: _completadas.length / _actividades.length,
                            tamano: 48,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _resultado?.correcta == true
                                ? '¡Tu planta está creciendo!'
                                : 'Cada reto ayuda a tu planta a crecer',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: ValueKey('actividad-${actividad.id}'),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _iconoActividad(actividad.icono),
                              size: 34,
                              color: AppColors.forest,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              actividad.titulo,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              actividad.enunciado,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (actividad.tipo == 'ordenar_pasos')
                        _ordenWidget()
                      else
                        for (final opcion in actividad.opciones)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _OpcionDesafioTile(
                              opcion: opcion,
                              selected: _seleccion == opcion.clave,
                              enabled: _resultado == null && !_enviando,
                              onTap: () => setState(() {
                                _seleccion = opcion.clave;
                                _error = null;
                                _clavePendiente = null;
                                _respuestaPendiente = null;
                              }),
                            ),
                          ),
                      if (_resultado != null)
                        _retroalimentacion(_resultado!, actividad),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _error == null
                      ? const SizedBox.shrink(
                          key: ValueKey('sin-error-desafio'),
                        )
                      : Padding(
                          key: const ValueKey('error-desafio-visible'),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _MensajeError(texto: _error!),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('comprobar-desafio'),
                        onPressed: _enviando
                            ? null
                            : _resultado == null
                            ? _comprobar
                            : _resultado!.correcta
                            ? _siguiente
                            : () => _cambiarActividad(_indice),
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _resultado == null
                                    ? Icons.check_rounded
                                    : _resultado!.correcta
                                    ? Icons.arrow_forward_rounded
                                    : Icons.replay_rounded,
                              ),
                        label: Text(
                          _enviando
                              ? 'Comprobando…'
                              : _resultado == null
                              ? 'Comprobar'
                              : _resultado!.correcta
                              ? _indice + 1 == _actividades.length
                                    ? 'Ver resultado'
                                    : 'Siguiente desafío'
                              : 'Intentar de nuevo',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ordenWidget() => ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _ordenActual.length,
    onReorderItem: (oldIndex, newIndex) => setState(() {
      final item = _ordenActual.removeAt(oldIndex);
      _ordenActual.insert(newIndex, item);
      _clavePendiente = null;
      _respuestaPendiente = null;
    }),
    itemBuilder: (context, index) => Card(
      key: ValueKey(_ordenActual[index].clave),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.mint,
          child: Text('${index + 1}'),
        ),
        title: Text(_ordenActual[index].texto),
        trailing: const Icon(Icons.drag_handle),
      ),
    ),
  );

  Widget _retroalimentacion(
    CapacitacionRespuestaActividad resultado,
    CapacitacionActividad actividad,
  ) => Container(
    key: const ValueKey('feedback-desafio'),
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: resultado.correcta ? AppColors.mint : Colors.orange.shade50,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: resultado.correcta ? AppColors.leaf : Colors.orange.shade300,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resultado.correcta
              ? '¡Muy bien! +${resultado.xpOtorgado} XP'
              : 'Vamos a aprender de este intento',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(resultado.explicacion),
        if (!resultado.correcta) ...[
          const SizedBox(height: 8),
          Text(
            'Respuesta sugerida: ${_respuestaActividadVisible(resultado.respuestaCorrecta, actividad)}',
          ),
        ],
      ],
    ),
  );

  void _siguiente() {
    final next = _actividades.indexWhere(
      (item) => !_completadas.contains(item.id),
    );
    _cambiarActividad(next < 0 ? _actividades.length : next);
  }

  Widget _resultadoCamino() => Scaffold(
    appBar: AppBar(title: const Text('Camino completado')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 86,
                color: Colors.amber,
              ),
              const SizedBox(height: 8),
              PlantaVirtual(progreso: 1, tamano: 120),
              const SizedBox(height: 12),
              Text(
                '¡Buen trabajo, jardinero!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Completaste ${_completadas.length} desafíos y acumulaste $_xpTotal XP.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.route),
                label: const Text('Volver al camino'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OpcionDesafioTile extends StatelessWidget {
  final CapacitacionOpcion opcion;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _OpcionDesafioTile({
    required this.opcion,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: selected ? AppColors.mint : null,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? AppColors.leaf : Colors.transparent,
        width: 1.5,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.leaf : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(opcion.texto)),
          ],
        ),
      ),
    ),
  );
}

IconData _iconoActividad(String icono) => switch (icono) {
  'search' => Icons.search_rounded,
  'water_drop' => Icons.water_drop_rounded,
  'air' => Icons.air_rounded,
  'sort' => Icons.low_priority_rounded,
  'sunny' => Icons.wb_sunny_rounded,
  _ => Icons.eco_rounded,
};

class _LeccionCapacitacionPage extends StatefulWidget {
  final CapacitacionLeccionResumen resumen;
  final CapacitacionService service;
  final String rutaModulo;

  const _LeccionCapacitacionPage({
    required this.resumen,
    required this.service,
    required this.rutaModulo,
  });

  @override
  State<_LeccionCapacitacionPage> createState() =>
      _LeccionCapacitacionPageState();
}

class _LeccionCapacitacionPageState extends State<_LeccionCapacitacionPage> {
  late Future<CapacitacionLeccion> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.obtenerLeccion(widget.resumen.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lección')),
    body: FutureBuilder<CapacitacionLeccion>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorCapacitacion(
            error: snapshot.error,
            onRetry: () => setState(() {
              _future = widget.service.obtenerLeccion(widget.resumen.id);
            }),
          );
        }
        final leccion = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const ValueKey('lectura-leccion'),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Text(
                        leccion.modulo,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        leccion.titulo,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 18),
                      AppSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Objetivo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 7),
                            Text(leccion.objetivo),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final seccion in leccion.secciones) ...[
                        Text(
                          seccion.titulo,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(seccion.texto),
                        const SizedBox(height: 18),
                      ],
                      if (leccion.fuentes.isNotEmpty) ...[
                        Text(
                          'Fuentes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final fuente in leccion.fuentes)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fuente.titulo,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    fuente.entidad,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 5),
                                  SelectableText(fuente.url),
                                  if (fuente.fechaConsulta != null &&
                                      fuente.fechaConsulta!.isNotEmpty)
                                    Text('Consulta: ${fuente.fechaConsulta}'),
                                  if (fuente.notaEditorial != null &&
                                      fuente.notaEditorial!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(fuente.notaEditorial!),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('iniciar-evaluacion'),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => _EvaluacionCapacitacionPage(
                              leccion: leccion,
                              service: widget.service,
                              rutaModulo: widget.rutaModulo,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('Iniciar evaluación'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _EvaluacionCapacitacionPage extends StatefulWidget {
  final CapacitacionLeccion leccion;
  final CapacitacionService service;
  final String rutaModulo;

  const _EvaluacionCapacitacionPage({
    required this.leccion,
    required this.service,
    required this.rutaModulo,
  });

  @override
  State<_EvaluacionCapacitacionPage> createState() =>
      _EvaluacionCapacitacionPageState();
}

class _EvaluacionCapacitacionPageState
    extends State<_EvaluacionCapacitacionPage> {
  late Future<CapacitacionEvaluacion> _future;
  final Map<int, dynamic> _seleccionadas = {};
  final Random _random = Random();
  String? _clavePendiente;
  String? _cuerpoPendiente;
  String? _errorEnvio;
  String? _errorProgreso;
  bool _mostroPendientes = false;
  bool _enviando = false;
  CapacitacionResultado? _resultado;
  CapacitacionProgreso? _progresoActual;

  @override
  void initState() {
    super.initState();
    _future = widget.service.obtenerEvaluacion(widget.leccion.id);
  }

  void _seleccionar(int idPregunta, dynamic respuesta) {
    setState(() {
      _seleccionadas[idPregunta] = respuesta;
      _clavePendiente = null;
      _cuerpoPendiente = null;
      _errorEnvio = null;
    });
  }

  String _nuevaClave() =>
      'cap-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  Future<void> _enviar(CapacitacionEvaluacion evaluacion) async {
    final pendientes = evaluacion.preguntas
        .where((pregunta) => !_seleccionadas.containsKey(pregunta.id))
        .toList();
    if (pendientes.isNotEmpty) {
      setState(() {
        _mostroPendientes = true;
        final numeros = pendientes.map((pregunta) => pregunta.orden).join(', ');
        _errorEnvio =
            'Responde todas las preguntas antes de enviar. Faltan las preguntas: $numeros.';
      });
      return;
    }

    _clavePendiente ??= _nuevaClave();
    _cuerpoPendiente ??= jsonEncode({
      'id_leccion_version': evaluacion.idVersion,
      'respuestas': evaluacion.preguntas
          .map(
            (pregunta) => {
              'id_pregunta_version': pregunta.id,
              'respuesta': _seleccionadas[pregunta.id],
            },
          )
          .toList(growable: false),
    });

    setState(() {
      _enviando = true;
      _errorEnvio = null;
      _mostroPendientes = false;
    });
    try {
      final resultado = await widget.service.enviarIntentoCodificado(
        idLeccion: widget.leccion.id,
        body: _cuerpoPendiente!,
        idempotencyKey: _clavePendiente!,
      );
      if (!mounted) return;
      setState(() => _resultado = resultado);
      try {
        final progress = await widget.service.obtenerProgreso();
        if (mounted) {
          CapacitacionProgreso? leccionProgress;
          for (final item in progress) {
            if (item.idLeccion == widget.leccion.id) {
              leccionProgress = item;
              break;
            }
          }
          setState(() {
            _progresoActual = leccionProgress;
          });
        }
      } catch (_) {
        if (mounted)
          setState(() => _errorProgreso = 'No se pudo actualizar el progreso.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorEnvio = error.toString());
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Evaluación')),
    body: FutureBuilder<CapacitacionEvaluacion>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorCapacitacion(
            error: snapshot.error,
            onRetry: () => setState(() {
              _future = widget.service.obtenerEvaluacion(widget.leccion.id);
            }),
          );
        }
        final evaluacion = snapshot.data!;
        if (_resultado case final resultado?) {
          return _resultadoView(resultado);
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const ValueKey('evaluacion-preguntas'),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.leccion.titulo,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('${evaluacion.preguntas.length} preguntas'),
                      const SizedBox(height: 16),
                      if (_errorEnvio != null) ...[
                        _MensajeError(texto: _errorEnvio!),
                        const SizedBox(height: 12),
                      ],
                      for (final pregunta in evaluacion.preguntas)
                        Card(
                          key: ValueKey('pregunta-${pregunta.id}'),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pregunta.orden}. ${pregunta.enunciado}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 8),
                                for (final opcion in pregunta.opciones)
                                  RadioListTile<String>(
                                    key: ValueKey(
                                      'respuesta-${pregunta.id}-${opcion.clave}',
                                    ),
                                    value: opcion.clave,
                                    groupValue:
                                        _seleccionadas[pregunta.id] as String?,
                                    onChanged: _enviando
                                        ? null
                                        : (value) {
                                            if (value != null) {
                                              _seleccionar(pregunta.id, value);
                                            }
                                          },
                                    title: Text(opcion.texto),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                if (_mostroPendientes &&
                                    !_seleccionadas.containsKey(pregunta.id))
                                  const Text(
                                    'Selecciona una respuesta.',
                                    style: TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('enviar-evaluacion'),
                        onPressed: _enviando ? null : () => _enviar(evaluacion),
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _enviando
                              ? 'Enviando…'
                              : _clavePendiente != null
                              ? 'Reintentar envío'
                              : 'Enviar evaluación',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _resultadoView(CapacitacionResultado resultado) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('resultado-evaluacion'),
              padding: const EdgeInsets.all(20),
              children: [
                Icon(
                  resultado.aprobado ? Icons.verified : Icons.menu_book,
                  size: 54,
                  color: resultado.aprobado ? AppColors.leaf : AppColors.water,
                ),
                const SizedBox(height: 8),
                Text(
                  resultado.aprobado
                      ? 'Evaluación aprobada'
                      : 'Evaluación no aprobada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Calificación: ${_numero(resultado.calificacion)} · '
                  '${resultado.respuestasCorrectas} de ${resultado.totalPreguntas} correctas',
                  textAlign: TextAlign.center,
                ),
                if (_progresoActual != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Progreso: ${_estadoVisible(_progresoActual!.estado)}',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_errorProgreso != null)
                  Text(_errorProgreso!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                for (final respuesta in resultado.respuestas)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        respuesta.correcta ? Icons.check_circle : Icons.cancel,
                        color: respuesta.correcta
                            ? AppColors.leaf
                            : Colors.orange,
                      ),
                      title: Text(
                        respuesta.correcta
                            ? 'Respuesta correcta'
                            : 'Respuesta por revisar',
                      ),
                      subtitle: Text(
                        '${respuesta.explicacion}\n'
                        'Respuesta correcta: ${_respuestaVisible(respuesta.respuestaCorrecta)}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('volver-leccion'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver a la lección'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('continuar-modulo'),
                    onPressed: () => Navigator.of(context).popUntil(
                      (route) => route.settings.name == widget.rutaModulo,
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuar al módulo'),
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

class _ProgresoCapacitacionPage extends StatefulWidget {
  final CapacitacionService service;

  const _ProgresoCapacitacionPage({required this.service});

  @override
  State<_ProgresoCapacitacionPage> createState() =>
      _ProgresoCapacitacionPageState();
}

class _ProgresoCapacitacionPageState extends State<_ProgresoCapacitacionPage> {
  late Future<List<CapacitacionProgreso>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() => _future = widget.service.obtenerProgreso();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi progreso')),
    body: FutureBuilder<List<CapacitacionProgreso>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorCapacitacion(
            error: snapshot.error,
            onRetry: () => setState(_cargar),
          );
        }
        final progreso = snapshot.data ?? const <CapacitacionProgreso>[];
        if (progreso.isEmpty) {
          return const EmptyStatePanel(
            icon: Icons.insights_outlined,
            title: 'Sin progreso disponible',
            message:
                'No hay lecciones publicadas para mostrar progreso todavía.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: progreso.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = progreso[index];
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.leaf,
                ),
                title: Text(item.leccion),
                subtitle: Text(
                  '${item.modulo} · ${_estadoVisible(item.estado)}',
                ),
                trailing: item.ultimaCalificacion == null
                    ? null
                    : Text('${_numero(item.ultimaCalificacion!)}'),
              ),
            );
          },
        );
      },
    ),
  );
}

class _ErrorCapacitacion extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorCapacitacion({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyStatePanel(
    icon: Icons.cloud_off_outlined,
    title: 'No se pudo cargar la capacitación',
    message: _mensajeError(error),
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Reintentar'),
    ),
  );
}

class _MensajeError extends StatelessWidget {
  final String texto;

  const _MensajeError({required this.texto});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(top: 12),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(texto, style: TextStyle(color: Colors.red.shade800)),
  );
}

String _mensajeError(Object? error) {
  if (error is CapacitacionApiException) return error.message;
  return 'Revisa tu conexión e inténtalo de nuevo.';
}

String _estadoVisible(String estado) => switch (estado) {
  'no_iniciado' => 'No iniciado',
  'en_progreso' => 'En progreso',
  'completado' => 'Completado',
  _ => 'Estado no disponible',
};

String _numero(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _respuestaVisible(dynamic answer) => answer?.toString() ?? '—';

String _respuestaActividadVisible(
  dynamic answer,
  CapacitacionActividad actividad,
) {
  String etiqueta(dynamic key) {
    for (final opcion in actividad.opciones) {
      if (opcion.clave == key?.toString()) return opcion.texto;
    }
    return key?.toString() ?? '—';
  }

  if (answer is List) return answer.map(etiqueta).join(' → ');
  return etiqueta(answer);
}
