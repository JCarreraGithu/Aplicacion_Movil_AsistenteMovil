import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/metric_card.dart';
import '../widgets/app_components.dart';
import '../theme/app_theme.dart';
import '../services/lectura_sensor_service.dart';
import '../services/riego_service.dart';
import '../services/jardin_service.dart';
import '../services/dispositivo_service.dart';
import '../services/caso_service.dart';
import '../services/recordatorio_caso.dart';
import 'dashboard_data.dart';
import 'notificaciones_page.dart';
import 'jardines_page.dart';
import 'asistente_page.dart';
import 'configuracion_page.dart';
import 'casos_page.dart';

class DashboardPage extends StatefulWidget {
  final String token;

  const DashboardPage({super.key, required this.token});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int currentIndex = 0;

  // ============================================================
  // LECTURAS DEL SECTOR
  // ============================================================

  List<dynamic> lecturas = [];
  bool cargandoLecturas = true;
  String? errorLecturas;
  int diasConsumo = 15;
  List<dynamic> riegosPeriodo = [];
  bool cargandoConsumo = true;
  String? errorConsumo;
  Map<String, dynamic>? resumenRiego;
  List<SectorDashboardOption> sectores = [];
  int? idSectorSeleccionado;
  bool cargandoSectores = true;
  String? errorSectores;
  int _cargaSectorId = 0;
  Timer? _temporizadorVigencia;
  final Set<int> _sectoresConLecturasEnCurso = {};
  List<SensorReadingSnapshot> estadoSensores = [];
  List<dynamic> dispositivosSector = [];
  bool cargandoDispositivos = false;
  String? errorDispositivos;
  Map<String, dynamic>? avisoSeguimiento;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _temporizadorVigencia = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {});

      // Only refresh while the Dashboard is visible. The same timer also
      // recalculates the five-minute freshness state without showing a loader.
      if (currentIndex != 0) return;
      final id = idSectorSeleccionado;
      if (id == null || _sectoresConLecturasEnCurso.contains(id)) return;
      unawaited(_cargarLecturas(id, silenciosa: true));
    });
    _cargarAvisoSeguimiento();
    cargarSectores();
  }

  Future<void> _cargarAvisoSeguimiento() async {
    try {
      final datos = await CasoService.obtenerRecordatoriosActivos(
        token: widget.token,
      );
      final unicos = RecordatorioCasoHelper.unicosPorId(
        datos.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
      );
      final relevantes =
          unicos.where((item) {
            if (item['activo'] != true) return false;
            final fecha = DateTime.tryParse(
              item['fecha_recordatorio']?.toString() ?? '',
            );
            return fecha != null && RecordatorioCasoHelper.requiereAviso(fecha);
          }).toList()..sort(
            (a, b) => DateTime.parse(a['fecha_recordatorio'].toString())
                .compareTo(DateTime.parse(b['fecha_recordatorio'].toString())),
          );
      if (mounted) {
        setState(
          () => avisoSeguimiento = relevantes.isEmpty ? null : relevantes.first,
        );
      }
    } catch (_) {
      // No se muestra un aviso si no se pudieron confirmar recordatorios reales.
    }
  }

  Future<void> _abrirSeguimientoProgramado(
    Map<String, dynamic> recordatorio,
  ) async {
    final idCaso = int.tryParse(recordatorio['id_caso']?.toString() ?? '');
    final idRecordatorio = int.tryParse(
      recordatorio['id_recordatorio']?.toString() ?? '',
    );
    if (idCaso == null || idRecordatorio == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CasoDetallePage(
          token: widget.token,
          idCaso: idCaso,
          idRecordatorioInicio: idRecordatorio,
        ),
      ),
    );
    await _cargarAvisoSeguimiento();
  }

  @override
  void dispose() {
    _temporizadorVigencia?.cancel();
    super.dispose();
  }

  Future<void> cargarSectores() async {
    if (!mounted) return;
    setState(() {
      cargandoSectores = true;
      errorSectores = null;
    });
    try {
      final jardines = await JardinService.obtenerJardines(token: widget.token);
      final sectoresPorJardin = <int, List<dynamic>>{};
      for (final jardin in jardines) {
        if (jardin is! Map) continue;
        final id = int.tryParse('${jardin['id_jardin']}');
        if (id != null) {
          sectoresPorJardin[id] = await JardinService.obtenerSectores(
            token: widget.token,
            idJardin: id,
          );
        }
      }
      final opciones = combinarSectores(jardines, sectoresPorJardin);
      if (!mounted) return;
      final seleccionado = elegirSectorInicial(opciones, idSectorSeleccionado);
      setState(() {
        sectores = opciones;
        idSectorSeleccionado = seleccionado;
        cargandoSectores = false;
      });
      if (seleccionado == null) {
        setState(() {
          lecturas = [];
          riegosPeriodo = [];
          resumenRiego = null;
          estadoSensores = [];
          dispositivosSector = [];
          cargandoLecturas = false;
          cargandoConsumo = false;
          cargandoDispositivos = false;
        });
      } else {
        await _cargarDatosSector(seleccionado);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        cargandoSectores = false;
        errorSectores = error.toString();
        cargandoLecturas = false;
        cargandoConsumo = false;
      });
    }
  }

  Future<void> seleccionarSector(int? id) async {
    if (id == null || id == idSectorSeleccionado) return;
    setState(() {
      idSectorSeleccionado = id;
      lecturas = [];
      estadoSensores = [];
      dispositivosSector = [];
      riegosPeriodo = [];
      resumenRiego = null;
    });
    await _cargarDatosSector(id);
  }

  Future<void> _cargarDatosSector(int id) async {
    final cargaId = ++_cargaSectorId;
    await Future.wait([
      cargarLecturas(id),
      cargarConsumo(id),
      cargarEstadoDispositivos(id),
    ]);
    if (!mounted || cargaId != _cargaSectorId) return;
  }

  Future<void> cargarEstadoDispositivos(int id) async {
    if (!mounted) return;
    setState(() {
      cargandoDispositivos = true;
      errorDispositivos = null;
    });
    try {
      final resultado = await DispositivoService.obtenerPorSector(
        token: widget.token,
        idSector: id,
      );
      if (!mounted || id != idSectorSeleccionado) return;
      setState(() {
        dispositivosSector = resultado;
        cargandoDispositivos = false;
      });
    } catch (_) {
      if (!mounted || id != idSectorSeleccionado) return;
      setState(() {
        dispositivosSector = [];
        cargandoDispositivos = false;
        errorDispositivos = 'No se pudo consultar el contacto reportado.';
      });
    }
  }

  Future<void> cargarConsumo([int? sectorId]) async {
    final id = sectorId ?? idSectorSeleccionado;
    if (id == null) return;
    if (!mounted) return;
    setState(() {
      cargandoConsumo = true;
      errorConsumo = null;
    });
    try {
      final resultados = await Future.wait([
        RiegoService.obtenerResumenPorSector(token: widget.token, idSector: id),
        RiegoService.obtenerRiegosPorIntervalo(
          token: widget.token,
          idSector: id,
          dias: diasConsumo,
        ),
      ]);
      if (!mounted || id != idSectorSeleccionado) return;
      setState(() {
        resumenRiego = resultados[0] as Map<String, dynamic>;
        riegosPeriodo = resultados[1] as List<dynamic>;
        cargandoConsumo = false;
      });
    } catch (error) {
      if (!mounted || id != idSectorSeleccionado) return;
      setState(() {
        cargandoConsumo = false;
        errorConsumo = error.toString();
      });
    }
  }

  // ============================================================
  // CARGAR LECTURAS DESDE EL BACKEND
  // ============================================================

  Future<void> cargarLecturas([int? sectorId]) => _cargarLecturas(sectorId);

  Future<void> _cargarLecturas(int? sectorId, {bool silenciosa = false}) async {
    final id = sectorId ?? idSectorSeleccionado;
    if (id == null) return;
    if (!mounted) return;
    if (!_sectoresConLecturasEnCurso.add(id)) return;

    if (!silenciosa) {
      setState(() {
        cargandoLecturas = true;
        errorLecturas = null;
      });
    }

    try {
      final resultado = await Future.wait([
        LecturaSensorService.obtenerSensoresPorSector(
          token: widget.token,
          idSector: id,
        ),
        LecturaSensorService.obtenerUltimasLecturasPorSector(
          token: widget.token,
          idSector: id,
        ),
      ]);

      if (!mounted) return;
      if (id != idSectorSeleccionado) return;

      final sensoresSector = resultado[0] as List<dynamic>;
      final lecturasRecibidas = resultado[1] as List<dynamic>;
      setState(() {
        lecturas = lecturasRecibidas;
        estadoSensores = combinarLecturasSensores(
          sensoresSector,
          lecturasRecibidas,
        );
        cargandoLecturas = false;
        errorLecturas = null;
      });
    } catch (error) {
      if (!mounted || id != idSectorSeleccionado || silenciosa) return;

      setState(() {
        cargandoLecturas = false;
        errorLecturas = error.toString();
      });

      print('ERROR CARGANDO LECTURAS: $error');
    } finally {
      _sectoresConLecturasEnCurso.remove(id);
    }
  }

  // ============================================================
  // OBTENER VALOR DE UN TIPO DE SENSOR
  // ============================================================

  dynamic obtenerLectura(String tipoSensor) {
    return lecturaRecientePorTipo(estadoSensores, tipoSensor)?.lectura;
  }

  String estadoTipoSensor(String tipoSensor) {
    final coincidencias = estadoSensores
        .where(
          (sensor) => sensor.tipo.toLowerCase() == tipoSensor.toLowerCase(),
        )
        .toList();
    if (coincidencias.isEmpty) return 'Sin sensor registrado';
    if (coincidencias.any(
      (sensor) => sensor.estadoLectura == EstadoLectura.reciente,
    )) {
      return 'Lectura reciente';
    }
    if (coincidencias.any(
      (sensor) => sensor.estadoLectura == EstadoLectura.antigua,
    )) {
      return 'Dato antiguo · no actual';
    }
    if (coincidencias.any(
      (sensor) => sensor.estadoLectura == EstadoLectura.fechaInvalida,
    )) {
      return 'Fecha de lectura no válida';
    }
    return 'Sin lecturas registradas';
  }

  String etiquetaLecturaHero(String tipoSensor, String valor, String sufijo) {
    if (valor != '--') return '$valor$sufijo';
    final estado = estadoTipoSensor(tipoSensor);
    if (estado.startsWith('Dato antiguo')) return 'Dato antiguo';
    if (estado == 'Sin lecturas registradas') return 'Sin lectura';
    return estado == 'Sin sensor registrado' ? 'Sin sensor' : estado;
  }

  // ============================================================
  // FORMATEAR VALOR
  // ============================================================

  String obtenerValor(String tipoSensor, {String valorDefecto = '--'}) {
    final lectura = obtenerLectura(tipoSensor);

    if (lectura == null) {
      return valorDefecto;
    }

    final valor = lectura['valor'];

    if (valor == null) {
      return valorDefecto;
    }

    final numero = double.tryParse(valor.toString());

    if (numero == null) {
      return valor.toString();
    }

    if (numero == numero.roundToDouble()) {
      return numero.toInt().toString();
    }

    return numero.toStringAsFixed(1);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Jardines',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'Asistente',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config.',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PÁGINA ACTUAL
  // ============================================================

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 1:
        return JardinesPage(token: widget.token);

      case 2:
        return AsistentePage(token: widget.token);

      case 3:
        return ConfiguracionPage(token: widget.token);

      default:
        return _buildDashboard();
    }
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    final humedadSuelo = obtenerValor('Humedad del suelo');

    final temperatura = obtenerValor('Temperatura');

    final humedadAmbiental = obtenerValor('Humedad ambiental');

    final luz = obtenerValor('Luz');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _cargarAvisoSeguimiento();
          final id = idSectorSeleccionado;
          if (id == null) {
            await cargarSectores();
          } else {
            await Future.wait([
              cargarLecturas(id),
              cargarConsumo(id),
              cargarEstadoDispositivos(id),
            ]);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // ENCABEZADO
              // ==================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _saludo(),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tu jardín hoy',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NotificacionesPage(token: widget.token),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_none, size: 27),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CasosPage(token: widget.token),
                          ),
                        );
                      },
                      icon: const Icon(Icons.healing_outlined, size: 27),
                    ),
                  ),
                ],
              ),

              if (avisoSeguimiento != null) ...[
                const SizedBox(height: 14),
                _tarjetaAvisoSeguimiento(avisoSeguimiento!),
              ],

              const SizedBox(height: 25),

              // ==================================================
              // ESTADO DEL JARDÍN
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.forest, AppColors.leaf],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'SECTOR MONITOREADO',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            Text(
                              cargandoLecturas
                                  ? 'Actualizando'
                                  : estadoSensores.any(
                                      (sensor) =>
                                          sensor.estadoLectura ==
                                          EstadoLectura.reciente,
                                    )
                                  ? 'Datos recientes'
                                  : estadoSensores.isEmpty
                                  ? 'Sin sensores'
                                  : 'Sin datos recientes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    const SizedBox(height: 4),
                    if (cargandoSectores)
                      const LinearProgressIndicator(color: Colors.white)
                    else if (errorSectores != null)
                      TextButton.icon(
                        onPressed: cargarSectores,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          'No se pudieron cargar los sectores',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    else if (sectores.isEmpty)
                      const Text(
                        'No tienes jardines o sectores registrados',
                        style: TextStyle(color: Colors.white),
                      )
                    else
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: idSectorSeleccionado,
                          isExpanded: true,
                          dropdownColor: AppColors.forest,
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                          items: sectores
                              .map(
                                (sector) => DropdownMenuItem<int>(
                                  value: sector.id,
                                  child: Text(
                                    sector.etiqueta,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: seleccionarSector,
                        ),
                      ),

                    const SizedBox(height: 17),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        _heroReading(
                          Icons.water_drop_outlined,
                          etiquetaLecturaHero(
                            'Humedad del suelo',
                            humedadSuelo,
                            '% humedad',
                          ),
                        ),
                        _heroReading(
                          Icons.thermostat_outlined,
                          etiquetaLecturaHero('Temperatura', temperatura, '°C'),
                        ),
                        _heroReading(
                          Icons.wb_sunny_outlined,
                          etiquetaLecturaHero('Luz', luz, ' lux'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildWaterOverview(),

              const SizedBox(height: 20),

              // ==================================================
              // ESTADO DE CARGA / ERROR
              // ==================================================
              if (cargandoLecturas)
                const Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: Center(child: CircularProgressIndicator()),
                ),

              if (errorLecturas != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No se pudieron cargar las lecturas.',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        onPressed: cargarLecturas,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),

              // ==================================================
              // MÉTRICAS
              // ==================================================
              const SectionHeading(
                title: 'Ambiente',
                subtitle: 'Últimas lecturas recibidas del sector',
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.02,
                children: [
                  MetricCard(
                    icon: Icons.water_drop,
                    value: humedadSuelo == '--' ? '--' : '$humedadSuelo%',
                    title: 'Humedad suelo',
                    status: humedadSuelo == '--'
                        ? estadoTipoSensor('Humedad del suelo')
                        : 'Reciente · últimos 5 min',
                    change: 'Suelo',
                  ),

                  MetricCard(
                    icon: Icons.thermostat,
                    value: temperatura == '--' ? '--' : '$temperatura°C',
                    title: 'Temperatura',
                    status: temperatura == '--'
                        ? estadoTipoSensor('Temperatura')
                        : 'Reciente · últimos 5 min',
                    change: 'Ambiente',
                  ),

                  MetricCard(
                    icon: Icons.water_drop_outlined,
                    value: humedadAmbiental == '--'
                        ? '--'
                        : '$humedadAmbiental%',
                    title: 'Humedad ambiental',
                    status: humedadAmbiental == '--'
                        ? estadoTipoSensor('Humedad ambiental')
                        : 'Reciente · últimos 5 min',
                    change: 'Ambiente',
                  ),

                  MetricCard(
                    icon: Icons.wb_sunny,
                    value: luz == '--' ? '--' : luz,
                    title: 'Intensidad luz',
                    status: luz == '--'
                        ? estadoTipoSensor('Luz')
                        : 'Reciente · últimos 5 min',
                    change: 'Lux',
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildIrrigationSummary(),

              const SizedBox(height: 16),
              _buildSensorMonitoring(),

              const SizedBox(height: 20),

              // ==================================================
              // ACCESO A CONTROLES REALES
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => currentIndex = 3),
                  icon: const Icon(Icons.tune),
                  label: const Text('Gestionar bombas y configuración'),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // CONSUMO DE AGUA
              // ==================================================
              _buildConsumptionChart(),
              const SizedBox(height: 16),
              _buildRecentIrrigations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaAvisoSeguimiento(Map<String, dynamic> recordatorio) {
    final fecha = DateTime.tryParse(
      recordatorio['fecha_recordatorio']?.toString() ?? '',
    );
    final planta = recordatorio['nombre_planta']?.toString().trim();
    final nombrePlanta = planta == null || planta.isEmpty
        ? 'la planta'
        : planta;
    final paso = recordatorio['tarea_descripcion']?.toString() ?? '';
    final mensaje = fecha == null
        ? 'Hay un seguimiento programado para $nombrePlanta.'
        : RecordatorioCasoHelper.mensaje(
            planta: nombrePlanta,
            paso: paso,
            fecha: fecha,
          );
    return Card(
      color: const Color(0xFFEAF5EC),
      child: ListTile(
        leading: const Icon(Icons.alarm, color: AppColors.leaf),
        title: const Text('Seguimiento de planta'),
        subtitle: Text(mensaje),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _abrirSeguimientoProgramado(recordatorio),
      ),
    );
  }

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _heroReading(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );

  Widget _buildIrrigationSummary() {
    final resumen = resumenRiego;
    final totalRiegos = int.tryParse('${resumen?['cantidad_riegos']}') ?? 0;
    final desconocidos =
        int.tryParse('${resumen?['cantidades_desconocidas']}') ?? 0;
    final consumo = cantidadAgua(resumen?['consumo_total']);
    final riegos7 = int.tryParse('${resumen?['riegos_ultimos_7_dias']}') ?? 0;
    final desconocidos7 =
        int.tryParse('${resumen?['cantidades_desconocidas_ultimos_7_dias']}') ??
        0;
    final consumo7 = cantidadAgua(resumen?['consumo_ultimos_7_dias']);
    final ultimo = DateTime.tryParse('${resumen?['fecha_ultimo_riego']}');
    String cantidadResumen(double? valor, int cantidad, int noMedidos) {
      if (cantidad == 0) return 'Sin riegos';
      if (valor == null || noMedidos == cantidad)
        return '$noMedidos cantidades desconocidas';
      final known = '${valor.toStringAsFixed(1)} (cantidad registrada)';
      return noMedidos > 0 ? '$known · $noMedidos desconocidas' : known;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de riego del sector',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          if (cargandoConsumo)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorConsumo != null)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'No se pudo cargar el consumo desde el servidor.',
                  ),
                ),
                IconButton(
                  onPressed: () => cargarConsumo(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          else if (idSectorSeleccionado == null)
            const Text('Selecciona un sector para consultar los riegos.')
          else if (resumen == null)
            const Text('Sin información de riego para este sector.')
          else ...[
            _summaryLine(
              Icons.water_drop_outlined,
              'Total histórico',
              cantidadResumen(consumo, totalRiegos, desconocidos),
            ),
            _summaryLine(
              Icons.date_range,
              'Últimos 7 días',
              cantidadResumen(consumo7, riegos7, desconocidos7),
            ),
            _summaryLine(
              Icons.format_list_numbered,
              'Riegos registrados',
              '$totalRiegos en total · $riegos7 en 7 días',
            ),
            _summaryLine(
              Icons.schedule,
              'Último riego',
              ultimo == null ? 'Sin riegos registrados' : _formatDate(ultimo),
            ),
            if (desconocidos > 0 || desconocidos7 > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Hay riegos sin cantidad de agua registrada; no se suman como cero.',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                ),
              ),
          ],
          const Divider(height: 24),
          Text(
            'La base registra cantidad_agua, pero no su unidad ni procedencia. No se puede confirmar si es consumo medido o estimado.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.leaf),
        const SizedBox(width: 9),
        Expanded(child: Text(title)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSensorMonitoring() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Sensores del sector',
          subtitle: 'Estado de lectura y última fecha recibida',
        ),
        const SizedBox(height: 10),
        if (cargandoLecturas)
          const Center(child: CircularProgressIndicator())
        else if (errorLecturas != null)
          _sensorMessage(
            'No fue posible consultar sensores y lecturas.',
            icon: Icons.cloud_off_outlined,
          )
        else if (estadoSensores.isEmpty)
          _sensorMessage(
            'No hay sensores registrados para este sector.',
            icon: Icons.sensors_off,
          )
        else
          ...estadoSensores.map(_buildSensorCard),
        const SizedBox(height: 8),
        _buildDeviceContact(),
      ],
    );
  }

  Widget _sensorMessage(String text, {required IconData icon}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _buildSensorCard(SensorReadingSnapshot item) {
    final state = item.estadoLectura;
    final color = switch (state) {
      EstadoLectura.reciente => AppColors.leaf,
      EstadoLectura.antigua => Colors.orange.shade800,
      EstadoLectura.sinLectura => AppColors.muted,
      EstadoLectura.fechaInvalida => Colors.red.shade700,
    };
    final value = item.lectura?['valor'];
    final unit = item.lectura?['unidad'];
    final readingLabel = switch (state) {
      EstadoLectura.reciente => 'Lectura reciente',
      EstadoLectura.antigua => 'Lectura antigua · no es tiempo real',
      EstadoLectura.sinLectura => 'Sin lecturas registradas',
      EstadoLectura.fechaInvalida => 'Fecha de lectura no válida',
    };
    final sensorState = '${item.sensor['estado'] ?? ''}'.toUpperCase();
    final disabled = const {
      'INACTIVO',
      'INACTIVE',
      'DESHABILITADO',
    }.contains(sensorState);
    final detail = disabled
        ? 'Sensor deshabilitado en el sistema'
        : switch (state) {
            EstadoLectura.reciente =>
              'Valor: ${value ?? 'no disponible'}${unit == null || '$unit'.isEmpty ? '' : ' $unit'}',
            EstadoLectura.antigua =>
              'Último valor guardado: ${value ?? 'no disponible'}${unit == null || '$unit'.isEmpty ? '' : ' $unit'}',
            EstadoLectura.sinLectura =>
              'Sin datos recibidos; esto no confirma una falla física.',
            EstadoLectura.fechaInvalida =>
              'Valor oculto porque no se puede validar su fecha.',
          };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          state == EstadoLectura.reciente
              ? Icons.sensors
              : state == EstadoLectura.antigua
              ? Icons.history
              : Icons.sensors_off,
          color: disabled ? AppColors.muted : color,
        ),
        title: Text('${item.tipo} · ${item.codigo}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              disabled ? 'Deshabilitado en el sistema' : readingLabel,
              style: TextStyle(color: disabled ? AppColors.muted : color),
            ),
            Text(detail),
            if (item.fechaLectura != null)
              Text('Última lectura: ${_formatDate(item.fechaLectura!)}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildDeviceContact() {
    if (cargandoDispositivos) {
      return const ListTile(
        leading: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Consultando contacto del dispositivo'),
      );
    }
    if (errorDispositivos != null) {
      return _sensorMessage(errorDispositivos!, icon: Icons.help_outline);
    }
    if (dispositivosSector.isEmpty) {
      return _sensorMessage(
        'No hay dispositivo registrado en este sector; no se puede determinar su contacto.',
        icon: Icons.device_unknown,
      );
    }

    return Column(
      children: dispositivosSector.whereType<Map>().map((device) {
        final activo = device['activo'] == true;
        final enLinea = device['en_linea'] == true;
        final ultimoContacto = DateTime.tryParse(
          '${device['ultimo_contacto']}',
        );
        final text = !activo
            ? 'Dispositivo deshabilitado en el sistema'
            : enLinea
            ? 'Contacto reciente reportado'
            : 'Sin contacto reciente reportado';
        final color = !activo
            ? AppColors.muted
            : enLinea
            ? AppColors.leaf
            : Colors.orange.shade800;
        return Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(Icons.router_outlined, color: color),
            title: Text('${device['nombre'] ?? 'Dispositivo'}'),
            subtitle: Text(
              [
                text,
                if (ultimoContacto != null)
                  'Último contacto: ${_formatDate(ultimoContacto)}',
                'El contacto reportado no confirma por sí solo una falla física.',
              ].join('\n'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentIrrigations() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial · últimos $diasConsumo días',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (cargandoConsumo)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorConsumo != null)
            const Text('El historial no está disponible por ahora.')
          else if (idSectorSeleccionado == null)
            const Text('Selecciona un sector para consultar el historial.')
          else if (riegosPeriodo.isEmpty)
            const Text('No hay riegos registrados en este periodo.')
          else
            ...riegosPeriodo.reversed.take(20).map((row) {
              if (row is! Map) return const SizedBox.shrink();
              final date = DateTime.tryParse('${row['fecha_hora']}');
              final amount = cantidadAgua(row['cantidad_agua']);
              final duration = row['duracion_segundos'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.water_drop_outlined),
                ),
                title: Text(
                  date == null ? 'Fecha no disponible' : _formatDate(date),
                ),
                subtitle: Text(
                  'Duración: ${duration == null ? 'no disponible' : '$duration s'}',
                ),
                trailing: Text(
                  amount == null
                      ? 'Cantidad\ndesconocida'
                      : '${amount.toStringAsFixed(1)}\nregistrada',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
          if (riegosPeriodo.length > 20)
            Text(
              'Se muestran los 20 eventos más recientes de ${riegosPeriodo.length}.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }

  Widget _buildWaterOverview() {
    final tank = _tankLevel();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.water, color: Color(0xFF168AAD)),
              SizedBox(width: 8),
              Text(
                'Tanque de agua',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: tank ?? 0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: tank == null ? 0 : value / 100,
                minHeight: 15,
                backgroundColor: Colors.blueGrey.shade50,
                color: const Color(0xFF168AAD),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            tank == null
                ? _estadoNivelTanque()
                : '${tank!.toStringAsFixed(0)}% disponible',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  double? _tankLevel() {
    for (final sensor in estadoSensores) {
      final tipo = sensor.tipo.toLowerCase();
      if (tipo.contains('tanque') &&
          (tipo.contains('nivel') || tipo.contains('agua')) &&
          sensor.estadoLectura == EstadoLectura.reciente) {
        final value = double.tryParse('${sensor.lectura?['valor']}');
        if (value == null) return null;
        return (value <= 1 ? value * 100 : value).clamp(0, 100).toDouble();
      }
    }
    return null;
  }

  String _estadoNivelTanque() {
    final sensoresNivel = estadoSensores.where((sensor) {
      final tipo = sensor.tipo.toLowerCase();
      return tipo.contains('tanque') &&
          (tipo.contains('nivel') || tipo.contains('agua'));
    });
    if (sensoresNivel.isEmpty) return 'Sin sensor de nivel registrado';
    if (sensoresNivel.any(
      (sensor) => sensor.estadoLectura == EstadoLectura.antigua,
    )) {
      return 'Lectura antigua; nivel actual no disponible';
    }
    return 'Sin lectura de nivel registrada';
  }

  Widget _buildConsumptionChart() {
    final grouped = agruparConsumoPorDia(riegosPeriodo);
    final maxWater = grouped.values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final days = List.generate(
      diasConsumo,
      (i) => DateTime.now().subtract(Duration(days: diasConsumo - i - 1)),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Consumo de agua',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: diasConsumo,
                underline: const SizedBox.shrink(),
                items: const [7, 15, 30]
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          'Últimos $d días',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (d) {
                  if (d != null)
                    setState(() {
                      diasConsumo = d;
                    });
                  if (d != null) cargarConsumo();
                },
              ),
            ],
          ),
          if (errorConsumo != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No se pudo cargar el historial de consumo.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            )
          else if (cargandoConsumo)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (idSectorSeleccionado == null)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('Selecciona un sector para consultar su consumo.'),
              ),
            )
          else
            SizedBox(
              height: 170,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.blueGrey.shade200),
                      bottom: BorderSide(color: Colors.blueGrey.shade200),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.map((date) {
                      final key =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final amount = grouped[key] ?? 0;
                      final barHeight = maxWater == 0
                          ? 3.0
                          : (amount / maxWater * 100).clamp(3, 100).toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: SizedBox(
                          width: 31,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (riegosPeriodo.isEmpty)
                                const SizedBox(height: 100)
                              else
                                Tooltip(
                                  message:
                                      '${amount.toStringAsFixed(1)} de cantidad registrada (unidad sin verificar)',
                                  child: Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: amount == 0
                                          ? Colors.grey.shade200
                                          : const Color(0xFF66BB6A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 7),
                              Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          if (!cargandoConsumo &&
              errorConsumo == null &&
              idSectorSeleccionado != null &&
              riegosPeriodo.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sin riegos registrados en este periodo.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
          if (!cargandoConsumo &&
              errorConsumo == null &&
              cantidadesDesconocidas(riegosPeriodo) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${cantidadesDesconocidas(riegosPeriodo)} riegos no incluyen cantidad; esos eventos no aparecen en la gráfica.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BARRA DE GRÁFICA
  // ============================================================

  Widget _bar(double height) {
    return Container(
      width: 12,
      height: 75 * height,
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
