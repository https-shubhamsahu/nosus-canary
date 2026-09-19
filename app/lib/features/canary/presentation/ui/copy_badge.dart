import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Perforated ticket: "COPY 07 / 50 · made for Priya".
class CopyBadge extends StatefulWidget {
  const CopyBadge({
    super.key,
    required this.copyIndex,
    required this.copyCount,
    this.readerName,
    this.fill = CanaryTokens.canary,
  });

  final int copyIndex;
  final int copyCount;
  final String? readerName;
  final Color fill;

  @override
  State<CopyBadge> createState() => _CopyBadgeState();
}

class _CopyBadgeState extends State<CopyBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(begin: 1.3, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _rotate = Tween<double>(begin: -6 * math.pi / 180, end: 0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.value = 1;
    } else if (!_c.isCompleted && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.readerName;
    final label = name == null || name.isEmpty
        ? 'COPY ${widget.copyIndex + 1} / ${widget.copyCount}'
        : 'COPY ${widget.copyIndex + 1} / ${widget.copyCount} · made for $name';

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotate.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: Semantics(
        label: label,
        child: CustomPaint(
          painter: _TicketPainter(fill: widget.fill),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: CanaryTokens.monoFont,
                fontSize: 21,
                color: CanaryTokens.onCanary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter({required this.fill});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 8.0;
    const notch = 7.0;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(r)));
    final holes = Path();
    for (var y = notch * 2; y < size.height - notch; y += notch * 2) {
      holes.addOval(
        Rect.fromCircle(center: Offset(0, y), radius: notch),
      );
      holes.addOval(
        Rect.fromCircle(center: Offset(size.width, y), radius: notch),
      );
    }
    final ticket = Path.combine(PathOperation.difference, path, holes);
    canvas.drawPath(
      ticket,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TicketPainter oldDelegate) =>
      oldDelegate.fill != fill;
}
