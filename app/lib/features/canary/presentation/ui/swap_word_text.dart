import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../../domain/canary_fingerprint.dart';

/// Renders a copy with swapped words flipping between variants.
class SwapWordText extends StatefulWidget {
  const SwapWordText({
    super.key,
    required this.plan,
    required this.codewords,
    this.labels = const [],
    this.interval = const Duration(milliseconds: 1800),
  });

  final CanaryPlan plan;
  final List<List<int>> codewords;
  final List<String> labels;
  final Duration interval;

  @override
  State<SwapWordText> createState() => _SwapWordTextState();
}

class _SwapWordTextState extends State<SwapWordText> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  @override
  void didUpdateWidget(covariant SwapWordText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.codewords.length != widget.codewords.length) {
      _index = 0;
    }
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (CanaryTokens.reduceMotion(context) || widget.codewords.length < 2) {
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.codewords.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.codewords.isEmpty) return const SizedBox.shrink();
    final i = _index.clamp(0, widget.codewords.length - 1);
    final tokens = renderCanaryTokens(widget.plan, widget.codewords[i]);
    final original = widget.plan.tokens;
    final label = i < widget.labels.length ? widget.labels[i] : 'Copy ${i + 1}';
    final reduce = CanaryTokens.reduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: CanaryTokens.monoFont,
            color: CanaryTokens.canary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              for (var t = 0; t < tokens.length; t++)
                if (tokens[t] == original[t])
                  TextSpan(
                    text: tokens[t],
                    style: const TextStyle(
                      fontFamily: CanaryTokens.bodyFont,
                      fontSize: 16,
                      height: 1.5,
                      color: CanaryTokens.text,
                    ),
                  )
                else
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: AnimatedSwitcher(
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        if (reduce) return child;
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        tokens[t],
                        key: ValueKey('$i-$t-${tokens[t]}'),
                        style: const TextStyle(
                          fontFamily: CanaryTokens.displayFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: CanaryTokens.canary,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
