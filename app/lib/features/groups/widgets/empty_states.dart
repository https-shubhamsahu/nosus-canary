import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';
import '../../../theme.dart';

/// Minimal empty state for the groups list screen.
class GroupsEmptyState extends StatelessWidget {
  final VoidCallback onCreateGroup;
  const GroupsEmptyState({super.key, required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.35);

    return Center(
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotView(
                character: MascotCharacter.lux,
                size: 48,
                fallback: Icon(
                  Icons.group_work_outlined,
                  size: 48,
                  color: subtle,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Groups Yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a private study group to share\nsecure documents with trusted people.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: subtle, height: 1.6),
              ),
              const SizedBox(height: 28),
              Semantics(
                button: true,
                label: 'Create group',
                child: GestureDetector(
                  onTap: onCreateGroup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CREATE GROUP',
                      style: TextStyle(
                        color: theme.colorScheme.surface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

/// Minimal empty state for the files tab inside a group.
class FilesEmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const FilesEmptyState({super.key, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.35);

    return Center(
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotView(
                character: MascotCharacter.lux,
                size: 40,
                fallback: Icon(
                  Icons.upload_file_outlined,
                  size: 40,
                  color: subtle,
                ),
              ),
              const SizedBox(height: 16),
              Text('No Files Shared', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Upload the first secure document\nto this group.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: subtle, height: 1.6),
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: 'Upload file',
                child: GestureDetector(
                  onTap: onUpload,
                  child: Text(
                    'UPLOAD FILE',
                    style: TextStyle(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.5),
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}
