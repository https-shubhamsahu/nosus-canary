import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme.dart';
import 'canary_mark.dart';
import 'glow_card.dart';

/// Canary mark that bobs ±6 px. Final pose when animations are disabled.
class BobbingCanaryMark extends StatefulWidget {
  const BobbingCanaryMark({super.key, this.size = 64});

  final double size;

  @override
  State<BobbingCanaryMark> createState() => _BobbingCanaryMarkState();
}

class _BobbingCanaryMarkState extends State<BobbingCanaryMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final y = math.sin(_c.value * math.pi) * 6;
        return Transform.translate(offset: Offset(0, -y), child: child);
      },
      child: CanaryMark(size: widget.size),
    );
  }
}

/// Sealed envelope shown while the copy is assigned on Monad.
class CanaryEnvelope extends StatefulWidget {
  const CanaryEnvelope({super.key});

  @override
  State<CanaryEnvelope> createState() => _CanaryEnvelopeState();
}

class _CanaryEnvelopeState extends State<CanaryEnvelope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: CustomPaint(
        painter: _ShimmerPainter(_c),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CanaryMark(size: 56),
            const SizedBox(height: 16),
            Text(
              'Making your copy… recording it on Monad',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final n = CanaryTokens.reduceMotion(context)
                    ? 3
                    : ((_c.value * 3).floor() % 3) + 1;
                return Text(
                  List.filled(n, '·').join(' '),
                  style: const TextStyle(
                    fontFamily: CanaryTokens.monoFont,
                    fontSize: 28,
                    color: CanaryTokens.canary,
                    height: 1,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final x = size.width * (t * 1.4 - 0.2);
    final rect = Rect.fromLTWH(x, 0, size.width * 0.28, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          CanaryTokens.canary.withValues(alpha: 0),
          CanaryTokens.canaryHi.withValues(alpha: 0.18),
          CanaryTokens.canary.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 3D Y-flip from [front] to [back] in 500 ms.
class CanaryFlipCard extends StatefulWidget {
  const CanaryFlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
  });

  final Widget front;
  final Widget back;
  final bool showBack;

  @override
  State<CanaryFlipCard> createState() => _CanaryFlipCardState();
}

class _CanaryFlipCardState extends State<CanaryFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.showBack) _c.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context) && widget.showBack) {
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant CanaryFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack == oldWidget.showBack) return;
    if (CanaryTokens.reduceMotion(context)) {
      _c.value = widget.showBack ? 1 : 0;
      return;
    }
    if (widget.showBack) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final back = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(math.pi * t),
          child: back
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: widget.back,
                )
              : widget.front,
        );
      },
    );
  }
}

/// Fades [child] in after [delay]. Instant when animations are disabled.
class DelayedFadeIn extends StatefulWidget {
  const DelayedFadeIn({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 400),
  });

  final Widget child;
  final Duration delay;

  @override
  State<DelayedFadeIn> createState() => _DelayedFadeInState();
}

class _DelayedFadeInState extends State<DelayedFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    if (_scheduled || _c.isCompleted || _c.isAnimating) return;
    _scheduled = true;
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _c, child: widget.child);
  }
}
