import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/canary_models.dart';
import 'canary_created_screen.dart';
import 'canary_leak_check_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';

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
    final theme = Theme.of(context);
    final record = _record;
    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This note is not on this device.')),
      );
    }
    final status = _status;
    final opened = status?.copies.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Canary note')),
      body: CanaryUi.page(
        children: [
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
          Text('Link works until ${CanaryUi.clock(record.expiresAt)} '
              '(${record.expiresAt.toLocal().day}/${record.expiresAt.toLocal().month})'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${copy.copyIndex + 1}')),
                title: Text(copy.readerName),
                subtitle: Text(
                  'Copy ${copy.copyIndex + 1} · opened ${CanaryUi.clock(copy.openedAt)}',
                ),
                trailing: copy.openTxHash == null
                    ? const Tooltip(
                        message: 'Recording on Monad…',
                        child: Icon(Icons.hourglass_empty),
                      )
                    : IconButton(
                        tooltip: 'Recorded on Monad testnet — view proof',
                        icon: const Icon(Icons.verified_outlined),
                        onPressed: () =>
                            CanaryUi.openTx(context, copy.openTxHash!),
                      ),
              ),
          const SizedBox(height: 24),
          Text(CanaryUi.honestyNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
