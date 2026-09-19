import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import '../ocr/canary_ocr.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/canary_confetti.dart';
import 'ui/canary_reveal.dart';
import 'ui/glow_card.dart';
import 'ui/liquid_carve_button.dart';

/// Paste a leaked text (or read a screenshot on Android) and find the copy.
/// Matching runs on this device; the leak is never uploaded.
class CanaryLeakCheckScreen extends StatelessWidget {
  const CanaryLeakCheckScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return CanaryUi.scaffold(
      title: 'Check a leak',
      builder: (context) => [
        CanaryLeakPanel(noteId: noteId, showHonesty: true),
      ],
    );
  }
}

/// Leak-check controls. Used as a full page and as the desktop dashboard panel.
class CanaryLeakPanel extends ConsumerStatefulWidget {
  const CanaryLeakPanel({
    super.key,
    required this.noteId,
    this.showHonesty = false,
  });

  final String noteId;
  final bool showHonesty;

  @override
  ConsumerState<CanaryLeakPanel> createState() => _CanaryLeakPanelState();
}

class _CanaryLeakPanelState extends ConsumerState<CanaryLeakPanel> {
  final _leak = TextEditingController();
  CanaryMatch? _match;
  CanaryNoteStatus? _status;
  bool _busy = false;
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _leak.dispose();
    super.dispose();
  }

  Future<void> _readScreenshot() async {
    setState(() => _error = null);
    try {
      final text = await canaryPickScreenshotText();
      if (text == null) return;
      if (text.trim().isEmpty) {
        setState(() => _error = 'No text found in that picture.');
        return;
      }
      _leak.text = text;
      await _check();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not read that picture: $e');
    }
  }

  Future<void> _check() async {
    final repository = ref.read(canaryRepositoryProvider);
    final record = repository.findNote(widget.noteId);
    if (record == null) {
      setState(() => _error = 'This note is not on this device.');
      return;
    }
    final match = repository.checkLeak(record, _leak.text);
    setState(() {
      _busy = true;
      _scanning = true;
      _error = null;
      _match = null;
    });
    final statusFuture = repository.fetchStatus(record);
    if (!CanaryTokens.reduceMotion(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    CanaryNoteStatus? status;
    try {
      status = await statusFuture;
    } catch (_) {
      // Names are a bonus; the copy number alone is still useful.
    }
    if (!mounted) return;
    setState(() {
      _match = match;
      _status = status;
      _busy = false;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = ref.read(canaryRepositoryProvider).findNote(widget.noteId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paste the text that leaked — from a forward, a post, or a '
          'screenshot. Even part of it helps.',
        ),
        const SizedBox(height: 12),
        LeakScanOverlay(
          active: _scanning,
          child: TextField(
            controller: _leak,
            minLines: 5,
            maxLines: 12,
            style: const TextStyle(
              fontFamily: CanaryTokens.monoFont,
              fontSize: 16,
              color: CanaryTokens.text,
            ),
            decoration: const InputDecoration(
              labelText: 'Leaked text',
              alignLabelWithHint: true,
            ),
          ),
        ),
        if (record != null && (_scanning || _match != null)) ...[
          const SizedBox(height: 12),
          ScanHitChips(
            plan: record.plan,
            leak: _leak.text,
            active: _scanning,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LiquidCarveButton(
              label: 'Find the copy',
              icon: Icons.search,
              busy: _busy,
              onPressed: _busy ? null : _check,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste'),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) _leak.text = data!.text!;
              },
            ),
            if (canaryOcrAvailable)
              OutlinedButton.icon(
                icon: const Icon(Icons.image_search),
                label: const Text('Read a screenshot'),
                onPressed: _busy ? null : _readScreenshot,
              ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_match != null) ...[
          const SizedBox(height: 20),
          _ResultCard(match: _match!, status: _status),
        ],
        if (widget.showHonesty) ...[
          const SizedBox(height: 24),
          const Text(CanaryUi.honestyNote),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.match, required this.status});

  final CanaryMatch match;
  final CanaryNoteStatus? status;

  @override
  Widget build(BuildContext context) {
    final reveal = match.kind == CanaryMatchKind.exactMarker ||
        match.kind == CanaryMatchKind.confident ||
        match.kind == CanaryMatchKind.likely;
    final celebrate = match.kind == CanaryMatchKind.exactMarker ||
        match.kind == CanaryMatchKind.confident;

    if (reveal) {
      final revealCard = CanaryReveal(
        match: match,
        status: status,
        likely: match.kind == CanaryMatchKind.likely,
      );
      if (!celebrate) return revealCard;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          revealCard,
          const Positioned.fill(child: CanaryConfetti()),
        ],
      );
    }

    final (String headline, String detail) = switch (match.kind) {
      CanaryMatchKind.senderOriginal => (
        'This is your own original text',
        'It matches the version on this device, not any reader\'s copy.',
      ),
      CanaryMatchKind.ambiguous => (
        'Could be copies ${match.candidates.map((i) => '#${i + 1}').join(', ')}',
        'Paste more of the leak to narrow it down.',
      ),
      CanaryMatchKind.notEnough => (
        'Not enough of the note to tell',
        'Paste more of the leaked text.',
      ),
      CanaryMatchKind.noMatch => (
        'No single copy matches',
        'The text may have been edited, or mixed from more than one copy. '
            'Canary will not name anyone in this case.',
      ),
      _ => ('', ''),
    };

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              headline,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail),
        ],
      ),
    );
  }
}
