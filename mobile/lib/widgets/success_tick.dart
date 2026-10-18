import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One-shot confirmation: the green circle settles, then the tick draws in.
/// Reduced-motion users receive the completed mark immediately.
class SuccessTick extends StatefulWidget {
  const SuccessTick({super.key, this.size = 112, this.label = 'Success'});
  final double size;
  final String label;
  @override
  State<SuccessTick> createState() => _SuccessTickState();
}

class _SuccessTickState extends State<SuccessTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 1;
    } else if (!_started) {
      _animation.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    image: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _TickPainter(_animation.value),
        ),
      ),
    ),
  );
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .37;
    final pop = Curves.easeOutBack.transform(
      (progress / .6).clamp(0.0, 1.0).toDouble(),
    );
    if (pop <= 0) return;
    canvas.drawCircle(
      center,
      radius * (1 + progress * .32),
      Paint()
        ..color = const Color(0xFF16A34A)
            .withValues(alpha: .18 * (1 - progress)),
    );
    canvas.drawCircle(
      center,
      radius * pop,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF16B655), Color(0xFF08643D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final tickProgress = ((progress - .35) / .65).clamp(0.0, 1.0).toDouble();
    final path = Path()
      ..moveTo(size.width * .33, size.height * .50)
      ..lineTo(size.width * .45, size.height * .62)
      ..lineTo(size.width * .68, size.height * .38);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(
        0,
        metric.length * Curves.easeOut.transform(tickProgress),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, size.width * .045)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
