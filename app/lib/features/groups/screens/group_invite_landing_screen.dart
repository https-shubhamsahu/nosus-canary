import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../analytics/data/analytics_service.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/providers/pending_intent_provider.dart';
import '../../auth/presentation/screens/auth_screen.dart';
import '../../config/presentation/providers/config_provider.dart';
import '../../notifications/presentation/widgets/notification_permission_prompt.dart';
import '../../../core/mascot/mascot_controller.dart';
import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';
import '../providers/groups_provider.dart';

class GroupInviteLandingScreen extends ConsumerStatefulWidget {
  final String inviteCode;

  const GroupInviteLandingScreen({
    super.key,
    required this.inviteCode,
  });

  @override
  ConsumerState<GroupInviteLandingScreen> createState() => _GroupInviteLandingScreenState();
}

class _GroupInviteLandingScreenState extends ConsumerState<GroupInviteLandingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _inviteDetails;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _fetchInviteDetails();
  }

  Future<void> _fetchInviteDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'get_invite_details',
        params: {'p_invite_code': widget.inviteCode},
      );

      final data = response as Map<String, dynamic>;
      if (data['valid'] == false) {
        setState(() {
          _errorMessage = data['reason'] as String? ?? 'Invalid invite link';
          _isLoading = false;
        });
        ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
      } else {
        setState(() {
          _inviteDetails = data;
          _isLoading = false;
        });
        ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load group invitation details.';
        _isLoading = false;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
    }
  }

  Future<void> _downloadApp() async {
    final downloadUrl = ref.read(remoteConfigValueProvider(SecureSendConfigs.appDownloadUrl)) as String;
    final uri = Uri.parse(downloadUrl);
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

  Future<void> _joinGroup() async {
    final auth = ref.read(authStateProvider).value;
    if (auth == null) {
      // Joining a private group is one of the places identity is genuinely
      // required, so this wall stays. What matters is that the intent survives
      // it: the invite code is parked (durably, through an email-confirmation
      // or OAuth round trip) and replayed once there is a session, so the user
      // lands back on this join flow rather than on Home.
      if (mounted) {
        AnalyticsService.instance.log(
          AnalyticsEvent.authWallHit,
          properties: {'action': 'join_group'},
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Create an account to join this group — we will bring you '
              'straight back here.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(pendingIntentProvider.notifier).set(
              PendingIntent(
                PendingIntentKind.joinGroup,
                payload: widget.inviteCode,
              ),
            );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AuthScreen(
              pendingInviteCode: widget.inviteCode,
              startOnSignUp: true,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final client = Supabase.instance.client;
      await client.rpc(
        'join_group_by_invite_link',
        params: {'p_invite_code': widget.inviteCode},
      );

      // Invalidate groups lists so they refresh immediately
      ref.invalidate(groupsProvider);
      AnalyticsService.instance.log(AnalyticsEvent.groupJoinCompleted);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the group! Welcome aboard.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Ask about notifications here, and only here-ish: the user has just
        // joined a group, so "activity in your groups" is a concrete thing they
        // now have rather than an abstraction. Awaited before popping so the
        // sheet is not raced by the navigation. It self-limits to once per
        // device and never spends the one-shot system dialog on a decline.
        await maybePrimeNotifications(
          context,
          ref,
          reason: 'You just joined a group. Want to know when people share '
              'documents in it, or when your access changes?',
        );

        if (!mounted) return;
        // Go back to the main app dashboard/workspace
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final primaryColor = isDark ? Colors.orangeAccent : const Color(0xFF0072FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NO SUS INVITATION'),
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: isDark ? const Color(0xFF141414) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _isLoading
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.orangeAccent),
                            SizedBox(height: 16),
                            Text('Fetching secure invite details...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        )
                      : _errorMessage != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MascotView(
                                  character: MascotCharacter.nox,
                                  size: 64,
                                  fallback: Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'INVITATION FAILED',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      } else {
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                      foregroundColor: fg,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('BACK TO APP'),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Center(
                                  child: MascotView(
                                    character: MascotCharacter.duo,
                                    size: 72,
                                    fallback: Icon(Icons.group_add_outlined, size: 72, color: Colors.orangeAccent),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'YOU HAVE BEEN INVITED TO JOIN',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    color: fg.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _inviteDetails?['group_name'] ?? 'Study Group',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_alt_outlined, size: 14, color: primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_inviteDetails?['member_count'] ?? 0} active members',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: fg.withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if ((_inviteDetails?['group_description'] as String? ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1C1C1C) : Colors.black.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: fg.withValues(alpha: 0.08)),
                                    ),
                                    child: Text(
                                      _inviteDetails!['group_description'],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: fg.withValues(alpha: 0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'Shared by: ${_inviteDetails?['creator_name'] ?? 'Admin'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: fg.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Display Landing Page details if on mobile web browser
                                if (kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) ...[
                                  Text(
                                    'SECURITY & PRIVACY BENEFITS',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: fg.withValues(alpha: 0.4),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  const _BenefitRow(icon: Icons.security_rounded, title: 'Secure Vault', subtitle: 'Volatile RAM caching prevents local leaks'),
                                  const _BenefitRow(icon: Icons.phonelink_lock, title: 'Anti-Screenshot', subtitle: 'Blocks system capture and screen recordings'),
                                  const _BenefitRow(icon: Icons.branding_watermark_outlined, title: 'Dynamic Watermarks', subtitle: 'Overlays trace leaks back to source'),
                                  const SizedBox(height: 32),
                                  FilledButton.icon(
                                    onPressed: _downloadApp,
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: const Text('DOWNLOAD NO SUS APP', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.orangeAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _joinGroup,
                                    icon: const Icon(Icons.web_rounded, size: 16),
                                    label: const Text('JOIN VIA WEB BROWSER', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ] else ...[
                                  FilledButton.icon(
                                    onPressed: _isJoining ? null : _joinGroup,
                                    icon: _isJoining
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                          )
                                        : const Icon(Icons.check_circle_outline, size: 16),
                                    label: Text(
                                      _isJoining ? 'JOINING...' : 'ACCEPT & JOIN GROUP',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.orangeAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
