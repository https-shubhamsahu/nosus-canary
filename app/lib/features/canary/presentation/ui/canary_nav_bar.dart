import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_mode.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../theme.dart';
import 'canary_mark.dart';
import 'wallet_button.dart';

/// Desktop & mobile top navigation bar for the Canary site.
class CanaryTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CanaryTopBar({
    super.key,
    required this.onHowItWorks,
    required this.onNotes,
    required this.onCheckLeak,
    this.standalone = true,
  });

  final VoidCallback onHowItWorks;
  final VoidCallback onNotes;
  final VoidCallback onCheckLeak;
  final bool standalone;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  Future<void> _openNoSusApp(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse('https://nosus.foo'),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open nosus.foo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = AppBreakpoints.isExpanded(context);
    final width = MediaQuery.sizeOf(context).width;
    // Keep the bar on one line: the centre links need ~1440 px next to a
    // connected wallet pill; the testnet badge needs ~1180 px.
    final showNav = expanded && width >= 1440;
    final showPill = expanded && width >= 1180;
    final pad = expanded ? 32.0 : 16.0;

    return Container(
      height: expanded ? 72 : 64,
      decoration: BoxDecoration(
        color: CanaryTokens.bg.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: CanaryTokens.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMaxExpanded,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CanaryMark(size: 28),
                    SizedBox(width: 10),
                    Text(
                      'NO SUS Canary',
                      style: TextStyle(
                        fontFamily: CanaryTokens.displayFont,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: CanaryTokens.text,
                      ),
                    ),
                  ],
                ),

                // Center navigation (wide desktop only)
                if (showNav)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavLink(label: 'How it works', onTap: onHowItWorks),
                      const _NavDivider(),
                      _NavLink(label: 'My notes', onTap: onNotes),
                      const _NavDivider(),
                      _NavLink(label: 'Check a leak', onTap: onCheckLeak),
                    ],
                  ),

                // Right side: Monad pulse pill + NO SUS app link
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPill) ...[
                      const MonadTestnetPill(),
                      const SizedBox(width: 14),
                    ],
                    WalletButton(compact: !expanded),
                    const SizedBox(width: 12),
                    if (standalone)
                      expanded
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: CanaryTokens.text,
                                  side: const BorderSide(
                                    color: CanaryTokens.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      CanaryTokens.rChip,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => _openNoSusApp(context),
                                child: const Text(
                                  'NO SUS app ↗',
                                  style: TextStyle(
                                    fontFamily: CanaryTokens.bodyFont,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : Semantics(
                              button: true,
                              label: 'Open the NO SUS app',
                              child: IconButton(
                                tooltip: 'Open the NO SUS app',
                                icon: const Icon(
                                  Icons.open_in_new,
                                  color: CanaryTokens.text,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () => _openNoSusApp(context),
                              ),
                            ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        '·',
        style: TextStyle(
          color: CanaryTokens.textDim,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  fontFamily: CanaryTokens.monoFont,
                  fontSize: 22,
                  letterSpacing: 1,
                  color: _hovered ? CanaryTokens.text : CanaryTokens.textDim,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 3,
                width: _hovered ? 40 : 0,
                decoration: BoxDecoration(
                  color: CanaryTokens.canary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing "Monad testnet" indicator pill.
class MonadTestnetPill extends StatefulWidget {
  const MonadTestnetPill({super.key});

  @override
  State<MonadTestnetPill> createState() => _MonadTestnetPillState();
}

class _MonadTestnetPillState extends State<MonadTestnetPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _controller.stop();
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CanaryTokens.surface,
        borderRadius: BorderRadius.circular(CanaryTokens.rChip),
        border: Border.all(color: CanaryTokens.text, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final opacity = CanaryTokens.reduceMotion(context)
                  ? 1.0
                  : 0.4 + 0.6 * _controller.value;
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CanaryTokens.canary.withValues(alpha: opacity),
                  border: Border.all(color: CanaryTokens.text, width: 1.5),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'MONAD TESTNET',
            style: TextStyle(
              fontFamily: CanaryTokens.monoFont,
              fontSize: 21,
              letterSpacing: 1,
              color: CanaryTokens.text,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin dashed connector line with an orange dot traveling every 4 seconds.
class HowItWorksConnector extends StatefulWidget {
  const HowItWorksConnector({super.key});

  @override
  State<HowItWorksConnector> createState() => _HowItWorksConnectorState();
}

class _HowItWorksConnectorState extends State<HowItWorksConnector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (CanaryTokens.reduceMotion(context)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 16),
          painter: _DashedLinePainter(_controller.value),
        );
      },
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CanaryTokens.border
      ..strokeWidth = 1;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    var startX = 0.0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    final dotX = size.width * progress;
    final dotPaint = Paint()..color = CanaryTokens.canary;
    canvas.drawCircle(Offset(dotX, y), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Standalone Canary footer.
class CanaryFooter extends StatelessWidget {
  const CanaryFooter({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CanaryTokens.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text(
              'Built at Monad Blitz Mumbai V4',
              style: TextStyle(color: CanaryTokens.textDim, fontSize: 13),
            ),
            const Text('·', style: TextStyle(color: CanaryTokens.textDim)),
            InkWell(
              onTap: () => _openUrl(context, 'https://nosus.foo'),
              child: const Text(
                'Part of NO SUS ↗',
                style: TextStyle(
                  color: CanaryTokens.textDim,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text('·', style: TextStyle(color: CanaryTokens.textDim)),
            InkWell(
              onTap: () => _openUrl(context, kCanaryRepoUrl),
              child: const Text(
                'GitHub ↗',
                style: TextStyle(
                  color: CanaryTokens.textDim,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text('·', style: TextStyle(color: CanaryTokens.textDim)),
            const Text(
              'Use harmless test notes only',
              style: TextStyle(color: CanaryTokens.textDim, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
