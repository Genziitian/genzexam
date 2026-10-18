import 'dart:math' as math;

import 'package:flutter/material.dart';

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
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF134E42), Color(0xFF031F1A)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF9EDDC4).withValues(alpha: 0.65),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66001811),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: complete
                      ? const Icon(
                          Icons.check_rounded,
                          key: ValueKey('ready'),
                          color: Color(0xFFD1FAE5),
                          size: 30,
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
              Positioned(
                top: 3,
                child: CustomPaint(
                  size: const Size(20, 26),
                  painter: _PointerPainter(),
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
    final disc = Rect.fromCircle(center: center, radius: radius - 22);
    final outer = Rect.fromCircle(center: center, radius: radius - 11);
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x24059669), Color(0x00059669)],
          stops: [0.65, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawShadow(
      Path()..addOval(outer),
      const Color(0xFF064E3B),
      10,
      false,
    );
    canvas.drawCircle(
      center,
      radius - 11,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0F4E9),
            Color(0xFF579D84),
            Color(0xFFECFDF5),
            Color(0xFF275E4A),
          ],
          stops: [0, 0.4, 0.65, 1],
        ).createShader(outer),
    );
    canvas.drawCircle(
      center,
      radius - 15,
      Paint()..color = const Color(0xFF082F27),
    );
    for (var i = 0; i < 72; i++) {
      final angle = i * math.pi / 36;
      final major = i % 6 == 0;
      final r = radius - 16;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * r,
        center +
            Offset(math.cos(angle), math.sin(angle)) * (r - (major ? 5 : 2)),
        Paint()
          ..color = (major ? const Color(0xFFD5EEDF) : const Color(0xFF6A9E87))
          ..strokeWidth = major ? 1.5 : 0.7,
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turns.value * 2 * math.pi);
    canvas.translate(-center.dx, -center.dy);
    const palette = [
      Color(0xFF064E3B),
      Color(0xFF0D7054),
      Color(0xFF116149),
      Color(0xFF158467),
      Color(0xFF0C5A45),
      Color(0xFF167454),
      Color(0xFF14543D),
      Color(0xFF0C8060),
      Color(0xFF0C634F),
      Color(0xFF1B755C),
    ];
    for (var i = 0; i < palette.length; i++) {
      final start = i * math.pi / 5;
      canvas.drawArc(
        disc,
        start,
        math.pi / 5,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF062C23),
              palette[i],
              Color.lerp(palette[i], const Color(0xFFB1ECD0), 0.13)!,
            ],
            stops: const [0.25, 0.72, 1],
          ).createShader(disc),
      );
      canvas.drawLine(
        center,
        center + Offset(math.cos(start), math.sin(start)) * (radius - 22),
        Paint()
          ..color = const Color(0x459CE3BB)
          ..strokeWidth = 0.7,
      );
      final angle = start + math.pi / 10;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 34),
        2,
        Paint()..color = const Color(0xFFB9DEC7),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      radius - 22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF89C7A9),
    );
    // Fixed light reflection over the moving disc gives the rim depth.
    canvas.drawCircle(
      center,
      radius - 23,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x31FFFFFF), Color(0x00FFFFFF), Color(0x12000000)],
          stops: [0, 0.45, 1],
        ).createShader(disc),
    );
    canvas.drawCircle(
      center,
      44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x709AD5B6),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => oldDelegate.turns != turns;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..quadraticBezierTo(size.width, 0, size.width - 1, 4)
      ..lineTo(size.width / 2 + 2, size.height - 3)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 1,
        size.width / 2 - 2,
        size.height - 3,
      )
      ..lineTo(1, 4)
      ..quadraticBezierTo(0, 0, 2, 0)
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF7E8BE), Color(0xFFBFA16B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}
