import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../../domain/canary_fingerprint.dart';
import '../../domain/canary_models.dart';
import '../canary_ui.dart';
import 'canary_mark.dart';
import 'chain_chip.dart';
import 'copy_badge.dart';
import 'glow_card.dart';

/// Hero result for confident / exact / likely matches.
class CanaryReveal extends StatefulWidget {
  const CanaryReveal({
    super.key,
    required this.match,
    required this.status,
    this.likely = false,
  });

  final CanaryMatch match;
  final CanaryNoteStatus? status;
  final bool likely;

  @override
  State<CanaryReveal> createState() => _CanaryRevealState();
}

class _CanaryRevealState extends State<CanaryReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _pop;
  late final Animation<double> _type;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    _type = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.4, 1, curve: Curves.linear),
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
    final index = widget.match.copyIndex;
    final copy = index == null ? null : widget.status?.copy(index);
    final who = copy?.readerName;
    final accent = widget.likely ? CanaryTokens.warn : CanaryTokens.canary;

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: _pop,
            child: const CanaryMark(size: 72),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.likely ? 'MOST LIKELY' : 'THE CANARY SANG',
              style: TextStyle(
                fontFamily: CanaryTokens.displayFont,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (who != null && who.isNotEmpty) ...[
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _type,
              builder: (context, _) {
                final n = (who.length * _type.value).ceil().clamp(0, who.length);
                return Text(
                  who.substring(0, n),
                  style: TextStyle(
                    fontFamily: CanaryTokens.displayFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          if (index != null)
            CopyBadge(
              copyIndex: index,
              copyCount: widget.status?.copyCount ?? (index + 1),
              readerName: who,
              fill: accent,
            ),
          if (copy != null) ...[
            const SizedBox(height: 12),
            Text(
              'Opened ${CanaryUi.clock(copy.openedAt)}',
              style: const TextStyle(fontFamily: CanaryTokens.monoFont),
            ),
            if (copy.openTxHash != null) ...[
              const SizedBox(height: 8),
              ChainChip(label: 'Proof on Monad', txHash: copy.openTxHash),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            widget.likely
                ? '${widget.match.agreeing} of ${widget.match.known} fingerprints match. Treat this as a strong hint, not proof.'
                : widget.match.kind == CanaryMatchKind.exactMarker
                    ? 'Matched by the hidden marker in the text.'
                    : '${widget.match.agreeing} of ${widget.match.known} fingerprints match.',
            style: const TextStyle(color: CanaryTokens.textDim),
          ),
        ],
      ),
    );
  }
}

/// Orange scan line over pasted text. Completes in 900 ms.
class LeakScanOverlay extends StatefulWidget {
  const LeakScanOverlay({
    super.key,
    required this.child,
    required this.active,
  });

  final Widget child;
  final bool active;

  @override
  State<LeakScanOverlay> createState() => _LeakScanOverlayState();
}

class _LeakScanOverlayState extends State<LeakScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant LeakScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (CanaryTokens.reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    } else if (!widget.active && oldWidget.active) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _ScanPainter(_c),
      child: widget.child,
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final y = size.height * t;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 8, size.width, 16),
      Paint()..color = CanaryTokens.canary.withValues(alpha: 0.45),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, y - 1.5, size.width, 3),
      Paint()..color = CanaryTokens.text,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Lights fingerprint words as the scan runs (orange = found, grey = unknown).
class ScanHitChips extends StatefulWidget {
  const ScanHitChips({
    super.key,
    required this.plan,
    required this.leak,
    required this.active,
  });

  final CanaryPlan plan;
  final String leak;
  final bool active;

  @override
  State<ScanHitChips> createState() => _ScanHitChipsState();
}

class _ScanHitChipsState extends State<ScanHitChips>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (!widget.active) _c.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant ScanHitChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (CanaryTokens.reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    } else if (!widget.active) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bits = readCanaryBits(widget.leak, widget.plan);
    final n = bits.length;
    if (n == 0) return const SizedBox.shrink();
    final shown = n > 12 ? 12 : n;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < shown; i++)
              Opacity(
                opacity: _c.value >= (i + 1) / shown ? 1 : 0.2,
                child: _hitChip(widget.plan.slots[i], bits[i]),
              ),
          ],
        );
      },
    );
  }

  Widget _hitChip(CanarySlot slot, int? bit) {
    final label = switch (bit) {
      0 => slot.original,
      1 => slot.alternate,
      _ => slot.original,
    };
    final found = bit != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: found
            ? CanaryTokens.canary.withValues(alpha: 0.18)
            : CanaryTokens.surfaceHi,
        borderRadius: BorderRadius.circular(CanaryTokens.rChip),
        border: Border.all(
          color: found ? CanaryTokens.canary : CanaryTokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: CanaryTokens.monoFont,
            fontSize: 18,
            color: found ? CanaryTokens.canaryHi : CanaryTokens.textDim,
          ),
        ),
      ),
    );
  }
}
