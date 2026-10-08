import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../state/auth_state.dart';

/// Animated launch screen for Quiz Lab Mobile.
///
/// - Verifies the `has_seen_onboarding` flag and any saved session.
/// - Plays the brand intro: sparks rise, the logo lands with a flash and pulsing
///   rings, the name builds letter by letter, then a charging bar runs.
/// - Routes to Onboarding, Login, or the role-based main shell.
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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _title = 'Quiz Lab';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Plays once: logo, flash, title, tagline.
  late final AnimationController _intro;

  /// Loops: sparks, rings, glow, charging bar.
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _checkAppEntryState();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _checkAppEntryState() async {
    // Long enough for the intro to finish before leaving the screen.
    final minimumShow = Future<void>.delayed(const Duration(milliseconds: 2100));

    final hasSeenOnboarding = await _storage.read(key: 'has_seen_onboarding');
    if (hasSeenOnboarding != 'true') {
      await minimumShow;
      if (mounted) widget.onNeedsOnboarding();
      return;
    }

    // Inspect user session while the intro plays
    await Future.wait<void>([widget.authState.init(), minimumShow]);
    if (mounted) widget.onReady();
  }

  /// 0..1 progress of the intro inside the window [start, end], eased.
  double _phase(double start, double end, [Curve curve = Curves.easeOutCubic]) {
    final t = ((_intro.value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
    return curve.transform(t);
  }

  Widget _ring(double t, double logoIn) {
    final grow = Curves.easeOut.transform(t);
    final opacity = (1 - t) * 0.55 * logoIn;
    return Transform.scale(
      scale: 1.0 + grow * 1.1,
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: opacity.clamp(0.0, 1.0).toDouble()), width: 2),
        ),
      ),
    );
  }

  Widget _logo() {
    final land = _phase(0.0, 0.42, Curves.easeOutBack);
    final appear = _phase(0.0, 0.2);
    // A quick yellow flash as the logo lands, like the lightning button.
    final flashT = ((_intro.value - 0.30) / 0.22).clamp(0.0, 1.0).toDouble();
    final flash = math.sin(flashT * math.pi);
    final pulse = 0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi);

    return SizedBox(
      width: 260,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(_loop.value, appear),
          _ring((_loop.value + 0.5) % 1.0, appear),
          Opacity(
            opacity: appear,
            child: Transform.rotate(
              angle: (1 - land) * -0.35,
              child: Transform.scale(
                scale: 0.35 + 0.65 * land,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.25 + 0.25 * pulse),
                        blurRadius: 28 + 16 * pulse,
                        spreadRadius: 2 + 3 * pulse,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.8 * flash),
                        blurRadius: 46,
                        spreadRadius: 10 * flash,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/logo.png', width: 108, height: 108, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Quiz Lab", each letter rising into place a beat after the previous one.
  Widget _titleLetters() {
    final letters = <Widget>[];
    for (var i = 0; i < _title.length; i++) {
      final start = 0.36 + i * 0.045;
      final t = _phase(start, start + 0.26, Curves.easeOutBack);
      final fade = _phase(start, start + 0.16);
      letters.add(
        Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 26),
            child: Text(
              _title[i],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: letters);
  }

  Widget _chargingBar() {
    final show = _phase(0.72, 1.0);
    final t = _loop.value;
    // A bright segment sweeping left to right, twice per loop.
    final sweep = (t * 2) % 1.0;
    return Opacity(
      opacity: show,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 132,
              height: 4,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.12)),
                  Align(
                    alignment: Alignment(-1.6 + 3.2 * sweep, 0),
                    child: Container(
                      width: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x004ADE80), Color(0xFF86EFAC), Color(0x004ADE80)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Getting your papers ready',
            style: TextStyle(color: Color(0xFFBBF7D0), fontSize: 12, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07200F),
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final byline = _phase(0.66, 0.92);
          final drift = _loop.value * 2 * math.pi;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Deep green backdrop with a glow that breathes behind the logo
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.18),
                    radius: 1.05 + 0.06 * math.sin(drift),
                    colors: const [Color(0xFF1B6B3A), Color(0xFF0F3D22), Color(0xFF07200F)],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Rising sparks
              CustomPaint(painter: _SparkPainter(time: _loop.value, fade: _phase(0.0, 0.5))),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _logo(),
                    _titleLetters(),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: byline,
                      child: Transform.translate(
                        offset: Offset(0, (1 - byline) * 10),
                        child: const Text(
                          'by GenZ IITian',
                          style: TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    _chargingBar(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Version
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Opacity(
                  opacity: 0.55 * byline,
                  child: const Text(
                    'v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small glowing dots that float upward and twinkle. Positions are fixed per
/// spark (seeded), so the motion loops without a jump.
class _SparkPainter extends CustomPainter {
  final double time; // 0..1, loops
  final double fade; // 0..1, fades the sparks in at the start

  const _SparkPainter({required this.time, required this.fade});

  static const _count = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final x = random.nextDouble();
      final startY = random.nextDouble();
      final laps = 1 + random.nextInt(2); // whole laps per loop keep it seamless
      final radius = 1.0 + random.nextDouble() * 2.2;
      final phase = random.nextDouble();
      final warm = random.nextInt(5) == 0;

      final y = (startY - time * laps) % 1.0;
      final sway = math.sin((time + phase) * 2 * math.pi) * 10;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin((time * 2 + phase) * 2 * math.pi));
      // Fade out near the top and bottom edges.
      final edge = math.sin(y * math.pi);

      paint.color = (warm ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC))
          .withValues(alpha: (0.5 * twinkle * edge * fade).clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(x * size.width + sway, y * size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.time != time || oldDelegate.fade != fade;
}
