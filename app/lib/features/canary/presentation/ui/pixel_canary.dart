import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// The NO SUS pixel canary, alive: it bobs, flaps in short bursts, blinks,
/// and (with [sing]) lets pixel music notes float up from its beak.
/// Shows a still bird when animations are disabled.
class PixelCanary extends StatefulWidget {
  const PixelCanary({super.key, this.size = 64, this.sing = false});

  /// Width in logical pixels; height is size * 14 / 16.
  final double size;
  final bool sing;

  @override
  State<PixelCanary> createState() => _PixelCanaryState();
}

class _PixelCanaryState extends State<PixelCanary>
    with SingleTickerProviderStateMixin {
  static const _cycleMs = 4000;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _cycleMs),
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = CanaryTokens.reduceMotion(context);
    if (_still) {
      _c.stop();
      _c.value = 0;
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
    final w = widget.size;
    final h = w * 14 / 16;
    return Semantics(
      label: 'NO SUS canary',
      image: true,
      child: SizedBox(
        width: w,
        height: h,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * _cycleMs;
            // Flap in bursts: wings beat for the first 900 ms of every 2 s.
            final flap =
                !_still && (t % 2000) < 900 && ((t / 150).floor() % 2 == 1);
            final blink = !_still && t > 3650 && t < 3800;
            final bob = _still
                ? 0.0
                : -math.sin(_c.value * 4 * math.pi).abs() * w * 0.06;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(0, bob),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _BirdPainter(flap: flap, blink: blink),
                  ),
                ),
                if (widget.sing && !_still)
                  for (var i = 0; i < 2; i++) _note(t, i, w),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _note(double t, int i, double w) {
    // Each note lives 2 s, the second starts 1 s after the first.
    final p = ((t + i * 1000) % 2000) / 2000;
    final opacity = p < 0.15 ? p / 0.15 : (1 - p).clamp(0.0, 1.0);
    return Positioned(
      left: w * (0.92 + 0.18 * p) + i * w * 0.08,
      top: w * (0.05 - 0.45 * p),
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size(w * 0.16, w * 0.19),
          painter: const _NotePainter(),
        ),
      ),
    );
  }
}

const _frameA = [
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
const _frameB = [
  '.....KKKKK......',
  '...KKYYYYYKK....',
  '..KYYYYYYYWWK...',
  '..KYYYYYYYWKK...',
  '.KYYyyYYYYYYKOO.',
  '.KYyyyyYYYYYKOOO',
  '.KYYyyyYYYYYK...',
  'KYYYYYYYYYYYK...',
  'KYYYYYYYYYYK....',
  '.KYYYYYYYYYK....',
  '..KYYYYYYYK.....',
  '...KKKKKKK......',
  '....K...K.......',
  '...KK..KK.......',
];

void _paintSprite(
  Canvas canvas,
  List<String> rows,
  double cell,
  Map<String, Color> colors,
) {
  for (var y = 0; y < rows.length; y++) {
    final row = rows[y];
    var x = 0;
    while (x < row.length) {
      final c = row[x];
      final color = colors[c];
      if (color == null) {
        x++;
        continue;
      }
      var end = x;
      while (end < row.length && row[end] == c) {
        end++;
      }
      canvas.drawRect(
        Rect.fromLTWH(x * cell, y * cell, (end - x) * cell + 0.5, cell + 0.5),
        Paint()..color = color,
      );
      x = end;
    }
  }
}

class _BirdPainter extends CustomPainter {
  const _BirdPainter({required this.flap, required this.blink});

  final bool flap;
  final bool blink;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 16;
    _paintSprite(canvas, flap ? _frameB : _frameA, cell, {
      'K': CanaryTokens.text,
      'O': CanaryTokens.text,
      'Y': CanaryTokens.canary,
      'y': CanaryTokens.bg,
      'W': blink ? CanaryTokens.text : CanaryTokens.bg,
    });
  }

  @override
  bool shouldRepaint(covariant _BirdPainter old) =>
      old.flap != flap || old.blink != blink;
}

class _NotePainter extends CustomPainter {
  const _NotePainter();

  static const _rows = [
    '...##.',
    '...#.#',
    '...#..',
    '...#..',
    '.###..',
    '####..',
    '.##...',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintSprite(canvas, _rows, size.width / 6, {'#': CanaryTokens.text});
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-width ink band with facts scrolling past, retro ticker style.
class TickerBand extends StatefulWidget {
  const TickerBand({super.key, required this.items});

  final List<String> items;

  @override
  State<TickerBand> createState() => _TickerBandState();
}

class _TickerBandState extends State<TickerBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.stop();
      _c.value = 0;
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
    const style = TextStyle(
      fontFamily: CanaryTokens.monoFont,
      fontSize: 26,
      letterSpacing: 1.5,
      color: CanaryTokens.bg,
      height: 1,
    );
    final spans = <InlineSpan>[
      for (final item in widget.items) ...[
        TextSpan(text: item),
        const TextSpan(
          text: '   *   ',
          style: TextStyle(color: CanaryTokens.canary),
        ),
      ],
    ];
    final segment = TextSpan(style: style, children: spans);
    final painter = TextPainter(
      text: segment,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final segW = painter.width;

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: CanaryTokens.text,
        border: Border.symmetric(
          horizontal: BorderSide(color: CanaryTokens.canary, width: 4),
        ),
      ),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copies = (constraints.maxWidth / segW).ceil() + 2;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Transform.translate(
                offset: Offset(-_c.value * segW, 0),
                child: child,
              ),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < copies; i++)
                      Text.rich(segment, maxLines: 1, softWrap: false),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
