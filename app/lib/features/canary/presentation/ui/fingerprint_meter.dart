import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Segmented bar: one tick per required slot, orange until enough, then green.
class FingerprintMeter extends StatelessWidget {
  const FingerprintMeter({
    super.key,
    required this.found,
    required this.requiredSlots,
  });

  final int found;
  final int requiredSlots;

  @override
  Widget build(BuildContext context) {
    final n = requiredSlots.clamp(1, 24);
    final filled = found.clamp(0, n);
    final enough = found >= requiredSlots && found > 0;
    final reduce = CanaryTokens.reduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    child: AnimatedContainer(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? (enough ? CanaryTokens.ok : CanaryTokens.canary)
                          : CanaryTokens.surfaceHi,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          found == 0
              ? 'No swappable words yet · need $requiredSlots'
              : enough
              ? '$found swappable words · ready for this reader count'
              : '$found of $requiredSlots swappable words',
          style: const TextStyle(
            fontFamily: CanaryTokens.monoFont,
            color: CanaryTokens.textDim,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}
