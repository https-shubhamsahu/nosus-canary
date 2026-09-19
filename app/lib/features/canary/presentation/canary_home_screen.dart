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
import 'ui/canary_nav_bar.dart';
import 'ui/chain_chip.dart';
import 'ui/glow_card.dart';
import 'ui/liquid_carve_button.dart';
import 'ui/pixel_canary.dart';
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

  static const double _maxWide = 1360;

  static const _tickerItems = [
    'EVERY OPEN = 1 MONAD TRANSACTION',
    '~0.015 MON PER READER',
    'FINAL IN UNDER 1 SECOND',
    'NO WALLET NEEDED TO READ',
    'LEAK MATCHING STAYS ON YOUR DEVICE',
    'IT CANNOT STOP SCREENSHOTS. IT MAKES THEM TRACEABLE.',
  ];

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontFamily: CanaryTokens.displayFont,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: CanaryTokens.text,
          height: 1.1,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(
          color: CanaryTokens.textDim,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    ],
  );

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
        final pad = expanded ? 48.0 : 20.0;
        final maxW = expanded ? _maxWide : AppBreakpoints.contentMaxCompact;

        Widget contained(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: child,
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            // The hero fills the first screen; the ticker sits on the fold.
            final heroMin = expanded
                ? (constraints.maxHeight - 60).clamp(520.0, 1400.0)
                : 0.0;
            final hero = expanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 11, child: _heroCopy(context)),
                      const SizedBox(width: 72),
                      Expanded(flex: 10, child: _heroStage(context, true)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroCopy(context),
                      const SizedBox(height: 36),
                      _heroStage(context, false),
                    ],
                  );

            return SingleChildScrollView(
              child: Column(
                children: [
                  contained(
                    Container(
                      constraints: BoxConstraints(minHeight: heroMin),
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        vertical: expanded ? 40 : 28,
                      ),
                      child: hero,
                    ),
                  ),
                  const TickerBand(items: _tickerItems),
                  contained(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: expanded ? 88 : 48),
                        Container(
                          key: _howItWorksKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(
                                'How it works',
                                'Three steps. No wallet, no install, no sign-up.',
                              ),
                              if (expanded) ...[
                                const SizedBox(height: 20),
                                const HowItWorksConnector(),
                                const SizedBox(height: 20),
                              ] else
                                const SizedBox(height: 20),
                              _howItWorks(expanded),
                            ],
                          ),
                        ),
                        SizedBox(height: expanded ? 88 : 48),
                        Container(
                          key: _notesKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(
                                'Your Canary notes',
                                'Kept only on this device. Clearing your browser data deletes them.',
                              ),
                              const SizedBox(height: 24),
                              if (_notes.isEmpty)
                                _emptyNotesCard(context)
                              else
                                for (final note in _notes)
                                  _noteCard(context, note),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          CanaryUi.honestyNote,
                          style: TextStyle(
                            color: CanaryTokens.textDim,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        if (kCanaryOnly) ...[
                          const SizedBox(height: 48),
                          const CanaryFooter(),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The demo card with the pixel canary perched on its top edge.
  Widget _heroStage(BuildContext context, bool expanded) {
    final bird = expanded ? 150.0 : 104.0;
    final birdH = bird * 14 / 16;
    // Feet (last 2 of 14 rows) rest on the card's top border.
    final cardTop = birdH - bird * 2 / 16;
    final reduce = CanaryTokens.reduceMotion(context);
    Widget bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      decoration: BoxDecoration(
        color: CanaryTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CanaryTokens.text, width: 2),
        boxShadow: const [
          BoxShadow(color: CanaryTokens.text, offset: Offset(4, 4)),
        ],
      ),
      child: Text(
        'TWEET! I KNOW WHOSE COPY IT IS.',
        style: TextStyle(
          fontFamily: CanaryTokens.monoFont,
          fontSize: expanded ? 24 : 19,
          color: CanaryTokens.text,
          height: 1,
        ),
      ),
    );
    if (!reduce) {
      bubble = bubble
          .animate(delay: 700.ms)
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.85, 0.85), duration: 300.ms, curve: Curves.easeOutBack);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: cardTop),
          child: _demoCard(context),
        ),
        Positioned(
          right: expanded ? 36 : 16,
          top: 0,
          child: PixelCanary(size: bird, sing: true),
        ),
        Positioned(
          right: (expanded ? 36 : 16) + bird + 20,
          top: birdH * 0.18,
          child: bubble,
        ),
      ],
    );
  }

  Widget _emptyNotesCard(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelCanary(size: 72, sing: true),
            const SizedBox(height: 16),
            const Text(
              'No Canary notes yet',
              style: TextStyle(
                fontFamily: CanaryTokens.displayFont,
                fontSize: 24,
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
                    fontSize: 18,
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
    final expanded = AppBreakpoints.isExpanded(context);
    final wide = MediaQuery.sizeOf(context).width >= 1500;

    Widget item(Widget child, int index) {
      if (reduce) return child;
      return child
          .animate(delay: Duration(milliseconds: 70 * index))
          .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.08, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
    }

    const stat = TextStyle(
      fontFamily: CanaryTokens.monoFont,
      fontSize: 22,
      color: CanaryTokens.textDim,
      height: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            decoration: BoxDecoration(
              color: CanaryTokens.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CanaryTokens.text, width: 2),
            ),
            child: const Text(
              'NO SUS  x  MONAD',
              style: TextStyle(
                color: CanaryTokens.text,
                fontFamily: CanaryTokens.monoFont,
                fontSize: 22,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ),
          0,
        ),
        SizedBox(height: expanded ? 28 : 20),
        item(
          Text(
            'Every reader gets their own copy.',
            style: TextStyle(
              fontFamily: CanaryTokens.displayFont,
              fontSize: expanded ? (wide ? 76 : 62) : 38,
              fontWeight: FontWeight.w700,
              color: CanaryTokens.text,
              height: 1.02,
              letterSpacing: expanded ? -2 : -1,
            ),
          ),
          1,
        ),
        SizedBox(height: expanded ? 22 : 16),
        item(
          Text(
            ' If it leaks, the canary sings. ',
            style: TextStyle(
              fontFamily: CanaryTokens.displayFont,
              fontSize: expanded ? 30 : 22,
              fontWeight: FontWeight.w700,
              color: CanaryTokens.text,
              backgroundColor: CanaryTokens.canary,
              height: 1.3,
            ),
          ),
          2,
        ),
        SizedBox(height: expanded ? 24 : 16),
        item(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              'Share one link in your group like any other link. Each person '
              'who opens it gets a copy worded a tiny bit differently. If a '
              'screenshot or pasted copy turns up somewhere it should not, '
              'NO SUS tells you whose copy it was.',
              style: TextStyle(
                color: CanaryTokens.textDim,
                fontSize: expanded ? 19 : 16,
                height: 1.6,
              ),
            ),
          ),
          3,
        ),
        SizedBox(height: expanded ? 36 : 28),
        item(
          Wrap(
            spacing: 18,
            runSpacing: 14,
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
                  backgroundColor: CanaryTokens.surface,
                  side: const BorderSide(color: CanaryTokens.text, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CanaryTokens.rChip),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  minimumSize: const Size(48, 52),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                onPressed: () => _scrollTo(_howItWorksKey),
                child: const Text('See how it works ↓'),
              ),
            ],
          ),
          4,
        ),
        SizedBox(height: expanded ? 32 : 24),
        item(
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (kCanaryContract.isNotEmpty)
                const ChainChip(
                  label: 'Contract on Monad',
                  txHash: kCanaryContract,
                  compact: true,
                ),
              const Text('~0.015 MON / READER', style: stat),
              const Text('FINAL < 1 S', style: stat),
              InkWell(
                onTap: () => _openUrl(kCanaryRepoUrl),
                child: const Text(
                  'OPEN SOURCE ↗',
                  style: TextStyle(
                    fontFamily: CanaryTokens.monoFont,
                    fontSize: 22,
                    height: 1,
                    color: CanaryTokens.text,
                    decoration: TextDecoration.underline,
                    decorationColor: CanaryTokens.canary,
                    decorationThickness: 3,
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
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
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
            bottom: expanded ? 0 : 16,
            right: 0,
          ),
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CanaryTokens.canary,
                      border: Border.all(color: CanaryTokens.text, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cards[i].$1,
                      style: const TextStyle(
                        fontFamily: CanaryTokens.monoFont,
                        color: CanaryTokens.onCanary,
                        fontSize: 26,
                        height: 1,
                      ),
                    ),
                  ),
                  Icon(cards[i].$2, color: CanaryTokens.text, size: 26),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                cards[i].$3,
                style: const TextStyle(
                  fontFamily: CanaryTokens.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: CanaryTokens.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cards[i].$4,
                style: const TextStyle(
                  color: CanaryTokens.textDim,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
    ];

    if (!expanded) {
      return Column(children: children);
    }
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
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
      ),
    );
  }
}
