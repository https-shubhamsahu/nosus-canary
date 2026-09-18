import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/canary_models.dart';
import 'canary_composer_screen.dart';
import 'canary_note_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';

class CanaryHomeScreen extends ConsumerStatefulWidget {
  const CanaryHomeScreen({super.key});

  @override
  ConsumerState<CanaryHomeScreen> createState() => _CanaryHomeScreenState();
}

class _CanaryHomeScreenState extends ConsumerState<CanaryHomeScreen> {
  List<CanaryOwnerRecord> _notes = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _notes = ref.read(canaryRepositoryProvider).listNotes());
  }

  Future<void> _openComposer() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CanaryComposerScreen()),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(CanaryUi.featureName)),
      body: CanaryUi.page(
        children: [
          Text(
            'Every reader gets their own copy.\nIf it leaks, you will know whose.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Share one link in your group like any other link. Each person who '
            'opens it gets a copy worded a tiny bit differently. If a screenshot '
            'or pasted copy turns up somewhere it should not, NO SUS can tell '
            'which copy it came from.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openComposer,
            icon: const Icon(Icons.add),
            label: const Text('New Canary note'),
          ),
          const SizedBox(height: 28),
          Text('Your Canary notes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Kept only on this device. Leak checks work on the device that '
            'created the note.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (_notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No Canary notes yet.'),
            ),
          for (final note in _notes)
            Card.outlined(
              child: ListTile(
                title: Text(
                  note.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${note.copyCount} copies · created ${CanaryUi.clock(note.createdAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CanaryNoteScreen(noteId: note.noteId),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(CanaryUi.honestyNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
