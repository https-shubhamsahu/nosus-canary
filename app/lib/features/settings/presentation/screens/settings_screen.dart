import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../services/supabase_service.dart';
import '../../../../theme.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../config/domain/app_update.dart';
import '../../../config/presentation/providers/app_update_provider.dart';
import '../../../config/presentation/providers/config_provider.dart';
import '../../../help/presentation/screens/help_screen.dart';
import '../../../notifications/data/push_service.dart';
import '../../../notifications/domain/app_notification.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../onboarding/presentation/providers/tour_providers.dart';
import '../../../profile/presentation/screens/advanced_settings_screen.dart';
import '../../../profile/providers/settings_provider.dart';
import '../widgets/settings_section.dart';
import 'notification_settings_screen.dart';

/// Settings, organised by what a person is trying to change.
///
/// Split out of `profile_screen.dart`, which had grown to ~2,100 lines holding
/// identity, storage, privacy toggles, admin entry, help, legal text, invented
/// metrics and account deletion in one scroll. Two different jobs — "who am I
/// here" and "how does this app behave" — sharing one screen meant neither had
/// a findable shape.
///
/// Every row here reaches something real. No section exists to look complete.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SETTINGS',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
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
                _account(context, ref, user?.email),
                _notifications(context, ref),
                _privacy(context, ref),
                _appearance(context, ref),
                _tips(context, ref),
                _adminSection(context, ref),
                _helpAndSupport(context, ref),
                _about(context, ref),
                _dangerZone(context, ref, user?.email ?? ''),
                const SizedBox(height: NoSusTheme.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Account ───────────────────────────────────────────────────────────────
  Widget _account(BuildContext context, WidgetRef ref, String? email) {
    return SettingsSection(
      title: 'ACCOUNT',
      children: [
        SettingsRow(
          icon: Icons.alternate_email,
          title: 'Email',
          subtitle: email ?? '—',
        ),
        SettingsRow(
          icon: Icons.lock_outline,
          title: 'Change password',
          subtitle: 'Set a new password for this account',
          onTap: () => _changePassword(context, ref),
        ),
      ],
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Widget _notifications(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final enabledCount = prefs.value?.enabled.values.where((v) => v).length;

    return SettingsSection(
      title: 'NOTIFICATIONS',
      children: [
        SettingsRow(
          icon: Icons.notifications_outlined,
          title: 'Notification categories',
          subtitle: enabledCount == null
              ? 'Choose what you hear about'
              : '$enabledCount of ${NotificationCategory.values.length} turned on',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Privacy & Security ────────────────────────────────────────────────────
  Widget _privacy(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'PRIVACY & SECURITY',
      children: [
        SettingsSwitchRow(
          title: 'Touch to reveal',
          subtitle: 'Keep documents blurred until you hold the screen',
          value: ref.watch(touchToRevealProvider),
          onChanged: (v) =>
              ref.read(touchToRevealProvider.notifier).setEnabled(v),
        ),
        SettingsSwitchRow(
          title: 'Watermark overlay',
          subtitle: 'Draw your identity across documents you open',
          value: ref.watch(watermarkVisibilityProvider),
          onChanged: (v) =>
              ref.read(watermarkVisibilityProvider.notifier).setEnabled(v),
        ),
      ],
    );
  }

  // ── Appearance ────────────────────────────────────────────────────────────
  Widget _appearance(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SettingsSection(
      title: 'APPEARANCE',
      children: [
        SettingsSwitchRow(
          title: 'Dark theme',
          subtitle: 'Also available from the toggle in the app header',
          value: mode == ThemeMode.dark,
          onChanged: (v) => ref
              .read(themeModeProvider.notifier)
              .setMode(v ? ThemeMode.dark : ThemeMode.light),
        ),
      ],
    );
  }

  // ── Tips ──────────────────────────────────────────────────────────────────
  Widget _tips(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'TIPS & TUTORIALS',
      children: [
        SettingsSwitchRow(
          title: 'Show contextual tips',
          subtitle: 'Short explanations the first time you open a screen',
          value: ref.watch(tipsEnabledProvider),
          onChanged: (v) =>
              ref.read(tipsEnabledProvider.notifier).setEnabled(v),
        ),
        SettingsRow(
          icon: Icons.replay_outlined,
          title: 'Replay all tips',
          subtitle: 'Show every tip again from the start',
          onTap: () async {
            HapticFeedback.lightImpact();
            await ref.read(tourProgressProvider.notifier).resetAll();
            await ref.read(tipsEnabledProvider.notifier).setEnabled(true);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tips reset. They will appear again as you move around the app.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        SettingsRow(
          icon: Icons.restart_alt,
          title: 'Replay first-run setup',
          subtitle: 'Go through name and community setup again',
          onTap: () async {
            HapticFeedback.lightImpact();
            await ref.read(onboardingCompletedProvider.notifier).reset();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Setup will run next time you open the app.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Administration (only for accounts that actually have the role) ────────
  Widget _adminSection(BuildContext context, WidgetRef ref) {
    return ref
        .watch(userRoleProvider)
        .maybeWhen(
          data: (role) {
            if (role != 'admin' && role != 'super_admin') {
              return const SizedBox.shrink();
            }
            return SettingsSection(
              title: 'ADMINISTRATION',
              children: [
                SettingsRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Super admin console',
                  subtitle: 'Feature flags, user roles and remote config',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  ),
                ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }

  // ── Help ──────────────────────────────────────────────────────────────────
  Widget _helpAndSupport(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'HELP & SUPPORT',
      children: [
        SettingsRow(
          icon: Icons.help_outline,
          title: 'Help centre',
          subtitle: 'How groups, documents and burn links work',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
        SettingsRow(
          icon: Icons.rate_review_outlined,
          title: 'Send feedback',
          subtitle: 'Report a bug or suggest something',
          onTap: () => _sendFeedback(context, ref),
        ),
        SettingsRow(
          icon: Icons.speed_outlined,
          title: 'Network diagnostics',
          subtitle: 'Check connectivity to the NO SUS backend',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
          ),
        ),
      ],
    );
  }

  // ── About & legal ─────────────────────────────────────────────────────────
  Widget _about(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider).value;
    return SettingsSection(
      title: 'ABOUT & LEGAL',
      children: [
        SettingsRow(
          icon: Icons.info_outline,
          title: 'About NO SUS',
          subtitle: update is AppUpdateAvailable
              ? 'Update available: v${update.latestVersion}'
              : 'Version and build information',
          onTap: () => _showAbout(context, ref),
        ),
        SettingsRow(
          icon: Icons.gavel_outlined,
          title: 'Terms of service',
          onTap: () => _showLegal(context, 'TERMS OF SERVICE', _termsBody),
        ),
        SettingsRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          onTap: () => _showLegal(context, 'PRIVACY POLICY', _privacyBody),
        ),
      ],
    );
  }

  // ── Danger zone ───────────────────────────────────────────────────────────
  Widget _dangerZone(BuildContext context, WidgetRef ref, String email) {
    return SettingsSection(
      title: 'DANGER ZONE',
      isDanger: true,
      children: [
        SettingsRow(
          icon: Icons.logout,
          title: 'Sign out',
          isDanger: true,
          onTap: () => _confirmSignOut(context, ref),
        ),
        SettingsRow(
          icon: Icons.delete_forever_outlined,
          title: 'Delete account',
          subtitle: 'Permanently removes your profile and memberships',
          isDanger: true,
          onTap: () => _confirmDelete(context, ref, email),
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _changePassword(BuildContext context, WidgetRef ref) {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSaving = false;
    bool obscure = true;
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            final pw = newCtrl.text;
            if (pw.length < 6) {
              setDialogState(
                () => errorText = 'Must be at least 6 characters.',
              );
              return;
            }
            if (pw != confirmCtrl.text) {
              setDialogState(() => errorText = 'Passwords do not match.');
              return;
            }
            setDialogState(() {
              isSaving = true;
              errorText = null;
            });
            try {
              await ref.read(authRepositoryProvider).updatePassword(pw);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              setDialogState(() {
                isSaving = false;
                errorText = e
                    .toString()
                    .replaceAll('AuthApiException: ', '')
                    .replaceAll('AuthException: ', '')
                    .replaceAll('Exception: ', '');
              });
            }
          }

          return AlertDialog(
            title: const Text(
              'Change password',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: NoSusTheme.s8),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscure,
                  onSubmitted: (_) => save(),
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    errorText: errorText,
                    errorMaxLines: 3,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('CANCEL', style: TextStyle(fontSize: 11)),
              ),
              FilledButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('UPDATE', style: TextStyle(fontSize: 11)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _sendFeedback(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool isSending = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: NoSusTheme.s24,
            right: NoSusTheme.s24,
            top: NoSusTheme.s24,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + NoSusTheme.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SEND FEEDBACK',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                  fontSize: 11,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: NoSusTheme.s24),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'What happened, or what would you change?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: NoSusTheme.s16),
              FilledButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        setSheetState(() => isSending = true);
                        try {
                          String? version;
                          try {
                            version =
                                (await PackageInfo.fromPlatform()).version;
                          } catch (_) {}
                          await Supabase.instance.client
                              .from('feedback')
                              .insert({
                                'user_id': Supabase
                                    .instance
                                    .client
                                    .auth
                                    .currentUser
                                    ?.id,
                                'message': text,
                                'app_version': version,
                              });
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thanks — feedback sent.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (_) {
                          setSheetState(() => isSending = false);
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not send. Check your connection and try again.',
                                ),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: Text(
                  isSending ? 'SENDING…' : 'SUBMIT',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAbout(BuildContext context, WidgetRef ref) async {
    // Real build metadata, never a hardcoded string that drifts from pubspec.
    String versionLabel = 'Version unavailable';
    try {
      final info = await PackageInfo.fromPlatform();
      versionLabel = 'Version ${info.version} (build ${info.buildNumber})';
    } catch (_) {}
    final update = ref.read(appUpdateProvider).value;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'About NO SUS',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(versionLabel, style: const TextStyle(fontSize: 12)),
            if (update is AppUpdateAvailable) ...[
              const SizedBox(height: NoSusTheme.s8),
              Text(
                'Update available: v${update.latestVersion}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: NoSusTheme.s16),
            const Text(
              'A secure study-group workspace: shared documents that stay '
              'watermarked and logged, plus burn links that need no account.',
              style: TextStyle(fontSize: 11.5, height: 1.5),
            ),
          ],
        ),
        actions: [
          if (update is AppUpdateAvailable)
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(update.downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('GET UPDATE', style: TextStyle(fontSize: 11)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showLegal(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SingleChildScrollView(
            child: Text(
              body,
              style: const TextStyle(fontSize: 11.5, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Sign out?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You will need to sign in again to reach your groups and documents.',
          style: TextStyle(fontSize: 12.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              HapticFeedback.mediumImpact();
              // Release the push token while the session still exists —
              // unregister_device_token is scoped by auth.uid(), so after
              // signOut() it would match nothing and this handset would keep
              // receiving the previous account's notifications.
              await PushService.instance.releaseCurrentDevice();
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text(
              'SIGN OUT',
              style: TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String email) {
    final confirmCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final matches = confirmCtrl.text.trim() == email.trim();
          return AlertDialog(
            title: const Text(
              'Delete account?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is permanent. Your profile, group memberships and '
                  'private notes are removed immediately.',
                  style: TextStyle(fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: NoSusTheme.s12),
                // Stated up front rather than discovered afterwards. Both are
                // deliberate: other members may depend on files you uploaded,
                // and an audit log the subject can erase is not an audit log.
                const Text(
                  'Files you uploaded stay with their groups, and audit log '
                  'entries are kept. Delete your uploads first if you want '
                  'them gone.',
                  style: TextStyle(fontSize: 11.5, height: 1.5),
                ),
                const SizedBox(height: NoSusTheme.s16),
                Text(
                  'Type $email to confirm:',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s8),
                TextField(
                  controller: confirmCtrl,
                  autocorrect: false,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(hintText: 'Your email'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCEL', style: TextStyle(fontSize: 11)),
              ),
              TextButton(
                onPressed: !matches
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        HapticFeedback.heavyImpact();
                        try {
                          await PushService.instance.releaseCurrentDevice();
                          if (SupabaseService.instance.isReachable) {
                            await Supabase.instance.client.functions.invoke(
                              'account-manager',
                            );
                          }
                          await ref.read(authRepositoryProvider).signOut();
                          await ref
                              .read(onboardingCompletedProvider.notifier)
                              .reset();
                          ref.invalidate(authStateProvider);
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not delete account: $e'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: Text(
                  'DELETE PERMANENTLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: matches ? Colors.redAccent : Colors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Kept verbatim from the previous Profile screen so this refactor does not
// quietly reword the legal text users have already been shown.
const String _termsBody =
    'Welcome to NO SUS.\n\n'
    '1. Acceptable Use\n'
    'You agree to use this secure enclave application solely for academic, private study collaborations. Any dissemination of unauthorized content or security audits bypasses is strictly forbidden.\n\n'
    '2. RLS & Access Protocols\n'
    'All operations are logged to a public audit ledger to ensure integrity. You are fully responsible for all documents uploaded under your credentials.\n\n'
    '3. Limitation of Liability\n'
    'NO SUS is provided "as is". We are not responsible for any transient network failures, client disconnects, or device-level screen recordings.';

const String _privacyBody =
    'Last updated: July 2026\n\n'
    '1. Data Collection\n'
    'We store your email, display name, and avatar selection inside secure Supabase database tables. Documents are streamed directly into volatile device memory and never cached permanently on disk.\n\n'
    '2. Audit Logs\n'
    'To detect potential leaks, we record events such as file openings and screenshots. These records containing user email and timestamps are immutable and visible to all group members.\n\n'
    '3. Product Analytics\n'
    'We record a small set of product events — app opened, first-run setup started/completed, sign-up completed, first document uploaded or viewed, and notification permission outcomes — against your account so we can see where the app is confusing. These records never contain document names, document contents, group names, or message text.\n\n'
    '4. Notifications\n'
    'If you enable push notifications we store a device token so messages can be delivered. Notification text never includes a document name or its contents. Signing out releases that device token.\n\n'
    '5. Data Deletion\n'
    'You may delete your account at any time. Account deletion removes your profile, memberships, private notes and analytics records. Files you uploaded to a group remain with that group, and audit log entries are retained for integrity.';
