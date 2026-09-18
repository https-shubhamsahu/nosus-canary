import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/presentation/providers/tour_providers.dart';
import '../theme.dart';

/// One anchored tip: a spotlight cut out around [targetKey]'s widget, plus a
/// bubble explaining what it is for.
class CoachMarkStep {
  /// Must be one of [TourSteps] — it is the persistence key.
  final String id;

  /// The widget to spotlight. If it is not mounted and laid out when the step
  /// comes up, the bubble is centred instead of anchored, rather than skipped:
  /// the explanation is the point, the highlight is decoration.
  final GlobalKey targetKey;
  final String title;
  final String body;

  /// Extra padding around the cut-out, so the highlight does not sit flush
  /// against the control's edge.
  final double inflate;

  const CoachMarkStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.body,
    this.inflate = 8,
  });
}

/// Geometry for keeping a tip inside the visible safe rectangle.
///
/// Flutter web typically reports `padding.bottom == 0` even when Chrome's
/// toolbar and the Android gesture bar overlay the canvas. Placement uses
/// view padding plus a web chrome floor so the action row is never clipped.
@visibleForTesting
abstract final class CoachMarkPlacement {
  static const double webBottomChrome = 32;

  static double topInset(MediaQueryData media) =>
      math.max(media.padding.top, media.viewPadding.top);

  static double bottomInset(MediaQueryData media, {required bool isWeb}) {
    return math.max(
      media.viewInsets.bottom,
      math.max(
        media.padding.bottom,
        math.max(media.viewPadding.bottom, isWeb ? webBottomChrome : 0),
      ),
    );
  }

  static Rect safeViewport(
    Size screen,
    MediaQueryData media, {
    required bool isWeb,
  }) {
    final top = topInset(media) + NoSusTheme.s12;
    final bottom =
        screen.height - bottomInset(media, isWeb: isWeb) - NoSusTheme.s12;
    return Rect.fromLTRB(
      NoSusTheme.s24,
      top,
      math.max(NoSusTheme.s24, screen.width - NoSusTheme.s24),
      math.max(top, bottom),
    );
  }

  static bool targetVisible(Rect? target, Rect viewport) {
    if (target == null) return false;
    return target.overlaps(viewport);
  }

  static bool placeBelow(Rect target, Rect viewport) {
    final spaceBelow = viewport.bottom - (target.bottom + NoSusTheme.s16);
    final spaceAbove = target.top - NoSusTheme.s16 - viewport.top;
    const minimumReadableHeight = 160.0;
    return spaceBelow >= minimumReadableHeight || spaceBelow >= spaceAbove;
  }
}

/// Presents a sequence of [CoachMarkStep]s, one at a time, over the current
/// route.
///
/// Call from a post-frame callback — it measures the target's render box, which
/// does not exist until after layout.
///
/// Accessibility: the bubble carries the full explanation as text and is
/// announced as a live region, so the tip is complete without seeing the
/// highlight. The scrim animation is dropped when the platform asks for reduced
/// motion.
abstract final class CoachMarks {
  static bool _isShowing = false;

  static Future<void> showSequence(
    BuildContext context,
    WidgetRef ref,
    List<CoachMarkStep> steps,
  ) async {
    // One sequence at a time. Two tabs racing to present on the same frame
    // would otherwise stack overlays on top of each other.
    if (_isShowing) return;
    if (!ref.read(tipsEnabledProvider)) return;

    final progress = ref.read(tourProgressProvider.notifier);
    final pending = steps
        .where((s) => !progress.hasSeen(s.id))
        .toList(growable: false);
    if (pending.isEmpty) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _isShowing = true;
    try {
      for (var i = 0; i < pending.length; i++) {
        if (!context.mounted) break;
        final outcome = await _showOne(
          overlay,
          context,
          pending[i],
          isLast: i == pending.length - 1,
          index: i,
          total: pending.length,
        );
        await progress.markSeen([pending[i].id]);
        if (outcome == _CoachMarkOutcome.skipAll) {
          // "Skip" means skip the rest of this sequence, not suppress tips
          // forever — that is what the Settings toggle is for.
          await progress.markSeen(pending.skip(i + 1).map((s) => s.id));
          break;
        }
      }
    } finally {
      _isShowing = false;
    }
  }

