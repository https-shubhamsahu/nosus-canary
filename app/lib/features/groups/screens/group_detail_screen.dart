import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/models/study_group.dart';
import '../models/group_file.dart';
import '../domain/repositories/study_group_repository.dart';
import '../providers/groups_provider.dart';
import '../widgets/file_card.dart';
import '../widgets/member_avatar_stack.dart';
import '../widgets/upload_modal.dart';
import '../../share/presentation/widgets/share_link_dialog.dart';
import '../../share/presentation/providers/share_providers.dart';
import '../../share/presentation/screens/share_analytics_screen.dart';
import '../widgets/empty_states.dart';
import '../../../theme.dart';
import '../../../components/spyglass_viewer.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../audit/providers/audit_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/screenshot_guard.dart';
import '../../../components/shimmer_box.dart';
import '../../../components/async_state_view.dart';
import '../../../core/utils/web_links.dart';

/// Full-screen group detail page with tabbed content:
/// Files | Notes | Members | Activity
class GroupDetailScreen extends ConsumerStatefulWidget {
  final StudyGroup group;
  final String? highlightedFileId;

  const GroupDetailScreen({super.key, required this.group, this.highlightedFileId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    ScreenshotGuard.instance.activeGroupId = widget.group.id;

    if (widget.highlightedFileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final filesAsync = ref.read(groupFilesForGroupProvider(widget.group.id));
        filesAsync.whenData((files) {
          final matched = files.firstWhere(
            (f) => f.id == widget.highlightedFileId,
            orElse: () => GroupFile(
              id: '',
              groupId: '',
              name: '',
              type: FileType.pdf,
              sizeBytes: 0,
              uploadedBy: '',
              ownerId: '',
              securityStatus: FileSecurityStatus.secured,
              isWatermarked: true,
              isPinned: false,
              uploadedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );
          if (matched.id.isNotEmpty && matched.type == FileType.markdown) {
            _tabController.animateTo(1);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    if (ScreenshotGuard.instance.activeGroupId == widget.group.id) {
      ScreenshotGuard.instance.activeGroupId = null;
    }
    _tabController.dispose();
    super.dispose();
  }

  void _openUploadModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadModal(groupId: widget.group.id),
    );
  }

  void _openInviteModal(StudyGroup group) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteModal(group: group),
    );
  }

  void _confirmLeaveGroup(BuildContext context, WidgetRef ref, StudyGroup group) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text('LEAVE GROUP?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: Text('Are you sure you want to leave "${group.name}"? You will lose access to all files and notes.', style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Close dialog
                await ref.read(groupsProvider.notifier).leaveGroup(group.id);
                navigator.pop(); // Pop group details screen
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('You left group "${group.name}"'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('LEAVE', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteGroup(BuildContext context, WidgetRef ref, StudyGroup group) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text('DELETE GROUP?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: Text('Are you sure you want to permanently delete "${group.name}"? This will delete all members, notes, and files and cannot be undone.', style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Close dialog
                await ref.read(groupsProvider.notifier).deleteGroup(group.id);
                navigator.pop(); // Pop group details screen
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Group "${group.name}" deleted'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;
    final cardBg = isDark ? NoSusTheme.dCard : NoSusTheme.lCard;

    // .select() narrows this widget's rebuild trigger to just THIS group's
    // data (now that StudyGroup has value equality) instead of the whole
    // groups list — previously this rebuilt the entire scaffold/tabs
    // whenever ANY group changed, not just this one.
    final group = ref.watch(groupsProvider.select((async) => async.maybeWhen(
          data: (list) {
            try {
              return list.firstWhere((g) => g.id == widget.group.id);
            } catch (_) {
              return widget.group;
            }
          },
          orElse: () => widget.group,
        )));

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupFilesProvider);
          ref.invalidate(groupMembersProvider(widget.group.id));
          ref.invalidate(auditLogsProvider);
          await Future.wait([
            ref.read(groupFilesProvider.future),
            ref.read(groupMembersProvider(widget.group.id).future),
          ]);
        },
        color: fg,
        backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
        child: NestedScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        headerSliverBuilder: (context, _) => [
          // ── Sliver app bar ──────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: bg,
            // Title + counts must sit above the pinned tab bar. 200px was
            // shorter than that stack, so member/file counts painted on the tabs.
            expandedHeight: 240,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: fg, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Invite button for admins
              if (group.members.any((m) => m.id == ref.watch(authStateProvider).value?.id && m.isAdmin) && group.inviteCode != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(Icons.group_add_outlined, color: fg),
                    onPressed: () => _openInviteModal(group),
                    tooltip: 'Invite Members',
                  ),
                ),
              // Group Options
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: fg),
                onSelected: (val) {
                  if (val == 'leave') {
                    _confirmLeaveGroup(context, ref, group);
                  } else if (val == 'delete') {
                    _confirmDeleteGroup(context, ref, group);
                  }
                },
                itemBuilder: (context) {
                  // ref.read, not watch — this callback only runs when the
                  // menu opens, not during reactive build, so watching here
                  // registers a listener with no effect.
                  final isCurrentUserAdmin = group.members.any((m) => m.id == ref.read(authStateProvider).value?.id && m.isAdmin);
                  return [
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app, size: 16),
                          SizedBox(width: 8),
                          Text('Leave Group', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isCurrentUserAdmin)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Delete Group', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                  ];
                },
              ),
              // Upload FAB in app bar
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Semantics(
                  button: true,
                  label: 'Upload file',
                  child: GestureDetector(
                  onTap: _openUploadModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'UPLOAD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.none,
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                          group.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 60.ms)
                        .slideY(begin: 0.03, end: 0),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MemberAvatarStack(
                          members: group.members,
                          maxVisible: 4,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${group.memberCount} members  ·  ${group.fileCount} files',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: subtle),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
              ),
            ),
            // Tab bar pinned at bottom of sliver
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: fg.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: fg,
                  unselectedLabelColor: subtle,
                  indicatorColor: fg,
                  indicatorWeight: 1.5,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(text: 'FILES'),
                    Tab(text: 'NOTES'),
                    Tab(text: 'MEMBERS'),
                    Tab(text: 'ACTIVITY'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _FilesTab(
              group: group,
              onUpload: _openUploadModal,
              highlightedFileId: widget.highlightedFileId,
            ),
            _NotesTab(
              group: group,
              fg: fg,
              subtle: subtle,
              cardBg: cardBg,
              highlightedFileId: widget.highlightedFileId,
            ),
            _MembersTab(groupId: group.id, fg: fg, subtle: subtle),
            _ActivityTab(groupId: group.id, fg: fg, subtle: subtle),
          ],
        ),
      ),
     ),
    );
  }
}

