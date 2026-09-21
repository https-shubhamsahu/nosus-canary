import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../theme.dart';

/// Lightweight orange/purple/white burst. Ticker-driven CustomPaint.
class CanaryConfetti extends StatefulWidget {
  const CanaryConfetti({super.key, this.play = true});

  final bool play;

  @override
  State<CanaryConfetti> createState() => _CanaryConfettiState();
}

class _Particle {
  _Particle(this.angle, this.speed, this.spin, this.color, this.size);
  final double angle;
  final double speed;
  final double spin;
  final Color color;
  final double size;
}

class _CanaryConfettiState extends State<CanaryConfetti>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier<double>(1);
  late final List<_Particle> _particles;
  Duration _start = Duration.zero;
  bool _started = false;

  static const _colors = [
    CanaryTokens.canary,
    CanaryTokens.canaryHi,
    CanaryTokens.monad,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _particles = [
      for (var i = 0; i < 40; i++)
        _Particle(
          rng.nextDouble() * math.pi * 2,
          80 + rng.nextDouble() * 140,
          (rng.nextDouble() - 0.5) * 8,
          _colors[i % _colors.length],
          3 + rng.nextDouble() * 4,
        ),
    ];
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = CanaryTokens.reduceMotion(context);
    if (reduce || !widget.play) {
      if (_ticker.isActive) _ticker.stop();
      _t.value = 1;
      return;
    }
    if (!_started) {
      _started = true;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_started) {
      _start = elapsed;
      _started = true;
    }
    final t = (elapsed - _start).inMilliseconds / 1200.0;
    if (t >= 1) {
      _t.value = 1;
      _ticker.stop();
      return;
    }
    _t.value = t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(progress: _t, particles: _particles),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles})
    : super(repaint: progress);

  final ValueNotifier<double> progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height / 2);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final p in particles) {
      final dist = p.speed * t;
      final pos = origin + Offset(math.cos(p.angle), math.sin(p.angle)) * dist;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.45,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
