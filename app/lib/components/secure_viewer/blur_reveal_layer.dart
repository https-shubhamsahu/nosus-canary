import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/viewer_config.dart';
import '../../core/mascot/mascot_controller.dart';
import '../../core/mascot/mascot_state.dart';
import '../../core/mascot/mascot_view.dart';

/// Core touch-blur engine for the NO SUS secure document viewer.
///
/// Obscures the entire canvas behind a blur/mask overlay by default.
/// When the user touches the screen, the entire blur layer animates to clear (unblurred),
/// allowing view of the whole screen. When the finger lifts, it blurs again.
class BlurRevealLayer extends ConsumerStatefulWidget {
  /// The protected document content. Wrapped in [RepaintBoundary] internally.
  final Widget child;

  /// An always-visible overlay that sits above the blur (e.g., watermark).
  final Widget? overlay;

  /// Animation + blur behavior configuration.
  final ViewerConfig config;

  /// Whether to show the "TOUCH TO REVEAL" hint when content is blurred.
  final bool showHint;

  /// Whether the layer starts revealed (false) or concealed (true, the
  /// existing default). Web viewers that don't want the sender's default
  /// touch-to-reveal blur still pass a [forceConcealSignal] so a detected
  /// security event can conceal on demand — this lets them start revealed.
  final bool initiallyConcealed;

  /// Emits to force an immediate conceal regardless of current touch state
  /// — e.g. [WebSecurityGuard] detected DevTools opening or repeated tab
  /// hiding. Does not change [showHint] or block the user from touching to
  /// reveal again afterward; this is a reactive deterrent, not a lock.
  final Stream<void>? forceConcealSignal;

  const BlurRevealLayer({
    super.key,
    required this.child,
    this.overlay,
    this.config = const ViewerConfig(),
    this.showHint = true,
    this.initiallyConcealed = true,
    this.forceConcealSignal,
  });

  @override
  ConsumerState<BlurRevealLayer> createState() => _BlurRevealLayerState();
}

class _BlurRevealLayerState extends ConsumerState<BlurRevealLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  StreamSubscription<void>? _forceConcealSub;

  // Number of currently active pointers (supports multi-touch tracking)
  int _activePointers = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      value: widget.initiallyConcealed ? 1.0 : 0.0,
      vsync: this,
    );

    _forceConcealSub = widget.forceConcealSignal?.listen((_) {
      if (!mounted) return;
      _controller.animateTo(
        1.0,
        duration: widget.config.concealDuration,
        curve: widget.config.concealCurve,
      );
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
    });

    if (widget.initiallyConcealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Blurred on open — Nox is guarding this document.
        if (mounted) ref.read(noxMascotProvider.notifier).play(MascotMood.protect);
      });
    }
  }

  @override
  void dispose() {
    _forceConcealSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ─── Pointer Event Handlers ───────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;

    if (_activePointers == 1) {
      _controller.animateTo(
        0.0,
        duration: widget.config.revealDuration,
        curve: widget.config.revealCurve,
      );
      // The reveal tap is the exact moment Nox nods it through.
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
    }
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 20);

    if (_activePointers == 0) {
      _controller.animateTo(
        1.0,
        duration: widget.config.concealDuration,
        curve: widget.config.concealCurve,
      );
      ref.read(noxMascotProvider.notifier).play(MascotMood.protect);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp, // System interruptions = conceal
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Protected document content ──────────────────────────
          RepaintBoundary(child: widget.child),

          // ── Layer 2: Animated blur overlay ───────────────────────────────
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final sigma = _controller.value * widget.config.maxBlurSigma;
                if (sigma < 0.05) {
                  return const SizedBox.shrink();
                }

                final tintAlpha = _controller.value * (isDark ? 0.25 : 0.15);

                return BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                    tileMode: ui.TileMode.clamp,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: tintAlpha),
                  ),
                );
              },
            ),
          ),

          // ── Layer 3: Always-visible overlay (watermark) ──────────────────
          if (widget.overlay != null) widget.overlay!,

          // ── Layer 4: Touch hint ───────────────────────────────────────────
          if (widget.showHint) _TouchRevealHint(animation: _controller),
        ],
      ),
    );
  }
}

// ─── Touch Reveal Hint ───────────────────────────────────────────────────────

class _TouchRevealHint extends StatelessWidget {
  final Animation<double> animation;

  const _TouchRevealHint({required this.animation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return IgnorePointer(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotView(
                character: MascotCharacter.nox,
                size: 28,
                fallback: Icon(
                  Icons.touch_app_outlined,
                  size: 28,
                  color: textColor.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'TOUCH TO REVEAL',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
