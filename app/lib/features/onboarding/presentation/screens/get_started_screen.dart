import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../services/supabase_service.dart';
import '../../../../theme.dart';
import '../../../analytics/data/analytics_service.dart';
import '../../../groups/presentation/providers/group_dependencies.dart';
import '../../../help/domain/help_topic.dart';
import '../../../help/presentation/screens/help_topic_screen.dart';
import '../../../profile/providers/profile_provider.dart';
import '../providers/onboarding_providers.dart';

/// First-run setup, post-signup. One screen, both fields optional.
///
/// This replaces a six-act narrative slideshow ("ACT 1: THE INCIDENT" …
/// "ACT 6: COMMUNITY") that ran *after* the user had already signed up — so it
/// was neither a pitch (they were sold) nor setup (five of six acts collected
/// nothing). Its only Skip control lived on act 1 and jumped to act 4, so
/// there was no way out of acts 2–6 at all.
///
/// The product explanation now lives pre-auth on the welcome surface and in
/// Help; what is left here is the two things the app genuinely cannot guess.
class GetStartedScreen extends ConsumerStatefulWidget {
  const GetStartedScreen({super.key});

  @override
  ConsumerState<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends ConsumerState<GetStartedScreen> {
  final _nameController = TextEditingController();
  bool _isFinishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = _defaultDisplayName();
    AnalyticsService.instance.log(AnalyticsEvent.onboardingStarted);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultDisplayName() {
    if (!SupabaseService.instance.isReachable) return '';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return '';
  }

  Future<void> _finish({required bool skipped}) async {
    if (_isFinishing) return;
    setState(() {
      _isFinishing = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    final wantsTsec = !skipped && ref.read(tsecCommunityProvider);

    try {
      final user = SupabaseService.instance.isReachable
          ? Supabase.instance.client.auth.currentUser
          : null;

      if (user != null) {
        final cache = await SupabaseService.instance.fetchProfile(user.id);
        var name = skipped ? '' : _nameController.text.trim();
        if (name.isEmpty) {
          name = (cache['display_name'] as String? ?? '').trim();
        }
        if (name.isEmpty) name = _defaultDisplayName();
        if (name.isEmpty) name = 'Enclave Member';

        await SupabaseService.instance.saveProfile(
          userId: user.id,
          email: user.email ?? '',
          displayName: name,
          // Preserve whatever avatar the account already has. These two columns
          // carry the avatar selection as JSON, so defaulting them on every
          // save would silently reset a returning user's avatar.
          avatarColorStart:
              cache['avatar_color_start'] as String? ?? 'FF0072FF',
          avatarColorEnd: cache['avatar_color_end'] as String? ?? 'FF00F2FE',
        );

        final repo = ref.read(studyGroupRepositoryProvider);
        // Global Community is joined by the handle_new_user() signup trigger.
        // Repeating it here is a cheap idempotent safety net for accounts whose
        // trigger run failed — without it those users land on an empty Groups
        // tab with no explanation.
        await repo.joinGroupByName('Global Community', user.id);

        if (wantsTsec) {
          await repo.ensureCommunityExists(
            'TSEC, Kandivali',
            'TSEC Kandivali Students Community',
            true,
          );
          await repo.joinGroupByName('TSEC, Kandivali', user.id);
        }

        ref.invalidate(profileProvider);
      }
    } catch (e) {
      // Setup is not load-bearing: the account already exists and every field
      // here is editable later. Blocking entry on a flaky network would be a
      // worse failure than starting with a default name, so surface it and
      // continue.
      debugLog('NO SUS: first-run setup could not be saved: $e');
      _error =
          'We could not save that right now — you can set it later in Settings.';
    }

    await ref.read(onboardingCompletedProvider.notifier).complete();
    AnalyticsService.instance.log(
      skipped
          ? AnalyticsEvent.onboardingSkipped
          : AnalyticsEvent.onboardingCompleted,
    );

    if (!mounted) return;
    if (_error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!), behavior: SnackBarBehavior.floating),
      );
    }
    // No pop: AuthGate watches onboardingCompletedProvider and swaps this
    // screen for the app shell.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.6);
    final wantsTsec = ref.watch(tsecCommunityProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              physics: NoSusTheme.getScrollPhysics(context),
              padding: const EdgeInsets.all(NoSusTheme.s24),
              children: [
                const SizedBox(height: NoSusTheme.s16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "You're in.",
                        style: theme.textTheme.displayMedium,
                      ),
                    ),
                    const MascotView(character: MascotCharacter.lux, size: 36),
                  ],
                ),
                const SizedBox(height: NoSusTheme.s8),
                Text(
                  'Two optional things, then the app. You can change both later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtle,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s32),

                // ── Display name ─────────────────────────────────────────────
                Text(
                  'WHAT SHOULD PEOPLE CALL YOU?',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: subtle,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s8),
                TextField(
                  controller: _nameController,
                  enabled: !_isFinishing,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _finish(skipped: false),
                  style: TextStyle(fontSize: 15, color: fg),
                  cursorColor: fg,
                  decoration: InputDecoration(
                    hintText: 'Display name',
                    hintStyle: TextStyle(fontSize: 15, color: subtle),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      borderSide: BorderSide(color: fg),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Shown to other members of your groups, and in the activity log.',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtle,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const WhatsThisButton(
                      topicId: HelpCatalog.account,
                      semanticLabel: 'What is stored about me?',
                    ),
                  ],
                ),
                const SizedBox(height: NoSusTheme.s32),

                // ── Community opt-in ─────────────────────────────────────────
                Text(
                  'ARE YOU AT TSEC, KANDIVALI?',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: subtle,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s8),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceTile(
                        icon: Icons.school_outlined,
                        label: 'YES',
                        selected: wantsTsec,
                        onTap: _isFinishing
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(tsecCommunityProvider.notifier)
                                    .set(true);
                              },
                      ),
                    ),
                    const SizedBox(width: NoSusTheme.s12),
                    Expanded(
                      child: _ChoiceTile(
                        icon: Icons.public_outlined,
                        label: 'NO',
                        selected: !wantsTsec,
                        onTap: _isFinishing
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(tsecCommunityProvider.notifier)
                                    .set(false);
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  wantsTsec
                      ? "You'll join the TSEC, Kandivali community as well as Global Community."
                      : "You'll start in Global Community. Treat it as public — anyone with an "
                            'account can read what you put there.',
                  style: TextStyle(fontSize: 11, color: subtle, height: 1.5),
                ),

                const SizedBox(height: NoSusTheme.s32),

                // ── Actions ──────────────────────────────────────────────────
                Semantics(
                  button: true,
                  enabled: !_isFinishing,
                  label: 'Start using NO SUS',
                  child: GestureDetector(
                    onTap: _isFinishing ? null : () => _finish(skipped: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: fg,
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      ),
                      child: Center(
                        child: _isFinishing
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              )
                            : Text(
                                'START USING NO SUS',
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
                const SizedBox(height: NoSusTheme.s8),
                Center(
                  child: TextButton(
                    onPressed: _isFinishing
                        ? null
                        : () => _finish(skipped: true),
                    child: Text(
                      'SKIP FOR NOW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: subtle,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 260.ms),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final onSelected = isDark ? Colors.black : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? fg : Colors.transparent,
            border: Border.all(
              color: selected ? fg : fg.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(NoSusTheme.r12),
          ),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Icon(icon, size: 20, color: selected ? onSelected : fg),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? onSelected : fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
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
