import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import 'canary_composer_screen.dart';
import 'canary_note_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/glow_card.dart';
import 'ui/liquid_carve_button.dart';
import 'ui/swap_word_text.dart';

class CanaryHomeScreen extends ConsumerStatefulWidget {
  const CanaryHomeScreen({super.key});

  @override
  ConsumerState<CanaryHomeScreen> createState() => _CanaryHomeScreenState();
}

class _CanaryHomeScreenState extends ConsumerState<CanaryHomeScreen> {
  List<CanaryOwnerRecord> _notes = const [];
  late final CanaryPlan _demoPlan;
  late final List<List<int>> _demoWords;

  @override
  void initState() {
    super.initState();
    _demoPlan = buildCanaryPlan(kCanaryDemoNote);
    _demoWords = [
      List<int>.filled(_demoPlan.bitCount, 0),
      List<int>.filled(_demoPlan.bitCount, 1),
    ];
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
    return CanaryUi.frame(
      title: CanaryUi.featureName,
      body: (context) {
        final expanded = AppBreakpoints.isExpanded(context);
        final pad = expanded ? 32.0 : 20.0;
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: expanded
                        ? AppBreakpoints.contentMaxExpanded
                        : AppBreakpoints.contentMaxCompact,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (expanded)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _heroCopy(context)),
                            const SizedBox(width: 32),
                            Expanded(child: _demoCard(context)),
                          ],
                        )
                      else ...[
                        _heroCopy(context),
                        const SizedBox(height: 20),
                        _demoCard(context),
                      ],
                      const SizedBox(height: 36),
                      Text(
                        'How it works',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _howItWorks(expanded),
                      const SizedBox(height: 36),
                      Text(
                        'Your Canary notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kept only on this device. Leak checks work on the device that '
                        'created the note.',
                      ),
                      const SizedBox(height: 12),
                      if (_notes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No Canary notes yet.'),
                        ),
                      for (final note in _notes)
                        GlowCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CanaryNoteScreen(noteId: note.noteId),
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
                              const Icon(
                                Icons.chevron_right,
                                color: CanaryTokens.textDim,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(CanaryUi.honestyNote),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _heroCopy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NO SUS × MONAD',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: CanaryTokens.canary,
            fontFamily: CanaryTokens.displayFont,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Every reader gets their own copy.',
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontSize: AppBreakpoints.isExpanded(context) ? 48 : 32,
            fontWeight: FontWeight.w700,
            color: CanaryTokens.text,
            height: 1.08,
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
        const SizedBox(height: 24),
        LiquidCarveButton(
          label: 'Create a Canary link',
          icon: Icons.add,
          onPressed: _openComposer,
        ),
      ],
    );
  }

  Widget _demoCard(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Same note, different copies',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          SwapWordText(
            plan: _demoPlan,
            codewords: _demoWords,
            labels: const ['Copy 03 · Asha', 'Copy 17 · Ben'],
          ),
        ],
      ),
    );
  }

  Widget _howItWorks(bool expanded) {
    final cards = [
      (Icons.edit_outlined, 'Write once', 'One note. One link for the group.'),
      (
        Icons.copy_outlined,
        'Everyone gets a unique copy',
        'Tiny wording changes identify each reader.',
      ),
      (
        Icons.search,
        'Paste a leak, find the copy',
        'Matching stays on this device.',
      ),
    ];
    final children = [
      for (final c in cards)
        GlowCard(
          margin: EdgeInsets.only(
            bottom: expanded ? 0 : 12,
            right: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(c.$1, color: CanaryTokens.canary),
              const SizedBox(height: 12),
              Text(
                c.$2,
                style: const TextStyle(
                  fontFamily: CanaryTokens.displayFont,
                  fontWeight: FontWeight.w600,
                  color: CanaryTokens.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(c.$3),
            ],
          ),
        ),
    ];
    if (!expanded) {
      return Column(children: children);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
