import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Vector canary. Never use an emoji glyph for this mark.
class CanaryMark extends StatelessWidget {
  const CanaryMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NO SUS Canary',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: CanaryMarkPainter()),
      ),
    );
  }
}

class CanaryMarkPainter extends CustomPainter {
  const CanaryMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = Paint()
      ..shader = CanaryTokens.brand.createShader(rect)
      ..style = PaintingStyle.fill;

    final cx = size.width * 0.48;
    final cy = size.height * 0.54;
    final r = size.width * 0.30;

    canvas.drawCircle(Offset(cx, cy), r, fill);

    final wing = Path()
      ..moveTo(cx - r * 0.15, cy - r * 0.1)
      ..quadraticBezierTo(
        cx - r * 1.55,
        cy + r * 0.05,
        cx - r * 0.35,
        cy + r * 0.85,
      )
      ..quadraticBezierTo(cx - r * 0.05, cy + r * 0.28, cx - r * 0.15, cy - r * 0.1);
    canvas.drawPath(wing, fill);

    final beak = Path()
      ..moveTo(cx + r * 0.72, cy - r * 0.18)
      ..lineTo(cx + r * 1.28, cy + r * 0.02)
      ..lineTo(cx + r * 0.70, cy + r * 0.22)
      ..close();
    canvas.drawPath(beak, fill);

    canvas.drawCircle(
      Offset(cx + r * 0.22, cy - r * 0.22),
      r * 0.13,
      Paint()..color = CanaryTokens.onCanary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
