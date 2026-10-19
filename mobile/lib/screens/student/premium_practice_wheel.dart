import 'dart:math' as math;

import 'package:flutter/material.dart';

const _ink = Color(0xFF312E81);
const _inkSoft = Color(0xFF4338CA);
const _gold = Color(0xFFC9A961);
const _goldLight = Color(0xFFF1E1B6);
const _goldDeep = Color(0xFF8E7234);
const _cream = Color(0xFFF8F4EA);

/// A decorative wheel; question selection is performed by the server.
class PracticeWheel extends StatelessWidget {
  final Animation<double> turns;
  final bool busy;
  final bool complete;

  const PracticeWheel({
    super.key,
    required this.turns,
    required this.busy,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: busy ? 'Creating your practice paper' : 'Practice wheel',
    child: SizedBox(
      height: 250,
      child: Center(
        child: SizedBox.square(
          dimension: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size.square(250),
                  painter: _WheelPainter(turns),
                ),
              ),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDeep],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_inkSoft, _ink],
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: complete
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('ready'),
                            color: _goldLight,
                            size: 32,
                          )
                        : Center(
                            key: const ValueKey('brand'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 40,
                                height: 40,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // The pointer flicks each time a segment edge passes it.
              Positioned(
                top: 2,
                child: AnimatedBuilder(
                  animation: turns,
                  builder: (_, child) {
                    final phase = (turns.value * 10) % 1;
                    final flick = busy
                        ? -.5 * math.max(0.0, 1 - phase * 5)
                        : 0.0;
                    return Transform.rotate(
                      angle: flick,
                      alignment: Alignment.topCenter,
                      child: child,
                    );
                  },
                  child: CustomPaint(
                    size: const Size(24, 32),
                    painter: _PointerPainter(),
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

class _WheelPainter extends CustomPainter {
  final Animation<double> turns;
  _WheelPainter(this.turns) : super(repaint: turns);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rim = Rect.fromCircle(center: center, radius: radius - 6);
    final disc = Rect.fromCircle(center: center, radius: radius - 28);

    // Soft ground shadow.
    canvas.drawShadow(Path()..addOval(rim), const Color(0xFF000000), 12, false);

    // Champagne metal rim.
    canvas.drawCircle(
      center,
      radius - 6,
      Paint()
        ..shader = const SweepGradient(
          colors: [_goldLight, _gold, _goldDeep, _gold, _goldLight],
          stops: [0, .3, .55, .8, 1],
        ).createShader(rim),
    );
    canvas.drawCircle(
      center,
      radius - 10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55FFFFFF),
    );
    // Dark channel holding the rim lights.
    canvas.drawCircle(center, radius - 11, Paint()..color = _ink);
    for (var i = 0; i < 30; i++) {
      final angle = i * math.pi * 2 / 30;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 17),
        i.isEven ? 2.1 : 1.3,
        Paint()..color = i.isEven ? _goldLight : _gold.withValues(alpha: .6),
      );
    }

    // Spinning disc.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turns.value * 2 * math.pi);
    canvas.translate(-center.dx, -center.dy);
    const segments = 10;
    const sweep = math.pi * 2 / segments;
    for (var i = 0; i < segments; i++) {
      final start = i * sweep - math.pi / 2 - sweep / 2;
      final base = i.isEven ? _ink : const Color(0xFF4338CA);
      canvas.drawArc(
        disc,
        start,
        sweep,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(base, Colors.black, .35)!,
              base,
              Color.lerp(base, Colors.white, .1)!,
            ],
            stops: const [.2, .7, 1],
          ).createShader(disc),
      );
      canvas.drawLine(
        center + Offset(math.cos(start), math.sin(start)) * 44,
        center + Offset(math.cos(start), math.sin(start)) * (radius - 28),
        Paint()
          ..color = _gold.withValues(alpha: .55)
          ..strokeWidth = 1,
      );
      final angle = start + sweep / 2;
      // Numbered medallion on every segment.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle + math.pi / 2);
      canvas.translate(0, -(radius - 62));
      canvas.drawCircle(
        Offset.zero,
        12,
        Paint()..color = const Color(0x1AFFFFFF),
      );
      canvas.drawCircle(
        Offset.zero,
        12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9
          ..color = _gold.withValues(alpha: .8),
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}'.padLeft(2, '0'),
          style: const TextStyle(
            color: _cream,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
      // Outer edge pearl.
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 36),
        1.8,
        Paint()..color = _goldLight,
      );
    }
    canvas.restore();

    // Fixed finishing rings and glass reflection.
    canvas.drawCircle(
      center,
      radius - 28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _gold,
    );
    canvas.drawCircle(
      center,
      50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _gold.withValues(alpha: .6),
    );
    canvas.drawCircle(
      center,
      radius - 29,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x26FFFFFF), Color(0x00FFFFFF), Color(0x14000000)],
          stops: [0, .45, 1],
        ).createShader(disc),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => oldDelegate.turns != turns;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3, 2)
      ..quadraticBezierTo(size.width / 2, -3, size.width - 3, 2)
      ..lineTo(size.width / 2 + 2, size.height - 3)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 1,
        size.width / 2 - 2,
        size.height - 3,
      )
      ..close();
    canvas.drawShadow(path, const Color(0x99000000), 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFE5E7EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _gold,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}

/// Light streaks and twinkles that shoot outward from the wheel's rim while
/// a paper is being created. Runs its own loop, independent of the spin.
class WheelSparks extends StatefulWidget {
  const WheelSparks({super.key, this.wheelRadius = 125});
  final double wheelRadius;

  @override
  State<WheelSparks> createState() => _WheelSparksState();
}

class _WheelSparksState extends State<WheelSparks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _loop.repeat();
    }
    _started = true;
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: OverflowBox(
        maxWidth: widget.wheelRadius * 2 + 190,
        maxHeight: widget.wheelRadius * 2 + 190,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.wheelRadius * 2 + 190),
            painter: _SparkPainter(_loop, widget.wheelRadius),
          ),
        ),
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t, this.radius) : super(repaint: t);
  final Animation<double> t;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final c = t.value;

    // Breathing glow behind the rim.
    final pulse = .5 + .5 * math.sin(c * math.pi * 2);
    canvas.drawCircle(
      center,
      radius + 6 + pulse * 8,
      Paint()
        ..color = _gold.withValues(alpha: .22 + .18 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    const count = 28;
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963;
      final phase = (c + (i * 0.137) % 1) % 1;
      final dist = radius + 4 + phase * (38 + (i % 4) * 14);
      final fade = math.sin(phase * math.pi);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final color = (i.isEven ? _goldLight : Colors.white).withValues(
        alpha: fade * .95,
      );
      if (i % 3 == 0) {
        // Four-point twinkle.
        final p = center + dir * dist;
        final r = 3.5 + 4 * fade;
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p - Offset(r, 0), p + Offset(r, 0), paint);
        canvas.drawLine(p - Offset(0, r), p + Offset(0, r), paint);
        canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = _gold.withValues(alpha: fade * .35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      } else {
        final len = 8 + 14 * (1 - phase);
        canvas.drawLine(
          center + dir * dist,
          center + dir * (dist - len),
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => false;
}
