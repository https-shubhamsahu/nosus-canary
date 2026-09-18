import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:no_sus/main.dart' show activeTabProvider;
import '../../../components/coach_mark.dart';
import '../../analytics/data/analytics_service.dart';
import '../../notifications/presentation/widgets/notification_permission_prompt.dart';
import '../../onboarding/presentation/providers/tour_providers.dart';
import '../providers/groups_provider.dart';
import '../domain/models/study_group.dart';
import '../widgets/group_card.dart';
import '../widgets/empty_states.dart';
import 'group_detail_screen.dart';
import 'join_group_page.dart';
import '../../../theme.dart';
import '../../../components/shimmer_box.dart';
import '../../../components/async_state_view.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// Main groups list screen — search, filtered list, FAB, skeleton loading.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _tabIndex = 4;

  final _searchController = TextEditingController();
  final _joinKey = GlobalKey();
  final _createKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (ref.read(activeTabProvider) == _tabIndex) _scheduleTips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// See the note in WorkspaceTab: every tab is built up front, so tips have to
  /// wait for this one to actually become the visible page.
  void _scheduleTips() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachMarks.showSequence(context, ref, [
        CoachMarkStep(
          id: TourSteps.groupsJoin,
          targetKey: _joinKey,
          title: 'Got an invite?',
          body:
              'Groups are invite-only — there is no directory to browse. Paste an invite '
              'code or link here to join one.',
        ),
        CoachMarkStep(
          id: TourSteps.groupsCreate,
          targetKey: _createKey,
          title: 'Or start your own',
          body:
              'You become the admin: you decide who joins, and you can remove or ban '
              'anyone. Everything shared inside stays inside.',
        ),
      ]);
    });
  }

  void _openCreateGroup() {
    HapticFeedback.lightImpact();
    AnalyticsService.instance.log(AnalyticsEvent.groupCreateStarted);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;
    final groupsAsync = ref.watch(filteredGroupsProvider);

    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == _tabIndex && previous != _tabIndex) _scheduleTips();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        _GroupsHeader(
          fg: fg,
          subtle: subtle,
          joinKey: _joinKey,
        ).animate().fadeIn(duration: 250.ms),

        const SizedBox(height: NoSusTheme.s16),

        // ── Search bar ─────────────────────────────────────────────────────
        _SearchBar(
          controller: _searchController,
          fg: fg,
          subtle: subtle,
          onChanged: (q) => ref.read(searchQueryProvider.notifier).update(q),
        ).animate().fadeIn(delay: 80.ms, duration: 250.ms),

        const SizedBox(height: NoSusTheme.s16),

        // ── Group list ─────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupsProvider);
              await ref.read(groupsProvider.future);
            },
            color: fg,
            backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
            child: AsyncStateView<List<StudyGroup>>(
              value: groupsAsync,
              onRetry: () => ref.invalidate(groupsProvider),
              errorMessage: 'Failed to load groups',
              loading: (context) => ShimmerListSkeleton(
                itemBuilder: (context) => const GroupCardSkeleton(),
              ),
              isEmpty: (groups) => groups.isEmpty,
              empty: (context) => GroupsEmptyState(onCreateGroup: _openCreateGroup),
              data: (context, groups) => _GroupList(
                groups: groups,
                onCreateGroup: _openCreateGroup,
                createKey: _createKey,
                onGroupTap: (group) => Navigator.of(
                  context,
                ).push(_slideRoute(GroupDetailScreen(group: group))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _GroupsHeader extends StatelessWidget {
  final Color fg;
  final Color subtle;
  final GlobalKey joinKey;
  const _GroupsHeader({
    required this.fg,
    required this.subtle,
    required this.joinKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STUDY GROUPS',
              style: TextStyle(
                color: subtle,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Secure Communities',
              style: TextStyle(
                color: fg,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        Tooltip(
          key: joinKey,
          message: 'Join Group',
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              AnalyticsService.instance.log(AnalyticsEvent.groupJoinStarted);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinGroupPage()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fg.withValues(alpha: 0.1)),
              ),
              child: Icon(Icons.group_add_outlined, color: fg, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Color fg;
  final Color subtle;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.fg,
    required this.subtle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.12), width: 0.75),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, size: 16, color: subtle),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: fg),
              cursorColor: fg,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search groups...',
                hintStyle: TextStyle(fontSize: 14, color: subtle),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  final List<StudyGroup> groups;
  final VoidCallback onCreateGroup;
  final GlobalKey createKey;
  final ValueChanged<StudyGroup> onGroupTap;

  const _GroupList({
    required this.groups,
    required this.onCreateGroup,
    required this.createKey,
    required this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.only(bottom: 90),
          physics: AlwaysScrollableScrollPhysics(
            parent: NoSusTheme.getScrollPhysics(context),
          ),
          itemCount: groups.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: NoSusTheme.s12),
          itemBuilder: (context, i) => GroupCard(
            group: groups[i],
            animationIndex: i,
            onTap: () => onGroupTap(groups[i]),
          ),
        ),

        // Floating action button
        Positioned(
          key: createKey,
          bottom: 16,
          right: 0,
          child: Semantics(
            button: true,
            label: 'Create group',
            child:
              GestureDetector(
                    onTap: onCreateGroup,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: fg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: fg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.surface,
                        size: 24,
                      ),
                    ),
                  )
                  .animate(delay: 400.ms)
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    duration: 350.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 200.ms),
          ),
        ),
      ],
    );
  }
}