  static Future<_CoachMarkOutcome> _showOne(
    OverlayState overlay,
    BuildContext context,
    CoachMarkStep step, {
    required bool isLast,
    required int index,
    required int total,
  }) {
    final completer = Completer<_CoachMarkOutcome>();
    late OverlayEntry entry;

    void close(_CoachMarkOutcome outcome) {
      if (completer.isCompleted) return;
      entry.remove();
      completer.complete(outcome);
    }

    entry = OverlayEntry(
      builder: (overlayContext) => _CoachMarkLayer(
        step: step,
        isLast: isLast,
        index: index,
        total: total,
        onNext: () => close(_CoachMarkOutcome.next),
        onSkip: () => close(_CoachMarkOutcome.skipAll),
      ),
    );

    overlay.insert(entry);
    return completer.future;
  }
}

enum _CoachMarkOutcome { next, skipAll }

class _CoachMarkLayer extends StatefulWidget {
  final CoachMarkStep step;
  final bool isLast;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachMarkLayer({
    required this.step,
    required this.isLast,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<_CoachMarkLayer> createState() => _CoachMarkLayerState();
}

class _CoachMarkLayerState extends State<_CoachMarkLayer>
    with WidgetsBindingObserver {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeMetrics() {
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final targetContext = widget.step.targetKey.currentContext;
    if (targetContext == null) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final box = targetContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = (offset & box.size).inflate(widget.step.inflate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screen = media.size;
    final reduceMotion = media.disableAnimations;

    final rect = _targetRect;
    final bubble = _CoachMarkBubble(
      step: widget.step,
      isLast: widget.isLast,
      index: widget.index,
      total: widget.total,
      onNext: widget.onNext,
      onSkip: widget.onSkip,
    );

    final safe = CoachMarkPlacement.safeViewport(screen, media, isWeb: kIsWeb);
    final anchored = CoachMarkPlacement.targetVisible(rect, safe);
    final placeBelow =
        anchored && rect != null && CoachMarkPlacement.placeBelow(rect, safe);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Scrim. Tapping anywhere advances — a coach mark that traps you
          // until you find the right button is worse than the confusion it
          // was meant to fix.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Dismiss tip',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onNext,
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    target: rect,
                    color: Colors.black.withValues(alpha: isDark ? 0.72 : 0.55),
                  ),
                ),
              ),
            ),
          ),
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NoSusTheme.r12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: safe.left,
            right: screen.width - safe.right,
            top: safe.top,
            bottom: screen.height - safe.bottom,
            child: Align(
              alignment: !anchored
                  ? Alignment.center
                  : placeBelow
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              child: _animateBubble(bubble, reduceMotion),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animateBubble(Widget bubble, bool reduceMotion) {
    if (reduceMotion) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: bubble,
    );
  }
}

class _CoachMarkBubble extends StatelessWidget {
  final CoachMarkStep step;
  final bool isLast;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachMarkBubble({
    required this.step,
    required this.isLast,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dCard : Colors.white;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;

    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!isLast)
          TextButton(
            onPressed: onSkip,
            child: Text(
              'SKIP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: fg.withValues(alpha: 0.55),
              ),
            ),
          ),
        const SizedBox(width: NoSusTheme.s8),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: fg,
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NoSusTheme.r12),
            ),
          ),
          child: Text(
            isLast ? 'DONE' : 'NEXT',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );

    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: NoSusTheme.s8),
            child: Text(
              'TIP ${index + 1} OF $total',
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 9,
                letterSpacing: 1.5,
                color: fg.withValues(alpha: 0.45),
              ),
            ),
          ),
        Text(
          step.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
        const SizedBox(height: NoSusTheme.s8),
        Text(
          step.body,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.55,
            color: fg.withValues(alpha: 0.75),
          ),
        ),
      ],
    );

    return Semantics(
      liveRegion: true,
      // The whole bubble reads as one announcement; the buttons below carry
      // their own labels.
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(NoSusTheme.r16),
          border: Border.all(color: fg.withValues(alpha: 0.12), width: 0.75),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep DONE/SKIP pinned even when the copy is taller than the
            // remaining safe viewport — the previous single scroll view let
            // the action row clip under the Android home indicator.
            const actionsReserve = 76.0;
            final maxCopyHeight = constraints.hasBoundedHeight
                ? math.max(64.0, constraints.maxHeight - actionsReserve)
                : double.infinity;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                NoSusTheme.s24,
                NoSusTheme.s24,
                NoSusTheme.s24,
                NoSusTheme.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxCopyHeight),
                    child: SingleChildScrollView(child: copy),
                  ),
                  const SizedBox(height: NoSusTheme.s16),
                  actions,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fills the screen with [color], minus a rounded hole over [target].
class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final Color color;

  const _SpotlightPainter({required this.target, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final paint = Paint()..color = color;

    if (target == null) {
      canvas.drawRect(screen, paint);
      return;
    }

    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(NoSusTheme.r12)),
      );
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(screen),
      hole,
    );
    canvas.drawPath(scrim, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.color != color;
}
