import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Plain paper page background. No grid, no gradients.
class CanaryBackdrop extends StatelessWidget {
  const CanaryBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: CanaryTokens.bg, child: child);
}
