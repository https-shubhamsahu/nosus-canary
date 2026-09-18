import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/config/domain/app_update.dart';
import '../features/config/presentation/providers/app_update_provider.dart';
import '../theme.dart';

/// Dismissible strip shown when a newer app version is available — same
/// visual language and per-session dismissal contract as [OfflineBanner].
/// Renders nothing on web/non-Android or when the app is current (see
/// appUpdateProvider for the platform gating).
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  Future<void> _openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final status = ref.watch(appUpdateProvider).value;
    if (status is! AppUpdateAvailable) return const SizedBox.shrink();

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
            Icons.system_update_alt_outlined,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: NoSusTheme.s8),
          Expanded(
            child: Text(
              'Update available: v${status.latestVersion}',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => _openDownload(status.downloadUrl),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: NoSusTheme.s8),
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              'UPDATE',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _dismissed = true),
            tooltip: 'Dismiss update notice',
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
