import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'theme/app_theme.dart';

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

      theme: AppTheme.light,

      home: const LoginPage(),
    );
  }
}
