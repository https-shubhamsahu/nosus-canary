import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_mode.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import 'canary_composer_screen.dart';
import 'canary_note_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/canary_envelope.dart';
import 'ui/canary_nav_bar.dart';
import 'ui/chain_chip.dart';
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

  final _howItWorksKey = GlobalKey();
  final _notesKey = GlobalKey();

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

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onCheckLeak() {
    if (_notes.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CanaryNoteScreen(noteId: _notes.first.noteId),
        ),
      );
    } else {
      _scrollTo(_notesKey);
    }
  }

  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CanaryUi.frame(
      title: CanaryUi.featureName,
      customAppBar: CanaryTopBar(
        onHowItWorks: () => _scrollTo(_howItWorksKey),
        onNotes: () => _scrollTo(_notesKey),
        onCheckLeak: _onCheckLeak,
        standalone: kCanaryOnly,
      ),
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
                      const SizedBox(height: 48),

                      // Section: How it works
                      Container(
                        key: _howItWorksKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How it works',
                              style: TextStyle(
                                fontFamily: CanaryTokens.displayFont,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: CanaryTokens.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Three steps to leak-proof private notes',
                              style: TextStyle(
                                color: CanaryTokens.textDim,
                                fontSize: 14,
                              ),
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 12),
                              const HowItWorksConnector(),
                              const SizedBox(height: 12),
                            ] else
                              const SizedBox(height: 16),
                            _howItWorks(expanded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Section: Your Canary notes
                      Container(
                        key: _notesKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Canary notes',
                              style: TextStyle(
                                fontFamily: CanaryTokens.displayFont,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: CanaryTokens.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Kept only on this device. Clearing your browser data deletes them.',
                              style: TextStyle(
                                color: CanaryTokens.textDim,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_notes.isEmpty)
                              _emptyNotesCard(context)
                            else
                              for (final note in _notes) _noteCard(context, note),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(CanaryUi.honestyNote),
                      if (kCanaryOnly) ...[
                        const SizedBox(height: 36),
                        const CanaryFooter(),
                      ],
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

  Widget _emptyNotesCard(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BobbingCanaryMark(size: 48),
            const SizedBox(height: 12),
            const Text(
              'No Canary notes yet',
              style: TextStyle(
                fontFamily: CanaryTokens.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CanaryTokens.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Make one with the demo note. It takes 20 seconds.',
              style: TextStyle(
                color: CanaryTokens.textDim,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: CanaryTokens.text,
                side: const BorderSide(color: CanaryTokens.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CanaryTokens.rChip),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                minimumSize: const Size(48, 48),
              ),
              onPressed: _openComposer,
              child: const Text('Create a Canary link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(BuildContext context, CanaryOwnerRecord note) {
    return GlowCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CanaryNoteScreen(noteId: note.noteId),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DateTime.now().isAfter(note.expiresAt)
                  ? CanaryTokens.textDim
                  : CanaryTokens.canary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.preview.isEmpty ? 'Untitled note' : note.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: CanaryTokens.displayFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: CanaryTokens.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${note.copyCount} copies · created ${CanaryUi.clock(note.createdAt)}',
                  style: const TextStyle(
                    fontFamily: CanaryTokens.monoFont,
                    color: CanaryTokens.textDim,
                    fontSize: 14,
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
    );
  }

  Widget _heroCopy(BuildContext context) {
    final reduce = CanaryTokens.reduceMotion(context);

    Widget item(Widget child, int index) {
      if (reduce) return child;
      return child
          .animate(delay: Duration(milliseconds: 60 * index))
          .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(
          const Text(
            'NO SUS × MONAD',
            style: TextStyle(
              color: CanaryTokens.monad,
              fontFamily: CanaryTokens.monoFont,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          0,
        ),
        const SizedBox(height: 12),
        item(
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
          1,
        ),
        const SizedBox(height: 8),
        item(
          const Text(
            'If it leaks, the canary sings.',
            style: TextStyle(
              fontFamily: CanaryTokens.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: CanaryTokens.canary,
            ),
          ),
          2,
        ),
        const SizedBox(height: 12),
        item(
          const Text(
            'Share one link in your group like any other link. Each person who '
            'opens it gets a copy worded a tiny bit differently. If a screenshot '
            'or pasted copy turns up somewhere it should not, NO SUS can tell '
            'which copy it came from.',
            style: TextStyle(
              color: CanaryTokens.textDim,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          3,
        ),
        const SizedBox(height: 24),
        item(
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LiquidCarveButton(
                label: 'Create a Canary link',
                icon: Icons.add,
                onPressed: _openComposer,
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: CanaryTokens.text,
                  side: const BorderSide(color: CanaryTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CanaryTokens.rChip),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => _scrollTo(_howItWorksKey),
                child: const Text('See how it works ↓'),
              ),
            ],
          ),
          4,
        ),
        const SizedBox(height: 16),
        item(
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (kCanaryContract.isNotEmpty)
                const ChainChip(
                  label: 'Contract on Monad',
                  txHash: kCanaryContract,
                  compact: true,
                ),
              const Text(
                '~0.015 MON per reader · final in < 1 s · ',
                style: TextStyle(
                  fontFamily: CanaryTokens.monoFont,
                  fontSize: 16,
                  color: CanaryTokens.textDim,
                ),
              ),
              InkWell(
                onTap: () => _openUrl(kCanaryRepoUrl),
                child: const Text(
                  'open source ↗',
                  style: TextStyle(
                    fontFamily: CanaryTokens.monoFont,
                    fontSize: 16,
                    color: CanaryTokens.canary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          5,
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
    final reduce = CanaryTokens.reduceMotion(context);
    final cards = [
      (
        '1',
        Icons.edit_outlined,
        'Write once',
        'One note. One link for the group. Encrypted locally with AES-256 before upload.',
      ),
      (
        '2',
        Icons.copy_outlined,
        'Everyone gets a unique copy',
        'Tiny wording changes identify each reader without changing meaning.',
      ),
      (
        '3',
        Icons.search,
        'Paste a leak, find the copy',
        'Matching stays 100% on this device. Local fingerprint engine identifies who leaked.',
      ),
    ];

    final children = [
      for (var i = 0; i < cards.length; i++)
        GlowCard(
          margin: EdgeInsets.only(
            bottom: expanded ? 0 : 12,
            right: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CanaryTokens.canary,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cards[i].$1,
                      style: const TextStyle(
                        color: CanaryTokens.onCanary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(cards[i].$2, color: CanaryTokens.canary, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                cards[i].$3,
                style: const TextStyle(
                  fontFamily: CanaryTokens.displayFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: CanaryTokens.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cards[i].$4,
                style: const TextStyle(
                  color: CanaryTokens.textDim,
                  fontSize: 14,
                ),
              ),
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
          Expanded(
            child: reduce
                ? children[i]
                : children[i]
                    .animate(delay: Duration(milliseconds: 60 * i))
                    .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                    .slideY(begin: 0.05, end: 0, duration: 400.ms),
          ),
        ],
      ],
    );
  }
}
