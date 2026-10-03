import 'package:flutter/material.dart';

import '../services/notificacion_service.dart';
import '../services/caso_service.dart';
import 'casos_page.dart';

class NotificacionesPage extends StatefulWidget {
  final String token;
  final int idSector;

  const NotificacionesPage({super.key, required this.token, this.idSector = 1});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  ResultadoNotificaciones? resultado;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => cargando = true);
    final datos = await NotificacionService.obtenerAlertas(
      token: widget.token,
      idSector: widget.idSector,
    );
    if (!mounted) return;
    setState(() {
      resultado = datos;
      cargando = false;
    });
  }

  Future<void> _cerrarRecordatorio(AlertaRiego alerta) async {
    if (alerta.idCaso == null || alerta.idRecordatorio == null) return;
    try {
      await CasoService.cerrarRecordatorio(
        token: widget.token,
        idCaso: alerta.idCaso!,
        idRecordatorio: alerta.idRecordatorio!,
      );
      await _cargar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo completar el recordatorio: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7F5),
        elevation: 0,
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar alertas',
            onPressed: cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : RefreshIndicator(onRefresh: _cargar, child: _contenido()),
    );
  }

  Widget _contenido() {
    final actual = resultado;
    if (actual == null || actual.alertas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 70,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'No hay alertas activas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aquí aparecerán las alertas de tu sector.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        if (actual.usaDatosDeEjemplo)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF8A6D1D)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mostrando alertas de ejemplo: todavía no hay registros disponibles en el backend.',
                    style: TextStyle(color: Color(0xFF6B5715), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ...actual.alertas.map(_tarjetaAlerta),
      ],
    );
  }

  Widget _tarjetaAlerta(AlertaRiego alerta) {
    final (icon, color) = switch (alerta.tipo) {
      'humedad' => (Icons.water_drop_outlined, const Color(0xFF1565C0)),
      'bomba' => (Icons.water, const Color(0xFF2E7D32)),
      'temperatura' => (Icons.thermostat, const Color(0xFFE65100)),
      'recordatorio' => (Icons.alarm, const Color(0xFF6A1B9A)),
      _ => (Icons.notifications_active_outlined, const Color(0xFF616161)),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alerta.idCaso == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CasoDetallePage(
                    token: widget.token,
                    idCaso: alerta.idCaso!,
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alerta.titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (alerta.esEjemplo)
                          const Text(
                            'EJEMPLO',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      alerta.mensaje,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _tiempoTranscurrido(alerta.fecha),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (alerta.esRecordatorio)
                IconButton(
                  tooltip: 'Marcar como completado',
                  onPressed: () => _cerrarRecordatorio(alerta),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF2E7D32),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _tiempoTranscurrido(DateTime fecha) {
    final ahora = DateTime.now();
    if (fecha.isAfter(ahora)) {
      final restante = fecha.difference(ahora);
      if (restante.inDays > 0) return 'En ${restante.inDays} días';
      if (restante.inHours > 0) return 'En ${restante.inHours} h';
      return 'En ${restante.inMinutes.clamp(1, 59)} min';
    }
    final diferencia = ahora.difference(fecha);
    if (diferencia.inMinutes < 1) return 'Ahora';
    if (diferencia.inHours < 1) return 'Hace ${diferencia.inMinutes} min';
    if (diferencia.inDays < 1) return 'Hace ${diferencia.inHours} h';
    if (diferencia.inDays == 1) return 'Ayer';
    return 'Hace ${diferencia.inDays} días';
  }
}
