import 'package:flutter/material.dart';
import '../../../monad/presentation/monad_entry_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../theme.dart';
import '../../../auth/presentation/providers/pending_intent_provider.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../help/domain/help_topic.dart';
import '../../../help/presentation/screens/help_screen.dart';
import '../../../help/presentation/screens/help_topic_screen.dart';
import '../../../share/presentation/screens/burn_file_creator_screen.dart';
import '../../../share/presentation/screens/burn_note_creator_screen.dart';
import '../../../share/presentation/screens/redeem_code_screen.dart';
import '../../../analytics/data/analytics_service.dart';
import '../providers/onboarding_providers.dart';

/// What a signed-out visitor sees instead of a login form.
///
/// The app used to render [AuthScreen] the instant `user == null`, so the first
/// thing anyone ever saw was an email field with no explanation of what they
/// were signing up for. Everything offered here is a real, working feature —
/// Burn Notes, Burn Files and code redemption are anonymous on both ends by
/// design (open INSERT policy on `burn_notes`, `verify_jwt: false` on the
/// burn-file and redeem Edge Functions), so this is genuine value before
/// signup rather than a screenshot tour.
///
/// Authentication is asked for at the point identity actually matters: joining
/// a group, or putting a document somewhere other people can read it.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // Top of the activation funnel. Everything downstream — signup_started,
    // onboarding_completed, first_document_uploaded — is measured against this.
    AnalyticsService.instance.log(AnalyticsEvent.welcomeViewed);
  }

  /// Opens one of the tools that genuinely needs no account.
  ///
  /// `tool` is a fixed identifier from this file, never user content — see
  /// AnalyticsService, which also drops anything that is not a primitive.
  void _openGuestTool(
    BuildContext context,
    WidgetRef ref, {
    required String tool,
    required Widget Function() builder,
  }) {
    ref.read(welcomeSeenProvider.notifier).markSeen();
    AnalyticsService.instance.log(
      AnalyticsEvent.guestToolOpened,
      properties: {'tool': tool},
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder()));
  }

  void _openAuth(BuildContext context, WidgetRef ref, {required bool signUp}) {
    HapticFeedback.lightImpact();
    ref.read(welcomeSeenProvider.notifier).markSeen();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthScreen(startOnSignUp: signUp)),
    );
  }

  /// Records what the user was reaching for before sending them to sign in, so
  /// they land back on it afterwards instead of on Home.
  void _authWall(
    BuildContext context,
    WidgetRef ref, {
    required PendingIntentKind intent,
  }) {
    ref.read(pendingIntentProvider.notifier).set(PendingIntent(intent));
    AnalyticsService.instance.log(
      AnalyticsEvent.authWallHit,
      properties: {'action': intent.name},
    );
    _openAuth(context, ref, signUp: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              physics: NoSusTheme.getScrollPhysics(context),
              padding: const EdgeInsets.fromLTRB(
                NoSusTheme.s24,
                NoSusTheme.s16,
                NoSusTheme.s24,
                NoSusTheme.s32,
              ),
              children: [
                // ── Header ───────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NO SUS',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SILENT SECURITY WORKSPACE',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 10,
                              color: subtle,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Switch theme',
                      onPressed: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                      icon: Icon(
                        isDark
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_round_outlined,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Help',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                      icon: const Icon(Icons.help_outline, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: NoSusTheme.s32),

                // ── Value proposition ────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Share study material\nwithout losing track of it.',
                        style: theme.textTheme.displayMedium?.copyWith(
                          height: 1.25,
                        ),
                      ),
                    ),
                    const MascotView(character: MascotCharacter.lux, size: 40),
                  ],
                ),
                const SizedBox(height: NoSusTheme.s12),
                Text(
                  'Documents open in a watermarked reader, every open is logged for the whole '
                  'group to see, and anything you send outside the group can be set to '
                  'self-destruct.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtle,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s32),

                const MonadEntryCard(),
                // ── Usable right now, no account ─────────────────────────────
                _SectionLabel(
                  text: 'TRY IT NOW — NO ACCOUNT NEEDED',
                  color: subtle,
                ),
                const SizedBox(height: NoSusTheme.s12),
                _ActionCard(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Send a Burn Note',
                      body:
                          'A secret that deletes itself the moment it is read.',
                      onTap: () => _openGuestTool(
                        context,
                        ref,
                        tool: 'burn_note',
                        builder: BurnNoteCreatorScreen.new,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.04, end: 0),
                const SizedBox(height: NoSusTheme.s12),
                _ActionCard(
                  icon: Icons.upload_file_outlined,
                  title: 'Send a Burn File',
                  body: 'Encrypted on your device. Deleted after one download.',
                  onTap: () => _openGuestTool(
                    context,
                    ref,
                    tool: 'burn_file',
                    builder: BurnFileCreatorScreen.new,
                  ),
                ).animate().fadeIn(duration: 340.ms).slideY(begin: 0.04, end: 0),
                const SizedBox(height: NoSusTheme.s12),
                _ActionCard(
                      icon: Icons.key_outlined,
                      title: 'Redeem a code',
                      body: 'Someone sent you a short code instead of a link.',
                      onTap: () => _openGuestTool(
                        context,
                        ref,
                        tool: 'redeem_code',
                        builder: RedeemCodeScreen.new,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 380.ms)
                    .slideY(begin: 0.04, end: 0),

                const SizedBox(height: NoSusTheme.s32),

                // ── What an account adds ─────────────────────────────────────
                _SectionLabel(text: 'WITH A FREE ACCOUNT', color: subtle),
                const SizedBox(height: NoSusTheme.s12),
                Container(
                  padding: const EdgeInsets.all(NoSusTheme.s24),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Benefit(
                        icon: Icons.group_outlined,
                        title: 'Study groups',
                        body:
                            'A private space with its own members, files and activity log.',
                        onTap: () => _authWall(
                          context,
                          ref,
                          intent: PendingIntentKind.browseGroups,
                        ),
                      ),
                      const SizedBox(height: NoSusTheme.s16),
                      _Benefit(
                        icon: Icons.description_outlined,
                        title: 'Secure documents',
                        body:
                            'Shared files open in a watermarked reader instead of downloading.',
                        onTap: () => _authWall(
                          context,
                          ref,
                          intent: PendingIntentKind.shareDocument,
                        ),
                      ),
                      const SizedBox(height: NoSusTheme.s16),
                      _Benefit(
                        icon: Icons.history_edu_outlined,
                        title: 'Activity log',
                        body:
                            'Who opened what, and when — visible to every member, including you.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpTopicScreen(
                              topicId: HelpCatalog.auditLog,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 420.ms),

                const SizedBox(height: NoSusTheme.s24),

                // ── Primary actions ──────────────────────────────────────────
                Semantics(
                  button: true,
                  label: 'Create a free account',
                  child: GestureDetector(
                    onTap: () => _openAuth(context, ref, signUp: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: fg,
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      ),
                      child: Center(
                        child: Text(
                          'CREATE A FREE ACCOUNT',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NoSusTheme.s12),
                TextButton(
                  onPressed: () => _openAuth(context, ref, signUp: false),
                  child: Text(
                    'I ALREADY HAVE AN ACCOUNT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: subtle,
                    ),
                  ),
                ),
                const SizedBox(height: NoSusTheme.s8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HelpTopicScreen(
                          topicId: HelpCatalog.whatIsNoSus,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.help_outline, size: 14, color: subtle),
                    label: Text(
                      'What is NO SUS?',
                      style: TextStyle(fontSize: 12, color: subtle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 10,
        letterSpacing: 1.5,
        color: color.withValues(alpha: 0.7),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label: '$title. $body',
      child: InkWell(
        borderRadius: BorderRadius.circular(NoSusTheme.r16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: NoSusTheme.cardDecoration(context),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NoSusTheme.r12),
                    border: Border.all(color: fg.withValues(alpha: 0.2)),
                    color: fg.withValues(alpha: 0.03),
                  ),
                  child: Icon(icon, color: fg.withValues(alpha: 0.8), size: 22),
                ),
                const SizedBox(width: NoSusTheme.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withValues(alpha: 0.54),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: fg.withValues(alpha: 0.45),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _Benefit({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label: '$title. $body',
      child: InkWell(
        borderRadius: BorderRadius.circular(NoSusTheme.r12),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: fg.withValues(alpha: 0.75)),
              const SizedBox(width: NoSusTheme.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
