import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Retro "quest" progress: 1 WRITE -> 2 SHARE -> 3 CATCH.
class QuestSteps extends StatelessWidget {
  const QuestSteps({super.key, required this.current});

  /// 0 = write, 1 = share, 2 = catch.
  final int current;

  static const _steps = ['WRITE', 'SHARE', 'CATCH'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of 3: ${_steps[current].toLowerCase()}',
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: i <= current
                      ? CanaryTokens.text
                      : CanaryTokens.text.withValues(alpha: 0.2),
                ),
              ),
            _pill(i),
          ],
        ],
      ),
    );
  }

  Widget _pill(int i) {
    final active = i == current;
    final done = i < current;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 14, 5),
      decoration: BoxDecoration(
        color: active || done ? CanaryTokens.canary : CanaryTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: i <= current
              ? CanaryTokens.text
              : CanaryTokens.text.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: active
            ? const [BoxShadow(color: CanaryTokens.text, offset: Offset(3, 3))]
            : null,
      ),
      child: Text(
        '${i + 1} ${_steps[i]}${done ? '  OK' : ''}',
        style: TextStyle(
          fontFamily: CanaryTokens.monoFont,
          fontSize: 22,
          letterSpacing: 1.5,
          height: 1,
          color: i <= current
              ? CanaryTokens.text
              : CanaryTokens.text.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Small pixel-caps label used above form groups.
class RetroLabel extends StatelessWidget {
  const RetroLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontFamily: CanaryTokens.monoFont,
      fontSize: 22,
      letterSpacing: 1.5,
      height: 1,
      color: CanaryTokens.text,
    ),
  );
}
