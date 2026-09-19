import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../data/canary_api.dart';
import '../data/canary_repository.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import 'canary_created_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/fingerprint_meter.dart';
import 'ui/glow_card.dart';
import 'ui/liquid_carve_button.dart';
import 'ui/pixel_canary.dart';
import 'ui/quest_steps.dart';

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

    return CanaryUi.frame(
      title: 'New Canary note',
      body: (context) {
        final theme = Theme.of(context);
        final expanded = AppBreakpoints.isExpanded(context);
        final plan = length == 0 ? null : buildCanaryPlan(_text.text.trim());
        final panel = _sidePanel(theme, required, strongEnough, length, plan);

        return LayoutBuilder(
          builder: (context, constraints) {
            // Desktop with enough height: the editor stretches to fill the
            // screen. Otherwise everything scrolls as one column.
            final fill = expanded && constraints.maxHeight >= 700;
            final pad = expanded ? 48.0 : 20.0;

            final header = _header(expanded);

            if (!fill) {
              return ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  header,
                  const SizedBox(height: 24),
                  const QuestSteps(current: 0),
                  const SizedBox(height: 24),
                  _editorCard(theme, expand: false),
                  const SizedBox(height: 24),
                  panel,
                ],
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 32, pad, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 24),
                      const QuestSteps(current: 0),
                      const SizedBox(height: 28),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _editorCard(theme, expand: true)),
                            const SizedBox(width: 32),
                            SizedBox(
                              width: 460,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 8,
                                ),
                                child: panel,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _header(bool expanded) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Write it once.',
                style: TextStyle(
                  fontFamily: CanaryTokens.displayFont,
                  fontSize: expanded ? 52 : 34,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  letterSpacing: expanded ? -1.5 : -0.5,
                  color: CanaryTokens.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Canary swaps tiny everyday words, so every reader gets a copy '
                'that reads the same but is secretly unique.',
                style: TextStyle(
                  fontSize: expanded ? 18 : 16,
                  height: 1.55,
                  color: CanaryTokens.textDim,
                ),
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(width: 24),
          const PixelCanary(size: 96, sing: true),
          const SizedBox(width: 24),
        ],
      ],
    );
  }

  Widget _editorCard(ThemeData theme, {required bool expand}) {
    final field = TextField(
      controller: _text,
      enabled: !_busy,
      minLines: expand ? null : 10,
      maxLines: expand ? null : 18,
      expands: expand,
      textAlignVertical: TextAlignVertical.top,
      maxLength: CanaryRepository.maxNoteLength,
      onChanged: _onTextChanged,
      style: const TextStyle(
        fontFamily: CanaryTokens.bodyFont,
        fontSize: 19,
        color: CanaryTokens.text,
        height: 1.65,
      ),
      cursorColor: CanaryTokens.text,
      cursorWidth: 3,
      decoration: const InputDecoration(
        hintText: 'Write your note the way you normally would…',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
    );

    return GlowCard(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const RetroLabel('Your note'),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: CanaryTokens.text,
                  backgroundColor: CanaryTokens.canary,
                  side: const BorderSide(color: CanaryTokens.text, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: _busy
                    ? null
                    : () {
                        _text.text = kCanaryDemoNote;
                        _onTextChanged(kCanaryDemoNote);
                      },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Use the demo note'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 2, color: CanaryTokens.text),
          const SizedBox(height: 16),
          if (expand) Expanded(child: field) else field,
        ],
      ),
    );
  }

  Widget _sidePanel(
    ThemeData theme,
    int required,
    bool strongEnough,
    int length,
    CanaryPlan? plan,
  ) {
    final ready = length > 0 && strongEnough;
    return GlowCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RetroLabel('Fingerprint'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                decoration: BoxDecoration(
                  color: ready ? CanaryTokens.canary : CanaryTokens.surfaceHi,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CanaryTokens.text, width: 1.5),
                ),
                child: Text(
                  ready ? 'READY' : '$_slots / $required',
                  style: const TextStyle(
                    fontFamily: CanaryTokens.monoFont,
                    fontSize: 20,
                    height: 1,
                    color: CanaryTokens.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FingerprintMeter(found: _slots, requiredSlots: required),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              length == 0
                  ? 'Canary needs at least $required everyday words it can swap '
                        '(like "don\'t", "okay", "until", numbers).'
                  : strongEnough
                  ? '$_slots swappable words found. Enough for $_copies readers.'
                  : 'Found $_slots of the $required swappable words needed for '
                        '$_copies readers. Add a sentence or two.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: length > 0 && !strongEnough
                    ? theme.colorScheme.error
                    : CanaryTokens.textDim,
              ),
            ),
          ),
          if (plan != null && plan.slots.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in plan.slots.take(8))
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                    decoration: BoxDecoration(
                      color: CanaryTokens.surfaceHi,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CanaryTokens.text, width: 1.5),
                    ),
                    child: Text(
                      '${slot.original} / ${slot.alternate}',
                      style: const TextStyle(
                        fontFamily: CanaryTokens.monoFont,
                        color: CanaryTokens.text,
                        fontSize: 19,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const RetroLabel('How many readers?'),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final c in _copyChoices)
                ButtonSegment<int>(
                  value: c,
                  label: Text('$c'),
                  enabled: canaryRequiredSlots(c) <= _slots || length == 0,
                  tooltip: canaryRequiredSlots(c) > _slots && length > 0
                      ? 'Needs ${canaryRequiredSlots(c)} swappable words'
                      : null,
                ),
            ],
            selected: {_copies},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _copies = value.first),
          ),
          const SizedBox(height: 24),
          const RetroLabel('Link works for'),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            showSelectedIcon: false,
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
          const SizedBox(height: 32),
          if (_busy) ...[
            RetroLabel(_stage ?? 'Working…'),
            const SizedBox(height: 12),
          ],
          LiquidCarveButton(
            label: _busy ? (_stage ?? 'Working…') : 'Create Canary link',
            icon: Icons.link,
            busy: _busy,
            onPressed: _busy || !strongEnough ? null : _create,
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
          Container(height: 2, color: CanaryTokens.text.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          const Text(
            'Your note is encrypted on this device. NO SUS stores only the '
            'encrypted copies; the key travels inside the link. Monad testnet '
            'receives only a hash of the copies and an anonymous tag per '
            'reader, never the text or names.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: CanaryTokens.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
