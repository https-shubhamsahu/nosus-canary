import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../domain/canary_link.dart';
import 'ui/canary_backdrop.dart';
import 'ui/canary_mark.dart';
import 'ui/wallet_button.dart';

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

  static Widget scaffold({
    required String title,
    required List<Widget> Function(BuildContext context) builder,
    List<Widget>? actions,
  }) {
    return Theme(
      data: CanaryTokens.theme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: CanaryTokens.bg,
            appBar: AppBar(
              title: Row(
                children: [
                  const CanaryMark(size: 28),
                  const SizedBox(width: 12),
                  Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                ],
              ),
              actions: actions,
            ),
            body: CanaryBackdrop(child: page(children: builder(context))),
          );
        },
      ),
    );
  }

  static Widget frame({
    required String title,
    required Widget Function(BuildContext context) body,
    List<Widget>? actions,
    PreferredSizeWidget? customAppBar,
    bool showAppBar = true,
  }) {
    return Theme(
      data: CanaryTokens.theme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: CanaryTokens.bg,
            appBar: !showAppBar
                ? null
                : customAppBar ??
                      AppBar(
                        title: Row(
                          children: [
                            const CanaryMark(size: 28),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          ...?actions,
                          const WalletButton(compact: true),
                          const SizedBox(width: 8),
                        ],
                      ),
            body: CanaryBackdrop(child: body(context)),
          );
        },
      ),
    );
  }

  static Widget missing({required String message}) {
    return Theme(
      data: CanaryTokens.theme(),
      child: Scaffold(
        backgroundColor: CanaryTokens.bg,
        appBar: AppBar(),
        body: CanaryBackdrop(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }

  static Widget page({required List<Widget> children}) => LayoutBuilder(
    builder: (context, constraints) {
      final expanded = constraints.maxWidth >= AppBreakpoints.expanded;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: expanded
                ? AppBreakpoints.contentMaxExpanded
                : AppBreakpoints.contentMaxCompact,
          ),
          child: ListView(
            padding: EdgeInsets.all(expanded ? 32 : 20),
            children: children,
          ),
        ),
      );
    },
  );
}
