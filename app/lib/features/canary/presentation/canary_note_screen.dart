import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../domain/canary_models.dart';
import 'canary_created_screen.dart';
import 'canary_leak_check_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/chain_chip.dart';
import 'ui/glow_card.dart';

/// Owner dashboard: live "Seen by" list plus the leak check.
class CanaryNoteScreen extends ConsumerStatefulWidget {
  const CanaryNoteScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<CanaryNoteScreen> createState() => _CanaryNoteScreenState();
}

class _CanaryNoteScreenState extends ConsumerState<CanaryNoteScreen> {
  CanaryOwnerRecord? _record;
  CanaryNoteStatus? _status;
  String? _error;
  Timer? _poll;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _record = ref.read(canaryRepositoryProvider).findNote(widget.noteId);
    if (_record != null) {
      _refresh();
      // Polling (not Realtime) on purpose: simplest thing that works on
      // every network, and a 3 s delay is fine for a "Seen by" list.
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final record = _record;
    if (record == null || _loading) return;
    _loading = true;
    try {
      final status = await ref.read(canaryRepositoryProvider).fetchStatus(record);
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    if (record == null) {
      return CanaryUi.missing(
        message: 'This note is not on this device.',
      );
    }
    final status = _status;
    final opened = status?.copies.length ?? 0;

    return CanaryUi.frame(
      title: 'Canary note',
      body: (context) {
        final theme = Theme.of(context);
        final expanded = AppBreakpoints.isExpanded(context);
        final pad = expanded ? 32.0 : 20.0;
        final left = _leftColumn(context, theme, record, status, opened, expanded);
        if (!expanded) {
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              ...left,
              const SizedBox(height: 24),
              const Text(CanaryUi.honestyNote),
            ],
          );
        }
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: ListView(
                  children: [
                    ...left,
                    const SizedBox(height: 24),
                    const Text(CanaryUi.honestyNote),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: ListView(
                  children: [
                    Text('Check a leak', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    GlowCard(
                      child: CanaryLeakPanel(noteId: record.noteId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _leftColumn(
    BuildContext context,
    ThemeData theme,
    CanaryOwnerRecord record,
    CanaryNoteStatus? status,
    int opened,
    bool expanded,
  ) {
    return [
      Text(record.preview, style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Semantics(
        liveRegion: true,
        child: Text(
          status == null
              ? 'Checking who opened it…'
              : '$opened of ${record.copyCount} copies opened',
          style: theme.textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Link works until ${CanaryUi.clock(record.expiresAt)} '
        '(${record.expiresAt.toLocal().day}/${record.expiresAt.toLocal().month})',
        style: const TextStyle(fontFamily: CanaryTokens.monoFont),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (!expanded)
            FilledButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Check a leak'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CanaryLeakCheckScreen(noteId: record.noteId),
                ),
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code),
            label: const Text('Show link & QR'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CanaryCreatedScreen(noteId: record.noteId),
              ),
            ),
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
      const Divider(height: 36),
      Text('Seen by', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (status != null && status.copies.isEmpty)
        const Text('Nobody has opened it yet.'),
      if (status != null)
        for (final copy in status.copies)
          GlowCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: CanaryTokens.surfaceHi,
                  foregroundColor: CanaryTokens.canary,
                  child: Text('${copy.copyIndex + 1}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.readerName, style: theme.textTheme.titleSmall),
                      Text(
                        'Copy ${copy.copyIndex + 1} · opened ${CanaryUi.clock(copy.openedAt)}',
                        style: const TextStyle(
                          fontFamily: CanaryTokens.monoFont,
                          color: CanaryTokens.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                if (copy.openTxHash == null)
                  const Tooltip(
                    message: 'Recording on Monad…',
                    child: Icon(
                      Icons.hourglass_empty,
                      color: CanaryTokens.monad,
                    ),
                  )
                else
                  Flexible(
                    child: ChainChip(
                      label: 'Monad',
                      txHash: copy.openTxHash,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
    ];
  }
}