// ─── Files tab ────────────────────────────────────────────────────────────────

class _FilesTab extends ConsumerWidget {
  final StudyGroup group;
  final VoidCallback onUpload;
  final String? highlightedFileId;

  const _FilesTab({
    required this.group,
    required this.onUpload,
    this.highlightedFileId,
  });

  void _confirmDeleteFile(BuildContext context, WidgetRef ref, String groupId, String fileId, String fileName) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text('DELETE FILE?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: Text('Are you sure you want to permanently delete "$fileName"?', style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                ref.read(groupFilesProvider.notifier).removeFile(groupId, fileId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File "$fileName" deleted'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _renameFile(BuildContext context, WidgetRef ref, String fileId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text('RENAME FILE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: fg),
            decoration: InputDecoration(
              labelText: 'FILE NAME',
              labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(groupFilesProvider.notifier).renameFile(fileId, newName);
                  Navigator.pop(context);
                }
              },
              child: Text('RENAME', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(groupFilesForGroupProvider(group.id));

    return filesAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        child: ShimmerListSkeleton(
          itemBuilder: (context) => const _FileCardSkeleton(),
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load files',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(groupFilesProvider),
              child: const Text('RETRY', style: TextStyle(fontSize: 11, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
      data: (allFiles) {
        final files = allFiles.where((f) => f.type != FileType.markdown).toList();
        
        return files.isEmpty
            ? FilesEmptyState(onUpload: onUpload)
            : ListView.separated(
                padding: const EdgeInsets.all(NoSusTheme.s24),
                physics: AlwaysScrollableScrollPhysics(
                  parent: NoSusTheme.getScrollPhysics(context),
                ),
                itemCount: files.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: NoSusTheme.s12),
                itemBuilder: (context, i) {
                  final file = files[i];
                  final isHighlighted = file.id == highlightedFileId;
                  final uploaderName = group.members.where((m) => m.id == file.uploadedBy).firstOrNull?.name ?? 'Unknown';
                  Widget card = FileCard(
                    file: file,
                    uploaderName: uploaderName,
                    animationIndex: i,
                    onDelete: () => _confirmDeleteFile(context, ref, group.id, file.id, file.name),
                    onRename: () => _renameFile(context, ref, file.id, file.name),
                    onShare: () => showShareLinkDialog(context, ref, file.id),
                    onAnalytics: () async {
                      try {
                        final repo = ref.read(shareRepositoryProvider);
                        final links = await repo.myLinksForFile(file.id);
                        final activeLink = links.where((l) => !l.revoked).firstOrNull;
                        if (activeLink != null) {
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShareAnalyticsScreen(
                                linkId: activeLink.id,
                                fileName: file.name,
                              ),
                            ),
                          );
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No active share links found. Create one first!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to check links: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    onPin: () => ref
                        .read(groupFilesProvider.notifier)
                        .togglePin(group.id, file.id),
                    onOpen: () => _evaluateAndOpenFile(
                      context: context,
                      ref: ref,
                      file: file,
                      group: group,
                    ),
                  );
                  if (isHighlighted) {
                    card = Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: card,
                    ).animate().shake(delay: 200.ms, duration: 500.ms);
                  }
                  return card;
                },
              );
      },
    );
  }
}

// ─── Notes tab ────────────────────────────────────────────────────────────────

class _NotesTab extends ConsumerWidget {
  final StudyGroup group;
  final Color fg;
  final Color subtle;
  final Color cardBg;
  final String? highlightedFileId;

  const _NotesTab({
    required this.group,
    required this.fg,
    required this.subtle,
    required this.cardBg,
    this.highlightedFileId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(groupFilesForGroupProvider(group.id));

    return filesAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        child: ShimmerListSkeleton(
          itemBuilder: (context) => const _FileCardSkeleton(),
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load notes', style: TextStyle(color: subtle)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(groupFilesProvider),
              child: const Text('RETRY', style: TextStyle(fontSize: 11, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
      data: (allFiles) {
        final notes = allFiles.where((f) => f.type == FileType.markdown).toList();

        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_alt_outlined, size: 48, color: subtle),
                const SizedBox(height: 16),
                Text(
                  'NO SECURE NOTES YET',
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Auto-generated group notes will appear here shortly.',
                  style: TextStyle(color: subtle, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(NoSusTheme.s24),
          physics: NoSusTheme.getScrollPhysics(context),
          itemCount: notes.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: NoSusTheme.s12),
          itemBuilder: (context, i) {
            final note = notes[i];
            final isHighlighted = note.id == highlightedFileId;
            final uploaderName = group.members.where((m) => m.id == note.uploadedBy).firstOrNull?.name ?? 'Unknown';
            Widget card = _PinnedNoteCard(
              note: note,
              uploaderName: uploaderName,
              fg: fg,
              subtle: subtle,
              cardBg: cardBg,
              index: i,
              onOpen: () => _evaluateAndOpenFile(
                context: context,
                ref: ref,
                file: note,
                group: group,
              ),
              onRename: () => _renameNote(context, ref, note.id, note.name),
              onDelete: () => _confirmDeleteNote(context, ref, group.id, note.id, note.name),
            );
            if (isHighlighted) {
              card = Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: card,
              ).animate().shake(delay: 200.ms, duration: 500.ms);
            }
            return card;
          },
        );
      },
    );
  }

  void _confirmDeleteNote(BuildContext context, WidgetRef ref, String groupId, String fileId, String fileName) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text('DELETE NOTE?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: Text('Are you sure you want to permanently delete "$fileName"?', style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                ref.read(groupFilesProvider.notifier).removeFile(groupId, fileId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Note "$fileName" deleted'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _renameNote(BuildContext context, WidgetRef ref, String fileId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text('RENAME NOTE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: fg),
            decoration: InputDecoration(
              labelText: 'NOTE NAME',
              labelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 10),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(groupFilesProvider.notifier).renameFile(fileId, newName);
                  Navigator.pop(context);
                }
              },
              child: Text('RENAME', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _PinnedNoteCard extends StatelessWidget {
  final GroupFile note;
  final String uploaderName;
  final Color fg;
  final Color subtle;
  final Color cardBg;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _PinnedNoteCard({
    required this.note,
    required this.uploaderName,
    required this.fg,
    required this.subtle,
    required this.cardBg,
    required this.index,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open pinned note ${note.name}',
      child: GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(NoSusTheme.s16),
        decoration: NoSusTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin, size: 12, color: subtle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.name,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: subtle.withValues(alpha: 0.7),
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                  ),
                  onSelected: (val) {
                    if (val == 'open') {
                      onOpen();
                    } else if (val == 'rename') {
                      onRename();
                    } else if (val == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 14, color: fg),
                          const SizedBox(width: 8),
                          const Text('Open Note', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: fg),
                          const SizedBox(width: 8),
                          const Text('Rename Note', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete Note', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to view note content...',
              style: TextStyle(
                color: fg.withValues(alpha: 0.4),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploaded by $uploaderName  ·  ${note.uploadedAtLabel}',
              style: TextStyle(
                color: subtle,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      )
    .animate(delay: (index.clamp(0, 10) * 80).ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.03, end: 0),
    );
  }
}

// ─── Zero-Trust Gateway File Open Helper ──────────────────────────────────────

Future<void> _evaluateAndOpenFile({
  required BuildContext context,
  required WidgetRef ref,
  required GroupFile file,
  required StudyGroup group,
}) async {
  // Log successful document access
  ref.read(auditLogsProvider.notifier).addLog(
        "Document Access Authorized: ${file.name}",
        "SUCCESS",
      );

  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpyglassViewer(
          fileId: file.id,
          groupId: file.groupId,
          documentTitle: file.name,
          documentCategory: file.type.label,
        ),
      ),
    );
  }
}

/// Shimmer placeholder matching one [FileCard] row: icon chip + name + meta.
class _FileCardSkeleton extends StatelessWidget {
  const _FileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s16),
      decoration: NoSusTheme.cardDecoration(context),
      child: const Row(
        children: [
          ShimmerBox(width: 40, height: 40, radius: 10),
          SizedBox(width: NoSusTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 14),
                SizedBox(height: 6),
                ShimmerBox(width: 90, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

/// Member roster and moderation.
///
/// Every destructive control here is a convenience over a server-side rule, not
/// the rule itself: `set_group_member_role`, `remove_group_member` and
/// `ban_group_member` re-check admin rights in the database and refuse to strip
/// a group of its last admin. A member who patches the client into showing
/// these buttons gets a rejection, not a promotion.
class _MembersTab extends ConsumerStatefulWidget {
  final String groupId;
  final Color fg;
  final Color subtle;

  const _MembersTab({
    required this.groupId,
    required this.fg,
    required this.subtle,
  });

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  Color get _fg => widget.fg;
  Color get _subtle => widget.subtle;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The RPCs raise readable messages on purpose ("This is the last admin.
  /// Promote someone else first.") so the reason for a refusal reaches the
  /// person who tried, instead of being replaced by a generic failure toast
  /// that makes a deliberate rule look like a bug.
  String _cleanError(Object e) => e
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll(RegExp(r'^PostgrestException\(message: '), '')
      .replaceAll(RegExp(r', code: .*\)$'), '');

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: destructive ? Colors.redAccent : null,
            ),
          ),
          content: Text(body, style: const TextStyle(fontSize: 12, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmLabel,
                style: TextStyle(
                  color: destructive ? Colors.redAccent : null,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _confirmRemoveMember(GroupMember member) async {
    final ok = await _confirm(
      title: 'REMOVE MEMBER?',
      body:
          '${member.name} loses access to this group\'s files immediately. They can '
          'rejoin with a valid invite — ban them instead if that is not what you want.',
      confirmLabel: 'REMOVE',
    );
    if (!ok) return;
    HapticFeedback.heavyImpact();
    await _run(
      () => ref
          .read(groupsProvider.notifier)
          .removeMember(widget.groupId, member.id),
      'Removed ${member.name} from the group',
    );
  }

  Future<void> _confirmBanMember(GroupMember member) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          title: const Text(
            'BAN MEMBER?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${member.name} is removed from the group and cannot rejoin with any '
                'invite until you unban them.',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 280,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  labelStyle: TextStyle(fontSize: 11),
                  helperText: 'Visible to every member of this group.',
                  helperStyle: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'BAN',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true) return;
    HapticFeedback.heavyImpact();
    await _run(
      () => ref.read(groupsProvider.notifier).banMember(
            widget.groupId,
            member.id,
            reason: reason.isEmpty ? null : reason,
          ),
      'Banned ${member.name}',
    );
  }

  Future<void> _confirmSetRole(GroupMember member, bool makeAdmin) async {
    final ok = await _confirm(
      title: makeAdmin ? 'MAKE ADMIN?' : 'REMOVE ADMIN?',
      body: makeAdmin
          ? '${member.name} will be able to manage members, delete anyone\'s files, '
              'and delete the group itself.'
          : '${member.name} keeps access to the group but loses every admin power.',
      confirmLabel: makeAdmin ? 'MAKE ADMIN' : 'REMOVE ADMIN',
      destructive: !makeAdmin,
    );
    if (!ok) return;
    HapticFeedback.mediumImpact();
    await _run(
      () => ref
          .read(groupsProvider.notifier)
          .setMemberRole(widget.groupId, member.id, makeAdmin),
      makeAdmin
          ? '${member.name} is now an admin'
          : '${member.name} is no longer an admin',
    );
  }

  Future<void> _confirmUnban(GroupBan ban) async {
    final ok = await _confirm(
      title: 'LIFT BAN?',
      body:
          '${ban.displayName} will be able to accept an invite again. They are not '
          'added back to the group automatically.',
      confirmLabel: 'LIFT BAN',
      destructive: false,
    );
    if (!ok) return;
    await _run(
      () => ref
          .read(groupsProvider.notifier)
          .unbanMember(widget.groupId, ban.userId),
      'Ban lifted for ${ban.displayName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return membersAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        child: ShimmerListSkeleton(
          itemBuilder: (context) => const _MemberRowSkeleton(),
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load members', style: TextStyle(color: _subtle)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.invalidate(groupMembersProvider(widget.groupId)),
              child: const Text(
                'RETRY',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 48, color: _subtle),
                const SizedBox(height: 16),
                Text(
                  'NO MEMBERS YET',
                  style: TextStyle(
                    color: _fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          );
        }
        return _buildList(context, list);
      },
    );
  }

  Widget _buildList(BuildContext context, List<GroupMember> all) {
    final currentUserId = ref.watch(authStateProvider).value?.id;
    final isCurrentUserAdmin =
        all.any((m) => m.id == currentUserId && m.isAdmin);
    final adminCount = all.where((m) => m.isAdmin).length;

    // Admins first, then alphabetical — the roster's job is to answer "who runs
    // this group" before "who is in it".
    final sorted = [...all]..sort((a, b) {
        if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? sorted
        : sorted.where((m) => m.name.toLowerCase().contains(q)).toList();

    final bansAsync = ref.watch(groupBansProvider(widget.groupId));
    final bans = bansAsync.value ?? const <GroupBan>[];

    return ListView(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      physics: AlwaysScrollableScrollPhysics(
        parent: NoSusTheme.getScrollPhysics(context),
      ),
      children: [
        // Search appears once the roster is big enough to need it — a filter
        // over four people is clutter.
        if (all.length >= 8) ...[
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(fontSize: 14, color: _fg),
            cursorColor: _fg,
            decoration: InputDecoration(
              hintText: 'Search members',
              hintStyle: TextStyle(fontSize: 14, color: _subtle),
              prefixIcon: Icon(Icons.search, size: 18, color: _subtle),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NoSusTheme.r12),
                borderSide: BorderSide(color: _fg.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NoSusTheme.r12),
                borderSide: BorderSide(color: _fg.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NoSusTheme.r12),
                borderSide: BorderSide(color: _fg),
              ),
            ),
          ),
          const SizedBox(height: NoSusTheme.s16),
        ],

        _RosterLabel(
          text: '${all.length} MEMBER${all.length == 1 ? '' : 'S'}'
              ' · $adminCount ADMIN${adminCount == 1 ? '' : 'S'}',
          color: _subtle,
        ),
        const SizedBox(height: NoSusTheme.s8),

        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NoSusTheme.s32),
            child: Text(
              'No member matches "$_query".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _subtle),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            _MemberRow(
              member: visible[i],
              fg: _fg,
              subtle: _subtle,
              isSelf: visible[i].id == currentUserId,
              canModerate:
                  isCurrentUserAdmin && visible[i].id != currentUserId,
              index: i,
              onSetRole: (makeAdmin) =>
                  _confirmSetRole(visible[i], makeAdmin),
              onRemove: () => _confirmRemoveMember(visible[i]),
              onBan: () => _confirmBanMember(visible[i]),
            ),
            const SizedBox(height: NoSusTheme.s12),
          ],

        // Bans are shown to every member, not just admins — the same
        // reasoning that makes the audit log group-visible. Moderation that
        // only moderators can see is not accountable.
        if (bans.isNotEmpty) ...[
          const SizedBox(height: NoSusTheme.s16),
          _RosterLabel(text: 'BANNED (${bans.length})', color: _subtle),
          const SizedBox(height: NoSusTheme.s8),
          for (final ban in bans) ...[
            _BanRow(
              ban: ban,
              fg: _fg,
              subtle: _subtle,
              onUnban:
                  isCurrentUserAdmin ? () => _confirmUnban(ban) : null,
            ),
            const SizedBox(height: NoSusTheme.s12),
          ],
        ],
        const SizedBox(height: NoSusTheme.s32),
      ],
    );
  }
}

class _RosterLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _RosterLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final GroupMember member;
  final Color fg;
  final Color subtle;
  final bool isSelf;
  final bool canModerate;
  final int index;
  final ValueChanged<bool> onSetRole;
  final VoidCallback onRemove;
  final VoidCallback onBan;

  const _MemberRow({
    required this.member,
    required this.fg,
    required this.subtle,
    required this.isSelf,
    required this.canModerate,
    required this.index,
    required this.onSetRole,
    required this.onRemove,
    required this.onBan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(NoSusTheme.s16),
          decoration: NoSusTheme.cardDecoration(context),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: fg.withValues(alpha: 0.15),
                    width: 0.75,
                  ),
                ),
                child: Center(
                  child: Text(
                    member.initials,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelf ? '${member.name} (you)' : member.name,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      member.isAdmin ? 'Admin' : 'Member',
                      style: TextStyle(color: subtle, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (member.isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: fg.withValues(alpha: 0.2),
                      width: 0.75,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 9,
                      color: subtle,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              if (canModerate)
                PopupMenuButton<String>(
                  // 48dp minimum touch target, and a real label for screen
                  // readers — a bare icon announces nothing useful.
                  tooltip: 'Manage ${member.name}',
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: subtle,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'promote':
                        onSetRole(true);
                      case 'demote':
                        onSetRole(false);
                      case 'remove':
                        onRemove();
                      case 'ban':
                        onBan();
                    }
                  },
                  itemBuilder: (context) => [
                    if (member.isAdmin)
                      const PopupMenuItem(
                        value: 'demote',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.remove_moderator_outlined, size: 18),
                          title: Text('Remove admin', style: TextStyle(fontSize: 13)),
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'promote',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.add_moderator_outlined, size: 18),
                          title: Text('Make admin', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.person_remove_outlined, size: 18),
                        title: Text('Remove from group',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'ban',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.block, size: 18, color: Colors.redAccent),
                        title: Text(
                          'Ban from group',
                          style: TextStyle(fontSize: 13, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        )
        .animate(delay: (index.clamp(0, 10) * 60).ms)
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.03, end: 0);
  }
}

class _BanRow extends StatelessWidget {
  final GroupBan ban;
  final Color fg;
  final Color subtle;
  final VoidCallback? onUnban;

  const _BanRow({
    required this.ban,
    required this.fg,
    required this.subtle,
    required this.onUnban,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(NoSusTheme.r16),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.15),
          width: 0.75,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 18, color: Colors.redAccent.withValues(alpha: 0.8)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ban.displayName,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  ban.reason == null || ban.reason!.isEmpty
                      ? 'No reason given'
                      : ban.reason!,
                  style: TextStyle(color: subtle, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          if (onUnban != null)
            TextButton(
              onPressed: onUnban,
              child: const Text(
                'UNBAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder matching one member row: avatar + name + role.
class _MemberRowSkeleton extends StatelessWidget {
  const _MemberRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ShimmerBox(width: 40, height: 40, radius: 20),
        SizedBox(width: NoSusTheme.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 120, height: 14),
              SizedBox(height: 6),
              ShimmerBox(width: 70, height: 11),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Activity tab ─────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  final String groupId;
  final Color fg;
  final Color subtle;

  const _ActivityTab({
    required this.groupId,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return AsyncStateView<List<Map<String, String>>>(
      value: auditLogsAsync,
      onRetry: () => ref.invalidate(auditLogsProvider),
      errorMessage: 'Failed to load activity',
      loading: (context) => Padding(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        child: ShimmerListSkeleton(
          spacing: NoSusTheme.s16,
          itemBuilder: (context) => const _ActivityRowSkeleton(),
        ),
      ),
      isEmpty: (logs) => logs.isEmpty,
      empty: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_outlined, size: 48, color: subtle),
            const SizedBox(height: 16),
            Text(
              'NO ACTIVITY YET',
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Group activities will appear here.',
              style: TextStyle(color: subtle, fontSize: 13),
            ),
          ],
        ),
      ),
      data: (context, auditLogs) => ListView.builder(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        itemCount: auditLogs.length,
        itemBuilder: (_, i) {
          final item = auditLogs[i];
          final event = item['event'] ?? '';
          final time = item['time'] ?? '';
          final status = item['status'] ?? '';
          final icon = _iconForStatus(status);

          return Padding(
            padding: const EdgeInsets.only(bottom: NoSusTheme.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fg.withValues(alpha: 0.12),
                      width: 0.75,
                    ),
                  ),
                  child: Icon(icon, size: 14, color: subtle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event,
                        style: TextStyle(color: fg, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(color: subtle, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate(delay: (i.clamp(0, 10) * 60).ms).fadeIn(duration: 250.ms),
          );
        },
      ),
    );
  }

  IconData _iconForStatus(String status) => switch (status.toUpperCase()) {
    'SUCCESS' => Icons.check_circle_outline,
    'SECURITY' => Icons.gpp_maybe_outlined,
    'INFO' => Icons.info_outline,
    _ => Icons.info_outline,
  };
}

/// Shimmer placeholder matching one activity row: icon circle + event + time.
class _ActivityRowSkeleton extends StatelessWidget {
  const _ActivityRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 32, height: 32, radius: 16),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: double.infinity, height: 13),
              SizedBox(height: 6),
              ShimmerBox(width: 80, height: 11),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteModal extends StatelessWidget {
  final StudyGroup group;

  const _InviteModal({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dCard : NoSusTheme.lCard;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final (:origin, :basePath) = webShareLinkBase();
    final inviteLink = '$origin$basePath/#/join/${group.inviteCode}';

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
              'INVITE MEMBERS',
              style: TextStyle(
                color: fg.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share Access Link & Code',
              style: TextStyle(
                color: fg,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'INVITE CODE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.inviteCode ?? 'NO-CODE',
                    style: TextStyle(
                      color: fg,
                      fontSize: 24,
                      letterSpacing: 4.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24, thickness: 0.5),
                  const Text(
                    'INVITE LINK',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inviteLink,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invite link copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.copy, size: 18, color: fg),
                    label: Text(
                      'COPY LINK',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: fg.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final text = 'Join my secure workspace "${group.name}" on NoSus! Use link: $inviteLink';
                      SharePlus.instance.share(ShareParams(text: text));
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.ios_share, size: 18, color: isDark ? Colors.black : Colors.white),
                    label: const Text(
                      'SHARE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fg,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

