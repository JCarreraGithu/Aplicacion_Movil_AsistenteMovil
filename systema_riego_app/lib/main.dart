import 'package:flutter/material.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const SistemaRiegoApp());
}

class SistemaRiegoApp extends StatelessWidget {
  const SistemaRiegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Sistema de Riego',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),

        scaffoldBackgroundColor:
            const Color(0xFFF5F7F5),
      ),

      home: const LoginPage(),
    );
  }
}