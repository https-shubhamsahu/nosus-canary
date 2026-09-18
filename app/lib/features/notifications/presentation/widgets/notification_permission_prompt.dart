import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../theme.dart';
import '../../../analytics/data/analytics_service.dart';
import '../../data/push_service.dart';

/// Tracks whether this device has already been asked about notifications.
///
/// Android shows the POST_NOTIFICATIONS dialog exactly once. Every later
/// request returns the previous answer with no UI at all, so the system prompt
/// is a single non-renewable resource: spend it at launch, before the user
/// knows what the app does, and a "no" is permanent and uninformed.
///
/// Persisted so the in-app explainer is not re-shown across restarts either —
/// nagging is how an app teaches people to dismiss it reflexively.
class NotificationPrimingNotifier extends Notifier<bool> {
  static const _key = 'nosus_notification_primed';

  @override
  bool build() {
    try {
      return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markPrimed() async {
    if (state) return;
    state = true;
    try {
      await ref.read(sharedPreferencesProvider).setBool(_key, true);
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> reset() async {
    state = false;
    try {
      await ref.read(sharedPreferencesProvider).remove(_key);
    } catch (_) {}
  }
}

final notificationPrimingProvider =
    NotifierProvider<NotificationPrimingNotifier, bool>(
      NotificationPrimingNotifier.new,
    );

/// Asks for the notification permission, in context, at most once.
///
/// Call this *after* the user does something whose follow-up they would want to
/// know about — joining a group, uploading a first document — not on first
/// launch. The explainer runs first so the system dialog is never the first
/// time the question is posed, and declining the explainer never spends the
/// OS-level prompt.
///
/// Returns true only if permission ended up granted.
Future<bool> maybePrimeNotifications(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  // Android is the only platform this ships to that has a runtime notification
  // permission and a configured push path.
  if (kIsWeb) return false;
  if (ref.read(notificationPrimingProvider)) return false;

  // If the transport is not configured there is nothing to grant, and burning
  // the one-shot system dialog for a capability that cannot deliver would be
  // straightforwardly user-hostile.
  if (!await PushService.instance.initialize()) {
    debugLog('NO SUS: Skipping notification priming — push not configured.');
    return false;
  }
  if (await PushService.instance.hasPermission()) {
    await ref.read(notificationPrimingProvider.notifier).markPrimed();
    return true;
  }

  if (!context.mounted) return false;

  AnalyticsService.instance.log(AnalyticsEvent.notificationPermissionPrompted);

  final wantsIt = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PrimingSheet(reason: reason),
  );

  // Mark primed either way. "Not now" is an answer, and re-asking on the next
  // group join would be exactly the nagging this is designed to avoid — the
  // switch in Settings is the way back in.
  await ref.read(notificationPrimingProvider.notifier).markPrimed();

  if (wantsIt != true) return false;

  final granted = await PushService.instance.requestPermissionAndRegister();
  AnalyticsService.instance.log(
    granted
        ? AnalyticsEvent.notificationPermissionGranted
        : AnalyticsEvent.notificationPermissionDenied,
  );
  return granted;
}

class _PrimingSheet extends StatelessWidget {
  final String reason;
  const _PrimingSheet({required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Container(
      padding: EdgeInsets.only(
        left: NoSusTheme.s24,
        right: NoSusTheme.s24,
        top: NoSusTheme.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + NoSusTheme.s32,
      ),
      decoration: BoxDecoration(
        color: isDark ? NoSusTheme.dCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: fg.withValues(alpha: 0.1), width: 0.75),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: NoSusTheme.s24),
            Icon(
              Icons.notifications_active_outlined,
              size: 32,
              color: fg.withValues(alpha: 0.85),
            ),
            const SizedBox(height: NoSusTheme.s16),
            Text(
              'Want to know when this happens?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: NoSusTheme.s8),
            Text(
              reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: subtle,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: NoSusTheme.s16),
            // The privacy answer belongs here, next to the ask — it is the
            // actual objection someone has to notifications from a security
            // product, and it is true: enqueue_notification composes the text
            // from templates that name no file and no group.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: subtle.withValues(alpha: 0.8),
                ),
                const SizedBox(width: NoSusTheme.s8),
                Expanded(
                  child: Text(
                    'Notifications never include a document name or its '
                    'contents, so nothing sensitive appears on your lock screen.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: subtle.withValues(alpha: 0.9),
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NoSusTheme.s24),
            FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: fg,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NoSusTheme.r12),
                ),
              ),
              child: const Text(
                'TURN ON NOTIFICATIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: NoSusTheme.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'NOT NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: subtle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
