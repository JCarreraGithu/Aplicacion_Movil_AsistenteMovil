import 'package:flutter/material.dart';
import '../services/jardin_service.dart';

class SectoresPage extends StatefulWidget {
  final String token;
  final int idJardin;
  final String nombreJardin;

  const SectoresPage({
    super.key,
    required this.token,
    required this.idJardin,
    required this.nombreJardin,
  });

  @override
  State<SectoresPage> createState() => _SectoresPageState();
}

class _SectoresPageState extends State<SectoresPage> {
  List<dynamic> sectores = [];

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarSectores();
  }

  Future<void> cargarSectores() async {
    try {
      final resultado =
          await JardinService.obtenerSectores(
        token: widget.token,
        idJardin: widget.idJardin,
      );

      if (!mounted) return;

      setState(() {
        sectores = resultado;
        cargando = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),

      appBar: AppBar(
        title: Text(
          widget.nombreJardin,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2E7D32),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red,
              ),

              const SizedBox(height: 15),

              const Text(
                'No se pudieron cargar los sectores',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: cargarSectores,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (sectores.isEmpty) {
      return const Center(
        child: Text(
          'Este jardín todavía no tiene sectores.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cargarSectores,

      child: ListView.builder(
        padding: const EdgeInsets.all(20),

        itemCount: sectores.length,

        itemBuilder: (context, index) {
          final sector = sectores[index];

          return _sectorCard(sector);
        },
      ),
    );
  }

  Widget _sectorCard(dynamic sector) {
    final String nombre =
        sector['nombre'] ?? 'Sector sin nombre';

    final String descripcion =
        sector['descripcion'] ?? 'Sin descripción';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,

            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(
              Icons.grass,
              color: Color(0xFF2E7D32),
              size: 30,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  nombre,

                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  descripcion,

                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right,
          ),
        ],
      ),
    );
  }
}