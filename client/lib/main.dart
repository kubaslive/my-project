import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const SwdApp());
}

class SwdApp extends StatelessWidget {
  const SwdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SWD PRM Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
