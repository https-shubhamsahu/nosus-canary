import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

/// Dismissible strip shown when [SupabaseService.isReachable] is false — a
/// lighter-weight alternative to full-screen dead-end blocks (see
/// AuthGate's unreachable state) or the purely cosmetic offline dot
/// previously used on its own in workspace_tab.dart.
///
/// [isReachable] is a point-in-time flag set once during startup (see
/// SupabaseService.initialize) rather than a live connectivity stream, so
/// this banner's state is read once per build like every other consumer of
/// that flag in the app — it does not re-check reachability itself.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || SupabaseService.instance.isReachable) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NoSusTheme.s16,
        vertical: NoSusTheme.s12,
      ),
      decoration: BoxDecoration(
        color: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: NoSusTheme.s8),
          Expanded(
            child: Text(
              "You're offline — showing the last saved data.",
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _dismissed = true),
            tooltip: 'Dismiss offline notice',
            icon: Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
