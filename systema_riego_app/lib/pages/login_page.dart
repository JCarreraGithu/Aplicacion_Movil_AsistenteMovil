import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final correoController = TextEditingController();
  final contrasenaController = TextEditingController();

  bool cargando = false;
  String? error;

  Future<void> iniciarSesion() async {
    final correo = correoController.text.trim();
    final contrasena = contrasenaController.text;

    if (correo.isEmpty || contrasena.isEmpty) {
      setState(() {
        error = 'Ingresa correo y contraseña';
      });
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await AuthService.login(
        correo: correo,
        contrasena: contrasena,
      );

      final token = resultado['token'];

      print('TOKEN: $token');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            token: token,
          ),
        ),
      );
    } catch (e) {
      print('ERROR LOGIN: $e');

      setState(() {
        error = e.toString();
        cargando = false;
      });
    }
  }
  @override
  void dispose() {
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),

            child: Column(
              children: [

                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    size: 44,
                    color: AppColors.leaf,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Sistema de Riego',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Inicia sesión para administrar tu jardín',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'MONITOREO  ·  RIEGO  ·  CUIDADO',
                  style: TextStyle(
                    color: AppColors.leaf,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 35),

                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: contrasenaController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton(
                    onPressed:
                        cargando ? null : iniciarSesion,

                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),

                    child: cargando
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
}
