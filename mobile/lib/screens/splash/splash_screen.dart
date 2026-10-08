import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../state/auth_state.dart';

/// Clean Initial Splash Screen for Quiz Lab Mobile.
///
/// Features:
/// - Verifies `has_seen_onboarding` flag and active Sanctum token session.
/// - Shows official brand logo and version code.
/// - Smoothly routes to Onboarding, Login, or Role-Based Main Shell.
class SplashScreen extends StatefulWidget {
  final AuthState authState;
  final VoidCallback onNeedsOnboarding;
  final VoidCallback onReady;

  const SplashScreen({
    super.key,
    required this.authState,
    required this.onNeedsOnboarding,
    required this.onReady,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAppEntryState();
  }

  Future<void> _checkAppEntryState() async {
    // Artificial minimum delay for brand presentation
    await Future.delayed(const Duration(milliseconds: 900));

    final hasSeenOnboarding = await _storage.read(key: 'has_seen_onboarding');
    if (hasSeenOnboarding != 'true') {
      if (mounted) widget.onNeedsOnboarding();
      return;
    }

    // Inspect user session
    await widget.authState.init();
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F3D22),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand Logo Container
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF2A5230),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFA8D18C).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Q',
                style: TextStyle(
                  color: Color(0xFFA8D18C),
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Quiz Lab',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),

            const Text(
              'by GenZ IITian',
              style: TextStyle(
                color: Color(0xFFA8D18C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),

            // Subtle Loading Indicator
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA8D18C)),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'v1.0.0 (Build 1)',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
