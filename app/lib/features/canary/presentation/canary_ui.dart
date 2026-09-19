import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/canary_link.dart';

/// Small shared pieces for the Canary screens.
class CanaryUi {
  const CanaryUi._();

  static const String featureName = 'NO SUS Canary';

  /// Always visible on Canary screens. Keep it honest and short.
  static const String honestyNote =
      'Canary shows whose copy leaked, not who shared it. Phones get lost and '
      'screens get shown to friends. If two readers compare and mix their '
      'copies, the result can point at the wrong copy.';

  static String clock(DateTime time) {
    final t = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  static Future<void> openTx(BuildContext context, String txHash) async {
    final ok = await launchUrl(
      Uri.parse(canaryExplorerTxUrl(txHash)),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the explorer.')),
      );
    }
  }

  static Widget page({required List<Widget> children}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(padding: const EdgeInsets.all(24), children: children),
    ),
  );

  static Widget testnetChip(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Chip(
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.link, size: 16),
      label: Text(
        'Recorded on Monad testnet',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  );
}
