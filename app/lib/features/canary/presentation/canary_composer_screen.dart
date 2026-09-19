import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../data/canary_api.dart';
import '../data/canary_repository.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import 'canary_created_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';

/// A demo note that has 15 swappable words (checked by the test harness), so
/// it supports up to 100 readers.
const String kCanaryDemoNote =
    "Hi everyone, please don't forward this. We're finalizing the budget and it's nearly done. "
    'The first ten people who reply can join the review, so kindly keep it quiet until Monday. '
    "I'll organize a short call afterwards for anybody who can't read the whole email. "
    'Someone from finance will share the favorite options, okay? '
    "Let's make sure nobody posts screenshots, and maybe we can wrap up by five. "
    "There's a lot riding on this, so don't be late.";

class CanaryComposerScreen extends ConsumerStatefulWidget {
  const CanaryComposerScreen({super.key});

  @override
  ConsumerState<CanaryComposerScreen> createState() =>
      _CanaryComposerScreenState();
}

class _CanaryComposerScreenState extends ConsumerState<CanaryComposerScreen> {
  final _text = TextEditingController();
  int _copies = 50;
  int _hours = 24;
  int _slots = 0;
  bool _busy = false;
  String? _stage;
  String? _error;

  static const _copyChoices = [10, 20, 50, 100];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final slots = value.trim().isEmpty ? 0 : buildCanaryPlan(value.trim()).bitCount;
    setState(() {
      _slots = slots;
      _error = null;
      // Drop to the largest reader count this text supports.
      if (canaryRequiredSlots(_copies) > slots) {
        _copies = _copyChoices.lastWhere(
          (c) => canaryRequiredSlots(c) <= slots,
          orElse: () => _copies,
        );
      }
    });
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
      _stage = 'Starting…';
    });
    try {
      final record = await ref.read(canaryRepositoryProvider).createNote(
        text: _text.text,
        copyCount: _copies,
        expiresInHours: _hours,
        onStage: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CanaryCreatedScreen(noteId: record.noteId),
        ),
      );
    } on CanaryUserException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on CanaryApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create the note: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final required = canaryRequiredSlots(_copies);
    final strongEnough = _slots >= required;
    final length = _text.text.trim().length;

    return CanaryUi.scaffold(
      title: 'New Canary note',
      builder: (context) {
        final theme = Theme.of(context);
        return [
          TextField(
            controller: _text,
            enabled: !_busy,
            minLines: 6,
            maxLines: 14,
            maxLength: CanaryRepository.maxNoteLength,
            onChanged: _onTextChanged,
            decoration: const InputDecoration(
              labelText: 'Your note',
              hintText: 'Write it the way you normally would.',
              alignLabelWithHint: true,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      _text.text = kCanaryDemoNote;
                      _onTextChanged(kCanaryDemoNote);
                    },
              child: const Text('Use the demo note'),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              length == 0
                  ? 'Canary needs at least $required everyday words it can swap '
                        '(like "don\'t", "okay", "until", numbers).'
                  : strongEnough
                  ? 'Fingerprint strength: $_slots swappable words '
                        '(needs $required for $_copies readers)'
                  : 'Found $_slots of the $required swappable words needed for '
                        '$_copies readers. Add a sentence or two.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: length > 0 && !strongEnough
                    ? theme.colorScheme.error
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('How many readers?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final c in _copyChoices)
                ButtonSegment<int>(
                  value: c,
                  label: Text('$c'),
                  enabled: canaryRequiredSlots(c) <= _slots || length == 0,
                ),
            ],
            selected: {_copies},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _copies = value.first),
          ),
          const SizedBox(height: 20),
          Text('Link works for', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 1, label: Text('1 hour')),
              ButtonSegment<int>(value: 24, label: Text('1 day')),
              ButtonSegment<int>(value: 168, label: Text('7 days')),
            ],
            selected: {_hours},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _hours = value.first),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _busy || !strongEnough ? null : _create,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CanaryTokens.onCanary,
                    ),
                  )
                : const Icon(Icons.link),
            label: Text(_busy ? (_stage ?? 'Working…') : 'Create Canary link'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Your note is encrypted on this device. NO SUS stores only the '
            'encrypted copies; the key travels inside the link. Monad testnet '
            'receives only a hash of the copies and an anonymous tag per '
            'reader, never the text or names.',
            style: theme.textTheme.bodySmall,
          ),
        ];
      },
    );
  }
}
