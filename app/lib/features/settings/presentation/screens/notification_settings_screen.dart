import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme.dart';
import '../../../help/domain/help_topic.dart';
import '../../../help/presentation/screens/help_topic_screen.dart';
import '../../../notifications/data/push_service.dart';
import '../../../notifications/domain/app_notification.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../widgets/settings_section.dart';

/// Per-category notification switches, plus an honest account of what the OS
/// and the backend are currently doing.
///
/// The system-permission state is surfaced rather than hidden: a user whose
/// switches are all on but whose Android permission is denied would otherwise
/// see a screen that claims notifications are configured while nothing ever
/// arrives, and no way to work out why.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool? _systemAllowed;
  bool _transportConfigured = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissionState();
  }

  Future<void> _refreshPermissionState() async {
    final configured = await PushService.instance.initialize();
    final allowed = configured && await PushService.instance.hasPermission();
    if (!mounted) return;
    setState(() {
      _transportConfigured = configured;
      _systemAllowed = allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'NOTIFICATIONS',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
        actions: const [
          WhatsThisButton(
            topicId: HelpCatalog.notifications,
            semanticLabel: 'What will I be notified about?',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              physics: NoSusTheme.getScrollPhysics(context),
              padding: const EdgeInsets.symmetric(
                horizontal: NoSusTheme.s24,
                vertical: NoSusTheme.s8,
              ),
              children: [
                _deliveryStatus(theme),
                SettingsSection(
                  title: 'IN-APP & PUSH',
                  children: [
                    for (final category in NotificationCategory.values)
                      SettingsSwitchRow(
                        title: category.label,
                        subtitle: category.description,
                        value: prefsAsync.value?.isEnabled(category) ?? true,
                        onChanged: (v) => _setCategory(category, v),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: NoSusTheme.s16,
                    left: NoSusTheme.s4,
                  ),
                  child: Text(
                    'These switches control the in-app inbox as well as push, so '
                    'turning a category off stops it reaching you either way.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11.5,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: NoSusTheme.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setCategory(NotificationCategory category, bool value) async {
    // Security alerts are the category someone would still want after muting
    // everything else, so switching them off is a decision worth confirming —
    // but it is still the user's decision to make.
    if (category.isCritical && !value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'Turn off security alerts?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You will not be told when access is revoked, when a document is '
            'opened from an unrecognised device, or when an integrity check '
            'fails. Everything is still recorded in the audit log.',
            style: TextStyle(fontSize: 12.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('KEEP ON', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'TURN OFF',
                style: TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setCategory(category, value);
    } catch (_) {
      // The notifier reverts its own state; this only reports it, because a
      // switch snapping back with no explanation is its own small mystery.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that. Check your connection.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Explains the actual delivery state instead of implying push works.
  Widget _deliveryStatus(ThemeData theme) {
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.6);

    final (IconData icon, String title, String body) = switch ((
      _transportConfigured,
      _systemAllowed,
    )) {
      // The state this build actually ships in: no Firebase project, so there
      // is no push transport. Saying so beats a screen that quietly implies
      // notifications will arrive.
      (false, _) => (
        Icons.inbox_outlined,
        'Delivered in the app',
        'Push delivery is not set up on this build, so these arrive in your '
            'in-app notifications rather than as system notifications. '
            'Everything below still applies.',
      ),
      (true, false) => (
        Icons.notifications_off_outlined,
        'Blocked by your device',
        'Android is not allowing notifications from NO SUS. Turn them on in '
            'system settings, and your choices below take effect again.',
      ),
      (true, _) => (
        Icons.notifications_active_outlined,
        'Push notifications are on',
        'Notification text never includes a document name or its contents.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: NoSusTheme.s16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(NoSusTheme.r16),
          border: Border.all(color: fg.withValues(alpha: 0.1), width: 0.75),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg.withValues(alpha: 0.8)),
            const SizedBox(width: NoSusTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: subtle,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  if (_transportConfigured &&
                      _systemAllowed == false &&
                      !kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: NoSusTheme.s8),
                      child: TextButton(
                        onPressed: () async {
                          // Android only shows its permission dialog once, so
                          // after a denial the only route back is the system
                          // settings app. requestPermissionAndRegister() opens
                          // it where the platform allows and is a no-op
                          // otherwise; re-check either way.
                          await PushService.instance
                              .requestPermissionAndRegister();
                          await _refreshPermissionState();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 40),
                          alignment: Alignment.centerLeft,
                        ),
                        child: const Text(
                          'TRY AGAIN',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
