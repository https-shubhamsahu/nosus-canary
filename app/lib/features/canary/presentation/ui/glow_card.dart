import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Paper card with an ink outline and a hard ink shadow. Hover lifts it and
/// turns the shadow orange.
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
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 180);

    final inner = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(
        hovered ? -3 : 0,
        hovered ? -3 : 0,
        0,
      ),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: CanaryTokens.surface,
        borderRadius: BorderRadius.circular(CanaryTokens.rCard),
        border: Border.all(color: CanaryTokens.text, width: 2),
        boxShadow: [
          BoxShadow(
            color: hovered ? CanaryTokens.canary : CanaryTokens.text,
            offset: hovered ? const Offset(8, 8) : const Offset(5, 5),
          ),
        ],
      ),
      child: widget.child,
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