// ─── Create group modal ───────────────────────────────────────────────────────

class _CreateGroupModal extends ConsumerStatefulWidget {
  const _CreateGroupModal();

  @override
  ConsumerState<_CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends ConsumerState<_CreateGroupModal> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _enableInviteCode = true;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 8 chars from a 32-symbol alphabet (no 0/O/1/I lookalikes) ≈ 1.1e12
  /// combinations — replaces the old `GRP-<timestamp%9999>` scheme, whose 4
  /// digits were guessable by brute force.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _create() async {
    if (_isCreating) return;
    if (_nameController.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();

    final currentUser = ref.read(authRepositoryProvider).currentUser;
    final userId = currentUser?.id ?? 'me';
    final userEmail = currentUser?.email ?? 'You';
    final cleanEmailPrefix = userEmail.contains('@') ? userEmail.split('@').first : '';
    final userInitials = cleanEmailPrefix.isNotEmpty
        ? cleanEmailPrefix.substring(0, cleanEmailPrefix.length >= 2 ? 2 : cleanEmailPrefix.length).toUpperCase()
        : 'ME';

    final newGroup = StudyGroup(
      id: 'g_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? 'Private study group'
          : _descController.text.trim(),
      members: [
        GroupMember(id: userId, name: userEmail, initials: userInitials, isAdmin: true),
      ],
      fileCount: 0,
      lastActivity: DateTime.now(),
      isWatermarkEnabled: true,
      inviteCode: _enableInviteCode ? _generateInviteCode() : null,
    );

    setState(() => _isCreating = true);
    try {
      await ref.read(groupsProvider.notifier).createGroup(newGroup);
      AnalyticsService.instance.log(AnalyticsEvent.groupCreateCompleted);
      if (mounted) {
        Navigator.of(context).pop();
        // Contextual, not at launch: the user now administers a group, so
        // join requests and document activity are things that will actually
        // happen to them. Uses the parent context — this sheet is being
        // dismissed, and its own context dies with it.
        await maybePrimeNotifications(
          context,
          ref,
          reason: "You're the admin of this group. Want to know when someone "
              'joins or shares a document?',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: ${_cleanError(e)}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _cleanError(Object e) => e
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll(RegExp(r'^PostgrestException\(message: '), '')
      .replaceAll(RegExp(r', code: .*\)$'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dCard : NoSusTheme.lCard;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: fg.withValues(alpha: 0.1), width: 0.75),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 20),
            Text(
              'NEW GROUP',
              style: TextStyle(
                color: subtle,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create Study Group',
              style: TextStyle(
                color: fg,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            _ModalField(
              controller: _nameController,
              hint: 'Group name',
              fg: fg,
              subtle: subtle,
            ),
            const SizedBox(height: 12),
            _ModalField(
              controller: _descController,
              hint: 'Description (optional)',
              fg: fg,
              subtle: subtle,
            ),
            const SizedBox(height: 16),

            // Invite code toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Generate invite code',
                    style: TextStyle(fontSize: 13, color: fg),
                  ),
                ),
                Semantics(
                  toggled: _enableInviteCode,
                  label: 'Generate invite code',
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _enableInviteCode = !_enableInviteCode),
                    child: Container(
                      // Invisible padding so the actual hit area reaches a
                      // reasonable minimum, without inflating the switch's
                      // small visual footprint.
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _enableInviteCode
                              ? fg
                              : fg.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Align(
                          alignment: _enableInviteCode
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _enableInviteCode
                                  ? (isDark ? Colors.black : Colors.white)
                                  : fg.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Create button
            Semantics(
              button: true,
              enabled: !_isCreating,
              label: 'Create group',
              child: GestureDetector(
                onTap: _isCreating ? null : _create,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isCreating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : Text(
                            'CREATE GROUP',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color fg;
  final Color subtle;

  const _ModalField({
    required this.controller,
    required this.hint,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.12), width: 0.75),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14, color: fg),
        cursorColor: fg,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: subtle),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

// ─── Slide page route ─────────────────────────────────────────────────────────

PageRouteBuilder<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}
