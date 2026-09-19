import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Surface card. Hover lifts 2 px and swaps the border to the chain gradient.
class GlowCard extends StatefulWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final reduce = CanaryTokens.reduceMotion(context);
    final hovered = _hover && !reduce;
    final duration = reduce
        ? Duration.zero
        : const Duration(milliseconds: 180);

    final inner = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CanaryTokens.rCard),
        gradient: hovered ? CanaryTokens.chain : null,
        border: hovered
            ? null
            : Border.all(color: CanaryTokens.border),
        color: hovered ? null : CanaryTokens.surface,
      ),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: CanaryTokens.surface,
          borderRadius: BorderRadius.circular(CanaryTokens.rCard - 1),
        ),
        child: widget.child,
      ),
    );

    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: inner,
    );

    if (widget.onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(CanaryTokens.rCard),
          child: card,
        ),
      );
    }

    if (widget.margin != null) {
      card = Padding(padding: widget.margin!, child: card);
    }
    return card;
  }
}
