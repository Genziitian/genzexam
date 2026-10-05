import 'package:flutter/material.dart';
import 'state/auth_state.dart';
import 'navigation/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final authState = AuthState();
  authState.checkAuthStatus();
  runApp(GenZExamApp(authState: authState));
}

class GenZExamApp extends StatelessWidget {
  final AuthState authState;

  const GenZExamApp({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QUIZ- LAB by GenZ IITian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          primary: const Color(0xFF16A34A),
          surface: Colors.white,
        ),
        fontFamily: 'Inter',
      ),
      home: AppRouter(authState: authState),
    );
  }
}
