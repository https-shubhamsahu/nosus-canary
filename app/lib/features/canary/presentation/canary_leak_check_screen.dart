import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import '../ocr/canary_ocr.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/canary_mark.dart';
import 'ui/chain_chip.dart';
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
    setState(() {
      _busy = true;
      _error = null;
      _match = repository.checkLeak(record, _leak.text);
    });
    try {
      final status = await repository.fetchStatus(record);
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Names are a bonus; the copy number alone is still useful.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paste the text that leaked — from a forward, a post, or a '
          'screenshot. Even part of it helps.',
        ),
        const SizedBox(height: 12),
        TextField(
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
    final theme = Theme.of(context);
    final index = match.copyIndex;
    final copy = index == null ? null : status?.copy(index);
    final String who;
    if (index == null) {
      who = '';
    } else if (copy == null) {
      who = 'Copy #${index + 1}';
    } else {
      who = 'Copy #${index + 1} — ${copy.readerName}';
    }

    final sang = match.kind == CanaryMatchKind.exactMarker ||
        match.kind == CanaryMatchKind.confident ||
        match.kind == CanaryMatchKind.likely;

    final (String headline, String detail) = switch (match.kind) {
      CanaryMatchKind.exactMarker => (
        'The canary sang. $who',
        'Matched by the hidden marker in the text.',
      ),
      CanaryMatchKind.confident => (
        'The canary sang. $who',
        '${match.agreeing} of ${match.known} fingerprints match.',
      ),
      CanaryMatchKind.likely => (
        'Most likely $who',
        '${match.agreeing} of ${match.known} fingerprints match. Treat this '
            'as a strong hint, not proof.',
      ),
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
    };

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sang) ...[
            const CanaryMark(size: 48),
            const SizedBox(height: 12),
          ],
          Semantics(
            liveRegion: true,
            child: Text(headline, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(detail),
          if (copy != null) ...[
            const SizedBox(height: 8),
            Text(
              'Opened ${CanaryUi.clock(copy.openedAt)}',
              style: const TextStyle(fontFamily: CanaryTokens.monoFont),
            ),
            if (copy.openTxHash != null) ...[
              const SizedBox(height: 8),
              ChainChip(
                label: 'Proof on Monad',
                txHash: copy.openTxHash,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
