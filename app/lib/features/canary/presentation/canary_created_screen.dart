import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../domain/canary_models.dart';
import 'canary_note_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/chain_chip.dart';
import 'ui/glow_card.dart';
import 'ui/swap_word_text.dart';

/// Shown right after creating a note, and from the dashboard's "Show QR".
class CanaryCreatedScreen extends ConsumerStatefulWidget {
  const CanaryCreatedScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<CanaryCreatedScreen> createState() =>
      _CanaryCreatedScreenState();
}

class _CanaryCreatedScreenState extends ConsumerState<CanaryCreatedScreen> {
  Timer? _poll;
  CanaryNoteStatus? _status;
  bool _copied = false;
  bool _present = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final record = ref.read(canaryRepositoryProvider).findNote(widget.noteId);
    if (record == null) return;
    try {
      final status = await ref
          .read(canaryRepositoryProvider)
          .fetchStatus(record);
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // The QR still works without a live open count.
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Canary link copied')),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.read(canaryRepositoryProvider).findNote(widget.noteId);
    if (record == null) {
      return CanaryUi.missing(message: 'This note is not on this device.');
    }

    if (_present) {
      return _PresentMode(
        record: record,
        opened: _status?.copies.length ?? 0,
        onClose: () => setState(() => _present = false),
      );
    }

    return CanaryUi.frame(
      title: 'Your Canary link',
      actions: [
        IconButton(
          tooltip: 'Present',
          icon: const Icon(Icons.present_to_all),
          onPressed: () => setState(() => _present = true),
        ),
      ],
      body: (context) {
        final expanded = AppBreakpoints.isExpanded(context);
        final pad = expanded ? 32.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: expanded ? _desktop(context, record) : _phone(context, record),
        );
      },
    );
  }

  Widget _desktop(BuildContext context, CanaryOwnerRecord record) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FloatingQr(data: record.readerLink, size: 320),
        const SizedBox(width: 28),
        Expanded(child: _middle(context, record)),
        const SizedBox(width: 28),
        Expanded(child: _magic(context, record, open: true)),
      ],
    );
  }

  Widget _phone(BuildContext context, CanaryOwnerRecord record) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share this one link with the group.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Each person who opens it gets their own copy '
          '(${record.copyCount} copies available).',
        ),
        const SizedBox(height: 20),
        Center(child: _FloatingQr(data: record.readerLink, size: 260)),
        const SizedBox(height: 20),
        _middle(context, record),
        const SizedBox(height: 24),
        _magic(context, record, open: false),
      ],
    );
  }

  Widget _middle(BuildContext context, CanaryOwnerRecord record) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (AppBreakpoints.isExpanded(context)) ...[
          Text(
            'Share this one link with the group.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Each person who opens it gets their own copy '
            '(${record.copyCount} copies available).',
          ),
          const SizedBox(height: 16),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CanaryTokens.surfaceHi,
            borderRadius: BorderRadius.circular(CanaryTokens.rChip),
            border: Border.all(color: CanaryTokens.border),
          ),
          child: SelectableText(
            record.readerLink,
            style: const TextStyle(
              fontFamily: CanaryTokens.monoFont,
              color: CanaryTokens.textDim,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              icon: Icon(_copied ? Icons.check : Icons.copy),
              label: Text(_copied ? 'Copied' : 'Copy link'),
              onPressed: () => _copyLink(record.readerLink),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: 'A private note for the group (your copy is yours '
                      'only): ${record.readerLink}',
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Who opened it'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CanaryNoteScreen(noteId: record.noteId),
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.present_to_all),
              label: const Text('Present'),
              onPressed: () => setState(() => _present = true),
            ),
          ],
        ),
        if (record.sealTxHash != null) ...[
          const SizedBox(height: 12),
          ChainChip(
            label: 'Sealed on Monad',
            txHash: record.sealTxHash,
          ),
        ],
      ],
    );
  }

  Widget _magic(
    BuildContext context,
    CanaryOwnerRecord record, {
    required bool open,
  }) {
    final n = record.copyCount < 3 ? record.copyCount : 3;
    final words = [for (var i = 0; i < n; i++) record.codewords[i]];
    final labels = [for (var i = 0; i < n; i++) 'Copy ${i + 1}'];
    final body = SwapWordText(
      plan: record.plan,
      codewords: words,
      labels: labels,
    );

    if (open) {
      return GlowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'See the magic',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('The same note, as different readers get it'),
            const SizedBox(height: 12),
            body,
          ],
        ),
      );
    }

    return GlowCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        title: Text(
          'See the magic',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: const Text(
          'The same note, as three different readers get it',
        ),
        children: [body],
      ),
    );
  }
}

class _FloatingQr extends StatefulWidget {
  const _FloatingQr({required this.data, required this.size});

  final String data;
  final double size;

  @override
  State<_FloatingQr> createState() => _FloatingQrState();
}

class _FloatingQrState extends State<_FloatingQr>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanaryTokens.reduceMotion(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final y = CanaryTokens.reduceMotion(context)
            ? 0.0
            : math.sin(_c.value * math.pi * 2) * 4;
        return Transform.translate(offset: Offset(0, y), child: child);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CanaryTokens.rCard),
          border: Border.all(color: CanaryTokens.canary, width: 3),
          boxShadow: CanaryTokens.glow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: QrImageView(
            data: widget.data,
            version: QrVersions.auto,
            size: widget.size,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PresentMode extends StatelessWidget {
  const _PresentMode({
    required this.record,
    required this.opened,
    required this.onClose,
  });

  final CanaryOwnerRecord record;
  final int opened;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CanaryTokens.theme(),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): onClose,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final qr = math.min(
                          math.min(constraints.maxWidth, constraints.maxHeight) *
                              0.62,
                          480.0,
                        );
                        return Column(
                          children: [
                            const SizedBox(height: 24),
                            Text(
                              record.preview.isEmpty
                                  ? 'NO SUS Canary'
                                  : record.preview,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: CanaryTokens.displayFont,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$opened / ${record.copyCount} opened',
                              style: const TextStyle(
                                fontFamily: CanaryTokens.monoFont,
                                fontSize: 22,
                                color: CanaryTokens.canary,
                              ),
                            ),
                            const Spacer(),
                            Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    CanaryTokens.rCard,
                                  ),
                                  border: Border.all(
                                    color: CanaryTokens.canary,
                                    width: 3,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: QrImageView(
                                    data: record.readerLink,
                                    version: QrVersions.auto,
                                    size: qr,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 72),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Close present mode',
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
