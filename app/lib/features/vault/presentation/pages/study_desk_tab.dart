import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../theme.dart';
import '../../../../components/shimmer_box.dart';
import '../../../../components/async_state_view.dart';
import '../../../groups/models/group_file.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../../components/spyglass_viewer.dart';

class StudyDeskTab extends ConsumerStatefulWidget {
  final String? initialFileId;

  const StudyDeskTab({
    super.key,
    this.initialFileId,
  });

  @override
  ConsumerState<StudyDeskTab> createState() => _StudyDeskTabState();
}

class _StudyDeskTabState extends ConsumerState<StudyDeskTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _selectedFileId;

  @override
  void initState() {
    super.initState();
    _selectedFileId = widget.initialFileId;
  }

  @override
  void didUpdateWidget(covariant StudyDeskTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFileId != oldWidget.initialFileId && widget.initialFileId != null) {
      setState(() {
        _selectedFileId = widget.initialFileId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;

    final filesAsync = ref.watch(groupFilesProvider);

    return RefreshIndicator(
      key: const ValueKey('studydesk_tab'),
      onRefresh: () async {
        ref.invalidate(groupFilesProvider);
        await ref.read(groupFilesProvider.future);
      },
      color: fg,
      backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(
            parent: NoSusTheme.getScrollPhysics(context),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: AsyncStateView<Map<String, List<GroupFile>>>(
              value: filesAsync,
              onRetry: () => ref.invalidate(groupFilesProvider),
              errorMessage: 'Failed to load your documents',
              loading: (context) =>
                  SizedBox(height: constraints.maxHeight, child: const _ViewerSkeleton()),
              isEmpty: (filesMap) =>
                  filesMap.values.every((files) => files.isEmpty),
              empty: (context) => SizedBox(
                height: constraints.maxHeight,
                child: _buildEmptyState(theme, isDark, fg),
              ),
              data: (context, filesMap) {
                final allFiles = filesMap.values.expand((x) => x).toList();
                final selectedFile = allFiles.firstWhere(
                  (f) => f.id == _selectedFileId,
                  orElse: () => allFiles.first,
                );
                return SizedBox(
                  height: constraints.maxHeight,
                  child: _buildViewer(theme, allFiles, selectedFile),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, Color fg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_person_outlined,
            size: 48,
            color: fg.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'NO DOCUMENT SELECTED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: fg.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload and select a document in the Vault or Groups tab.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViewer(
    ThemeData theme,
    List<GroupFile> allFiles,
    GroupFile selectedFile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPYGLASS VIEWER',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s4),
                  Text(
                    '${selectedFile.name}${selectedFile.type.extension}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NoSusTheme.s16),
            // Outlined dropdown to swap files
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoSusTheme.s12,
                  vertical: NoSusTheme.s8,
                ),
                decoration: NoSusTheme.buttonDecoration(context, radius: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: NoSusTheme.s8),
                    Text(
                      'Swap Doc',
                      style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              onSelected: (String id) {
                setState(() {
                  _selectedFileId = id;
                });
              },
              itemBuilder: (BuildContext context) {
                return allFiles.map((f) {
                  return PopupMenuItem<String>(
                    value: f.id,
                    child: Text(
                      '${f.name}${f.type.extension}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selectedFile.id == f.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ],
        ),
        const SizedBox(height: NoSusTheme.s24),

        // Secure viewer entry card — tapping opens full-screen SpyglassViewer
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open secure viewer for ${selectedFile.name}${selectedFile.type.extension}',
            child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpyglassViewer(
                    fileId: selectedFile.id,
                    groupId: selectedFile.groupId,
                    documentTitle: '${selectedFile.name}${selectedFile.type.extension}',
                    documentCategory: selectedFile.type.label,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_open_outlined,
                    size: 36,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TAP TO OPEN SECURE VIEWER',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 11,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${selectedFile.name}${selectedFile.type.extension}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: NoSusTheme.buttonDecoration(
                      context,
                      radius: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OPEN SECURE VIEWER',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          ).animate().fadeIn(duration: 350.ms),
        ),
      ],
    );
  }
}

/// Shimmer placeholder for the viewer entry card while [groupFilesProvider]
/// is loading.
class _ViewerSkeleton extends StatelessWidget {
  const _ViewerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            ShimmerBox(width: 140, height: 14),
          ],
        ),
        const SizedBox(height: NoSusTheme.s8),
        const ShimmerBox(width: 200, height: 20),
        const SizedBox(height: NoSusTheme.s24),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: NoSusTheme.cardDecoration(context),
            child: const Center(
              child: ShimmerBox(width: 180, height: 44, radius: 12),
            ),
          ),
        ),
      ],
    );
  }
}
