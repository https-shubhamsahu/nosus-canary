import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:no_sus/main.dart' show activeTabProvider;
import '../../../../theme.dart';
import '../../../../components/coach_mark.dart';
import '../../../../components/shimmer_box.dart';
import '../../../../components/async_state_view.dart';
import '../../../groups/models/group_file.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../onboarding/presentation/providers/tour_providers.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';

class VaultTab extends ConsumerStatefulWidget {
  final ValueChanged<String> onRevealRequested;

  const VaultTab({
    super.key,
    required this.onRevealRequested,
  });

  @override
  ConsumerState<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends ConsumerState<VaultTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _selectedFileId;

  static const _tabIndex = 1;

  /// Anchors the first document row. Deliberately not a fixed header: the tip
  /// explains what happens when you open a document, which only means anything
  /// once there is one to open.
  final _firstFileKey = GlobalKey();

  /// See [_WorkspaceTabState._scheduleTips] — every tab is constructed with the
  /// shell, so visibility has to be gated on the active tab rather than mount.
  void _scheduleTips() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachMarks.showSequence(context, ref, [
        CoachMarkStep(
          id: TourSteps.vaultReveal,
          targetKey: _firstFileKey,
          title: 'Documents open in a protected reader',
          body:
              'Tap REVEAL and the file opens in the Study Desk rather than downloading — '
              'watermarked with your identity, and recorded in the group\'s audit log.',
        ),
      ]);
    });
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(activeTabProvider) == _tabIndex) _scheduleTips();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == _tabIndex && previous != _tabIndex) _scheduleTips();
    });

    final filesAsync = ref.watch(groupFilesProvider);

    return Column(
      key: const ValueKey('vault_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STUDY VAULT',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: NoSusTheme.s24),

        // List of classified study documents
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupFilesProvider);
              await ref.read(groupFilesProvider.future);
            },
            color: fg,
            backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
            child: AsyncStateView<Map<String, List<GroupFile>>>(
              value: filesAsync,
              onRetry: () => ref.invalidate(groupFilesProvider),
              errorMessage: 'Failed to load your secure documents',
              loading: (context) => ShimmerListSkeleton(
                spacing: NoSusTheme.s16,
                itemBuilder: (context) => const _FileRowSkeleton(),
              ),
              isEmpty: (filesMap) =>
                  filesMap.values.every((files) => files.isEmpty),
              empty: (context) => _buildEmptyState(fg, subtle),
              data: (context, filesMap) => _buildFileList(
                theme,
                filesMap.values.expand((x) => x).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color fg, Color subtle) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Nothing to guard yet — Nox waits. (Falls back to the
                // original folder icon until nox.riv exists.)
                MascotView(
                  character: MascotCharacter.nox,
                  size: 48,
                  fallback: Icon(
                    Icons.folder_off_outlined,
                    size: 48,
                    color: fg.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NO SECURE DOCUMENTS YET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: fg.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Navigate to the Groups tab to upload secure files.',
                  style: TextStyle(fontSize: 13, color: subtle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileList(ThemeData theme, List<GroupFile> allFiles) {
    return ListView.separated(
      physics: AlwaysScrollableScrollPhysics(
        parent: NoSusTheme.getScrollPhysics(context),
      ),
      itemCount: allFiles.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: NoSusTheme.s16),
      itemBuilder: (context, index) {
        final file = allFiles[index];
        final isSelected = _selectedFileId == file.id;

        return Container(
          key: index == 0 ? _firstFileKey : null,
          padding: const EdgeInsets.all(NoSusTheme.s24),
          decoration: NoSusTheme.cardDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: NoSusTheme.s8,
                            vertical: 3,
                          ),
                          decoration: NoSusTheme.buttonDecoration(
                            context,
                            radius: 6,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.05),
                          ),
                          child: Text(
                            file.type.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: NoSusTheme.s8),
                        Text(
                          file.sizeLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: NoSusTheme.s12),
                    Text(
                      '${file.name}${file.type.extension}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: NoSusTheme.s4),
                    Text(
                      'Imported: ${file.uploadedAtLabel}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NoSusTheme.s24),
              // Action button to open in Spyglass
              Semantics(
                button: true,
                label: 'Reveal ${file.name}',
                child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFileId = file.id;
                  });
                  widget.onRevealRequested(file.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NoSusTheme.s16,
                    vertical: NoSusTheme.s12,
                  ),
                  decoration: NoSusTheme.buttonDecoration(
                    context,
                    radius: 12,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.surface
                            : theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: NoSusTheme.s8),
                      Text(
                        'REVEAL',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 11,
                          color: isSelected
                              ? theme.colorScheme.surface
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

/// Shimmer placeholder matching the file-row card layout in [_buildFileList].
class _FileRowSkeleton extends StatelessWidget {
  const _FileRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      decoration: NoSusTheme.cardDecoration(context),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 48, height: 16, radius: 6),
                    SizedBox(width: NoSusTheme.s8),
                    ShimmerBox(width: 40, height: 14),
                  ],
                ),
                SizedBox(height: NoSusTheme.s12),
                ShimmerBox(width: 160, height: 16),
                SizedBox(height: NoSusTheme.s4),
                ShimmerBox(width: 120, height: 12),
              ],
            ),
          ),
          SizedBox(width: NoSusTheme.s24),
          ShimmerBox(width: 90, height: 40, radius: 12),
        ],
      ),
    );
  }
}
