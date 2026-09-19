import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// The NO SUS pixel canary (same sprite as the README and the hub page).
/// Never use an emoji glyph for this mark.
class CanaryMark extends StatelessWidget {
  const CanaryMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NO SUS Canary',
      image: true,
      child: SizedBox(
        width: size,
        height: size * 14 / 16,
        child: const CustomPaint(painter: CanaryMarkPainter()),
      ),
    );
  }
}

class CanaryMarkPainter extends CustomPainter {
  const CanaryMarkPainter();

  static const _rows = [
    '.....KKKKK......',
    '...KKYYYYYKK....',
    '..KYYYYYYYWWK...',
    '..KYYYYYYYWKK...',
    '.KYYYYYYYYYYKOO.',
    '.KYYYYYYYYYYKOOO',
    '.KYyyyyYYYYYK...',
    'KYYyyyyyYYYYK...',
    'KYYYyyyyYYYK....',
    '.KYYYyyYYYYK....',
    '..KYYYYYYYK.....',
    '...KKKKKKK......',
    '....K...K.......',
    '...KK..KK.......',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.width / 16 < size.height / 14)
        ? size.width / 16
        : size.height / 14;
    final colors = <String, Color>{
      'K': CanaryTokens.text,
      'O': CanaryTokens.text,
      'Y': CanaryTokens.canary,
      'y': CanaryTokens.bg,
      'W': CanaryTokens.bg,
    };
    for (var y = 0; y < _rows.length; y++) {
      final row = _rows[y];
      var x = 0;
      while (x < row.length) {
        final c = row[x];
        if (c == '.') {
          x++;
          continue;
        }
        var end = x;
        while (end < row.length && row[end] == c) {
          end++;
        }
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, (end - x) * cell + 0.5, cell + 0.5),
          Paint()..color = colors[c]!,
        );
        x = end;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
