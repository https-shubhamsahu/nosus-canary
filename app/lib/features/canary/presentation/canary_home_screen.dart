import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../domain/canary_models.dart';
import 'canary_composer_screen.dart';
import 'canary_note_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/glow_card.dart';

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
    return CanaryUi.scaffold(
      title: CanaryUi.featureName,
      builder: (context) {
        return [
          Text(
            'NO SUS × MONAD',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: CanaryTokens.canary,
              fontFamily: CanaryTokens.displayFont,
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Every reader gets their own copy.',
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: CanaryTokens.text,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'If it leaks, the canary sings.',
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: CanaryTokens.canary,
          ),
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
        Text(
          'Your Canary notes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Kept only on this device. Leak checks work on the device that '
          'created the note.',
        ),
        const SizedBox(height: 8),
        if (_notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No Canary notes yet.'),
          ),
        for (final note in _notes)
          GlowCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CanaryNoteScreen(noteId: note.noteId),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: CanaryTokens.displayFont,
                          fontWeight: FontWeight.w600,
                          color: CanaryTokens.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${note.copyCount} copies · created ${CanaryUi.clock(note.createdAt)}',
                        style: const TextStyle(
                          fontFamily: CanaryTokens.monoFont,
                          color: CanaryTokens.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: CanaryTokens.textDim),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text(CanaryUi.honestyNote),
      ];
      },
    );
  }
}
