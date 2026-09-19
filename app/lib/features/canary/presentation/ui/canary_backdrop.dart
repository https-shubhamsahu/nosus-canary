import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../theme.dart';

/// Dark grid plus two drifting radial orbs. Paint is ticker-driven.
class CanaryBackdrop extends StatefulWidget {
  const CanaryBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<CanaryBackdrop> createState() => _CanaryBackdropState();
}

class _CanaryBackdropState extends State<CanaryBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  Duration _lastPaint = Duration.zero;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = CanaryTokens.reduceMotion(context);
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTicker();
  }

  void _syncTicker() {
    final paused =
        _reduce ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive;
    if (paused) {
      if (_ticker.isActive) _ticker.stop();
      _t.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    // Cap ambient paint at ~30 fps.
    if (elapsed - _lastPaint < const Duration(milliseconds: 33)) return;
    _lastPaint = elapsed;
    _t.value = (elapsed.inMilliseconds % 20000) / 20000;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: CanaryTokens.bg),
        Positioned.fill(
          child: CustomPaint(
            painter: _BackdropPainter(progress: _t),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.progress}) : super(repaint: progress);

  final ValueNotifier<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value * math.pi * 2;
    final grid = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final orange = Offset(
      size.width * (0.18 + 0.04 * math.sin(t)),
      size.height * (0.12 + 0.03 * math.cos(t * 0.7)),
    );
    final purple = Offset(
      size.width * (0.82 + 0.03 * math.cos(t * 0.8)),
      size.height * (0.78 + 0.04 * math.sin(t * 0.6)),
    );
    final orangeR = size.shortestSide * 0.42;
    final purpleR = size.shortestSide * 0.48;
    canvas.drawCircle(
      orange,
      orangeR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            CanaryTokens.canary.withValues(alpha: 0.22),
            CanaryTokens.canary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: orange, radius: orangeR)),
    );
    canvas.drawCircle(
      purple,
      purpleR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            CanaryTokens.monad.withValues(alpha: 0.18),
            CanaryTokens.monad.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: purple, radius: purpleR)),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
