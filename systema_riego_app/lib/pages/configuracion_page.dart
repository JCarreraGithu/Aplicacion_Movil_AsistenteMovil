import 'package:flutter/material.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() =>
      _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  bool notificaciones = true;
  bool modoAutomatico = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Riego',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),

          const SizedBox(height: 10),

          _settingCard(
            Icons.auto_mode,
            'Modo automático',
            'Permite que el sistema controle el riego',
            Switch(
              value: modoAutomatico,
              onChanged: (value) {
                setState(() {
                  modoAutomatico = value;
                });
              },
            ),
          ),

          const SizedBox(height: 15),

          _settingCard(
            Icons.notifications_outlined,
            'Notificaciones',
            'Recibir alertas del sistema',
            Switch(
              value: notificaciones,
              onChanged: (value) {
                setState(() {
                  notificaciones = value;
                });
              },
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Sistema',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),

          const SizedBox(height: 10),

          _settingCard(
            Icons.sensors,
            'Sensores',
            'Administrar sensores instalados',
            const Icon(Icons.chevron_right),
          ),

          const SizedBox(height: 10),

          _settingCard(
            Icons.water,
            'Actuadores',
            'Administrar bombas y válvulas',
            const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _settingCard(
    IconData icon,
    String title,
    String subtitle,
    Widget trailing,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF2E7D32),
            size: 26,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}