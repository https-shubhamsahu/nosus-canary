import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../theme.dart';

/// Originkit-style liquid carve CTA. Paint is ticker-driven; pointer
/// events only update targets, they do not call setState.
class LiquidCarveButton extends StatefulWidget {
  const LiquidCarveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fill = CanaryTokens.canary,
    this.blobColor = CanaryTokens.canaryHi,
    this.textColor = CanaryTokens.onCanary,
    this.blobSize = 80,
    this.smoothness = 55,
    this.busy = false,
    this.enableGoo = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color fill;
  final Color blobColor;
  final Color textColor;
  final double blobSize;
  final double smoothness;
  final bool busy;
  final bool enableGoo;

  @override
  State<LiquidCarveButton> createState() => _LiquidCarveButtonState();
}

class _BitePaint extends ChangeNotifier {
  Offset pos = Offset.zero;
  double squash = 1;
  double angle = 0;
  double scale = 0;

  void set({
    Offset? pos,
    double? squash,
    double? angle,
    double? scale,
  }) {
    var changed = false;
    if (pos != null && pos != this.pos) {
      this.pos = pos;
      changed = true;
    }
    if (squash != null && squash != this.squash) {
      this.squash = squash;
      changed = true;
    }
    if (angle != null && angle != this.angle) {
      this.angle = angle;
      changed = true;
    }
    if (scale != null && scale != this.scale) {
      this.scale = scale;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

class _LiquidCarveButtonState extends State<LiquidCarveButton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _paint = _BitePaint();
  final _focus = FocusNode();

  Offset _target = Offset.zero;
  double _x = 0;
  double _y = 0;
  double _squash = 1;
  double _angle = 0;
  double _scale = 0;
  double _scaleVel = 0;
  SpringSimulation? _scaleSim;
  Duration _simStart = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  Duration? _tapBiteStart;
  bool _hovering = false;
  bool _focused = false;
  bool _pressedFallback = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = CanaryTokens.reduceMotion(context);
    if (reduce) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _paint.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final rawDt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final dt = rawDt.clamp(0.0, 0.05);
    if (dt <= 0) return;

    if (_tapBiteStart != null) {
      final t = (elapsed - _tapBiteStart!).inMilliseconds / 350.0;
      if (t >= 1) {
        _tapBiteStart = null;
        _scale = 0;
        _scaleVel = 0;
      } else if (t < 0.5) {
        _scale = t * 2;
      } else {
        _scale = 1 - (t - 0.5) * 2;
      }
    } else if (_scaleSim != null) {
      final t = (elapsed - _simStart).inMicroseconds / 1e6;
      _scale = _scaleSim!.x(t);
      _scaleVel = _scaleSim!.dx(t);
      if (_scaleSim!.isDone(t)) {
        _scaleSim = null;
        _scale = _hovering ? 1 : 0;
        _scaleVel = 0;
      }
    }

    final tau = 0.02 + (widget.smoothness / 100) * (0.4 - 0.02);
    final k = 1 - math.exp(-dt / tau);
    final nx = _x + (_target.dx - _x) * k;
    final ny = _y + (_target.dy - _y) * k;
    final dist = math.sqrt(math.pow(nx - _x, 2) + math.pow(ny - _y, 2));
    final speed = dist / dt;
    _x = nx;
    _y = ny;
    if (speed > 8) {
      _angle = math.atan2(_target.dy - _y, _target.dx - _x);
    }
    final targetSquash = math.min(1.6, 1 + speed * 0.0011);
    _squash += (targetSquash - _squash) * (1 - math.exp(-dt / 0.09));

    _paint.set(
      pos: Offset(_x, _y),
      squash: _squash,
      angle: _angle,
      scale: _scale.clamp(0.0, 1.0),
    );
  }

  void _springTo(double target) {
    _tapBiteStart = null;
    _scaleSim = SpringSimulation(
      const SpringDescription(mass: 1.4, stiffness: 110, damping: 13),
      _scale,
      target,
      _scaleVel,
    );
    _simStart = _lastElapsed;
  }

  void _enter(Offset local) {
    if (!_enabled) return;
    _hovering = true;
    _target = local;
    _x = local.dx;
    _y = local.dy;
    _springTo(1);
  }

  void _leave() {
    _hovering = false;
    _springTo(0);
  }

  void _tapBite(Offset local) {
    if (!_enabled) return;
    _target = local;
    _x = local.dx;
    _y = local.dy;
    _scaleSim = null;
    _tapBiteStart = _lastElapsed;
  }

  void _activate() {
    if (!_enabled) return;
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = CanaryTokens.reduceMotion(context);
    if (reduce) return _fallback();

    final label = _Label(
      icon: widget.icon,
      label: widget.label,
      busy: widget.busy,
      color: widget.textColor,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: FocusableActionDetector(
        focusNode: _focus,
        enabled: _enabled,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) {
          if (_focused != v) setState(() => _focused = v);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Listener(
            onPointerHover: (e) {
              if (e.kind != PointerDeviceKind.mouse) return;
              if (!_hovering) {
                _enter(e.localPosition);
              } else {
                _target = e.localPosition;
              }
            },
            onPointerDown: (e) {
              if (e.kind == PointerDeviceKind.mouse) {
                _target = e.localPosition;
                return;
              }
              _tapBite(e.localPosition);
            },
            onPointerUp: (_) => _activate(),
            onPointerCancel: (_) => _leave(),
            child: MouseRegion(
              onExit: (_) => _leave(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(
                  _hovering ? -2 : 0,
                  _hovering ? -2 : 0,
                  0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CanaryTokens.rChip),
                  border: Border.all(
                    color: CanaryTokens.text,
                    width: _focused ? 3.5 : 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CanaryTokens.text,
                      offset: _hovering ? const Offset(6, 6) : const Offset(4, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CanaryTokens.rChip),
                  child: RepaintBoundary(
                    child: IntrinsicWidth(
                      child: IntrinsicHeight(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(child: _blobLayer()),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FillBitePainter(
                                  paintState: _paint,
                                  fill: widget.fill,
                                  blobSize: widget.blobSize,
                                  radius: CanaryTokens.rChip,
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                child: label,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _blobLayer() {
    final blob = CustomPaint(
      painter: _BlobPainter(
        paintState: _paint,
        color: widget.blobColor,
        radius: CanaryTokens.rChip,
      ),
    );
    if (!widget.enableGoo) return blob;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 19, -2295,
      ]),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8, tileMode: TileMode.decal),
        child: blob,
      ),
    );
  }

  Widget _fallback() {
    final bg = _pressedFallback ? CanaryTokens.canaryDeep : widget.fill;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: FocusableActionDetector(
        focusNode: _focus,
        enabled: _enabled,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) {
          if (_focused != v) setState(() => _focused = v);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: _enabled
              ? (_) => setState(() => _pressedFallback = true)
              : null,
          onTapUp: _enabled
              ? (_) {
                  setState(() => _pressedFallback = false);
                  _activate();
                }
              : null,
          onTapCancel: () => setState(() => _pressedFallback = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _enabled ? bg : bg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(CanaryTokens.rChip),
              border: Border.all(
                color: CanaryTokens.text,
                width: _focused ? 3.5 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CanaryTokens.text,
                  offset: _pressedFallback ? Offset.zero : const Offset(4, 4),
                ),
              ],
            ),
            child: _Label(
              icon: widget.icon,
              label: widget.label,
              busy: widget.busy,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.busy,
    required this.color,
    this.icon,
  });

  final String label;
  final bool busy;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: color),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.paintState,
    required this.color,
    required this.radius,
  }) : super(repaint: paintState);

  final _BitePaint paintState;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _FillBitePainter extends CustomPainter {
  _FillBitePainter({
    required this.paintState,
    required this.fill,
    required this.blobSize,
    required this.radius,
  }) : super(repaint: paintState);

  final _BitePaint paintState;
  final Color fill;
  final double blobSize;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final scale = paintState.scale;
    if (scale <= 0.001) {
      canvas.drawPath(rrect, Paint()..color = fill);
      return;
    }
    final squash = paintState.squash.clamp(0.6, 1.6);
    final d = blobSize * scale;
    final ellipse = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: d * squash,
          height: d / squash,
        ),
      );
    final matrix = Matrix4.identity()
      ..translateByDouble(paintState.pos.dx, paintState.pos.dy, 0, 1)
      ..rotateZ(paintState.angle);
    final hole = ellipse.transform(matrix.storage);
    final bitten = Path.combine(PathOperation.difference, rrect, hole);
    canvas.drawPath(bitten, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(covariant _FillBitePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.blobSize != blobSize ||
      oldDelegate.radius != radius;
}
