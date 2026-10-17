import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_ux_components.dart';

/// Shared building blocks for the premium look: brand colours, entrance
/// animations, a pressable button with a sheen, and the PRO emblem.
class Brand {
  static const green = Color(0xFF16A34A);
  static const deep = Color(0xFF0B2A18);
  static const forest = Color(0xFF123B24);
  static const mint = Color(0xFFD1FAE5);
  static const gold = Color(0xFFFFC24B);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  static const gradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF0F5132)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const darkGradient = LinearGradient(
    colors: [Color(0xFF0F3D24), Color(0xFF061A10)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Fades and slides its child up when first built. Use [delay] to stagger a list.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.dy = 22,
  });

  @override
  Widget build(BuildContext context) {
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Curves.linear,
      builder: (context, t, _) {
        final start = delay.inMilliseconds / total.inMilliseconds;
        final p = Curves.easeOutCubic.transform(
          ((t - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, (1 - p) * dy), child: child),
        );
      },
    );
  }
}

/// Gentle endless up-and-down float.
class Floating extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;
  const Floating({
    super.key,
    required this.child,
    this.distance = 7,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, (Curves.easeInOut.transform(_c.value) - .5) * 2 * widget.distance),
      child: child,
    ),
    child: widget.child,
  );
}

/// Expanding, fading rings behind a hero icon.
class PulseRings extends StatefulWidget {
  final double size;
  final Color color;
  final Widget child;
  const PulseRings({
    super.key,
    required this.child,
    this.size = 120,
    this.color = Brand.green,
  });

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size * 1.9,
    height: widget.size * 1.9,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size * 1.9),
            painter: _RingsPainter(_c.value, widget.color, widget.size / 2),
          ),
        ),
        widget.child,
      ],
    ),
  );
}

class _RingsPainter extends CustomPainter {
  final double t;
  final Color color;
  final double inner;
  _RingsPainter(this.t, this.color, this.inner);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final radius = inner + (outer - inner) * p;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * .35),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t;
}

/// Soft drifting colour blobs for premium backgrounds.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Color base;
  const AuroraBackground({
    super.key,
    required this.child,
    this.base = const Color(0xFFF8FAFC),
    this.colors = const [Color(0x3316A34A), Color(0x33FFC24B), Color(0x2616A34A)],
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(color: widget.base),
      AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _AuroraPainter(_c.value, widget.colors)),
      ),
      widget.child,
    ],
  );
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  _AuroraPainter(this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final a = (t + i / colors.length) * 2 * math.pi;
      final c = Offset(
        size.width * (.5 + .38 * math.cos(a + i)),
        size.height * (.28 + .22 * math.sin(a * 1.3 + i * 2)),
      );
      final r = size.width * .55;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [colors[i], colors[i].withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

/// Button with a press-in scale, optional gradient and a light sheen that sweeps across.
class PremiumButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool gold;
  const PremiumButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.busy = false,
    this.gold = false,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> with TickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  bool _down = false;

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final gradient = widget.gold
        ? const LinearGradient(colors: [Color(0xFFFFD36E), Color(0xFFF59E0B)])
        : Brand.gradient;
    final fg = widget.gold ? Brand.deep : Colors.white;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: enabled
          ? () {
              AppHaptics.light();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? .97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: widget.onPressed == null ? .5 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (widget.gold ? Brand.gold : Brand.green).withValues(alpha: .35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (enabled)
                  AnimatedBuilder(
                    animation: _sheen,
                    builder: (context, _) => FractionallySizedBox(
                      widthFactor: 1,
                      child: Transform.translate(
                        offset: Offset((_sheen.value * 2 - 1) * 320, 0),
                        child: Transform.rotate(
                          angle: -.4,
                          child: Container(
                            width: 46,
                            height: 120,
                            color: Colors.white.withValues(alpha: .22),
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: widget.busy
                      ? SizedBox(
                          key: const ValueKey('busy'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                        )
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, color: fg, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: fg,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                            ),
                          ],
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

/// The Quiz LAB Pro emblem, with an optional glow.
class ProEmblem extends StatelessWidget {
  final double size;
  final bool glow;
  const ProEmblem({super.key, this.size = 72, this.glow = true});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .24),
      boxShadow: glow
          ? [BoxShadow(color: Brand.green.withValues(alpha: .45), blurRadius: size * .4, spreadRadius: 1)]
          : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.asset('assets/quiz-lab-pro.png', fit: BoxFit.cover),
    ),
  );
}

/// A circular progress ring that animates from its previous value.
class AnimatedRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;
  const AnimatedRing({
    super.key,
    required this.value,
    this.size = 84,
    this.stroke = 9,
    this.color = Brand.green,
    this.track = const Color(0x2616A34A),
    this.child,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: stroke,
              color: track,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    ),
  );
}
