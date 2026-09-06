import 'package:flutter/material.dart';
import '../widgets/metric_card.dart';
import 'notificaciones_page.dart';
import 'jardines_page.dart';
import 'asistente_page.dart';
import 'configuracion_page.dart';

class DashboardPage extends StatefulWidget {
  final String token;

  const DashboardPage({
    super.key,
    required this.token,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int currentIndex = 0;

  bool sistemaActivo = true;
  bool riegoManual = false;

  // ============================================================
  // RIEGO MANUAL
  // ============================================================

  void activarRiegoManual() {
    setState(() {
      riegoManual = !riegoManual;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          riegoManual
              ? 'Riego manual activado'
              : 'Riego manual desactivado',
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),

      body: _buildCurrentPage(),

      // ========================================================
      // NAVEGACIÓN INFERIOR
      // ========================================================

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
        return JardinesPage(
          token: widget.token,
        );


      case 2:
        return AsistentePage(
          token: widget.token,
        );

      case 3:
        return const ConfiguracionPage();

      default:
        return _buildDashboard();
    }
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // ENCABEZADO
            // ==================================================

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buenos días,',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Carlos 👋',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificacionesPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_none,
                      size: 27,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // ==================================================
            // ESTADO DEL JARDÍN
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius:
                    BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ESTADO DEL JARDÍN',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                const BoxDecoration(
                              color:
                                  Colors.lightGreenAccent,
                              shape:
                                  BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sistemaActivo
                                ? 'Activo'
                                : 'Inactivo',
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Jardín Principal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      _gardenStat(
                        '72%',
                        'Humedad',
                      ),
                      _gardenStat(
                        '88%',
                        'Salud',
                      ),
                      _gardenStat(
                        '61%',
                        'Luz',
                      ),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            sistemaActivo =
                                !sistemaActivo;
                          });
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.white
                                .withValues(
                              alpha: 0.15,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          child: Text(
                            sistemaActivo
                                ? 'Desactivar'
                                : 'Activar',
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // MÉTRICAS
            // ==================================================

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: const [
                MetricCard(
                  icon: Icons.water_drop,
                  value: '72%',
                  title: 'Humedad suelo',
                  status: 'Nivel adecuado',
                  change: '+3%',
                ),

                MetricCard(
                  icon: Icons.thermostat,
                  value: '24°C',
                  title: 'Temperatura',
                  status: 'Estable',
                  change: 'Normal',
                ),

                MetricCard(
                  icon:
                      Icons.water_drop_outlined,
                  value: '58%',
                  title: 'Humedad ambiental',
                  status: 'Nivel adecuado',
                  change: '-2%',
                ),

                MetricCard(
                  icon: Icons.wb_sunny,
                  value: '8.2k',
                  title: 'Intensidad luz',
                  status: 'Alta',
                  change: 'Lux',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ==================================================
            // RIEGO MANUAL
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed:
                    activarRiegoManual,
                icon: Icon(
                  riegoManual
                      ? Icons.water_drop
                      : Icons.water_drop_outlined,
                ),
                label: Text(
                  riegoManual
                      ? 'Riego Manual Activo'
                      : 'Activar Riego Manual',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      riegoManual
                          ? Colors.blue
                          : const Color(
                              0xFF2E7D32,
                            ),
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  textStyle:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // CONSUMO DE AGUA
            // ==================================================

            Container(
              width: double.infinity,
              height: 180,
              padding:
                  const EdgeInsets.all(20),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Consumo de Agua',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Últimos 15 días',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Expanded(
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _bar(0.45),
                        _bar(0.65),
                        _bar(0.55),
                        _bar(0.80),
                        _bar(0.60),
                        _bar(0.90),
                        _bar(0.70),
                        _bar(0.50),
                        _bar(0.75),
                        _bar(0.85),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ESTADÍSTICA DEL JARDÍN
  // ============================================================

  Widget _gardenStat(
    String value,
    String label,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
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
        borderRadius:
            BorderRadius.circular(10),
      ),
    );
  }
}