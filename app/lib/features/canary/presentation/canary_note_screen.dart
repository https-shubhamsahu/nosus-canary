import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_mode.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../data/canary_api.dart';
import '../domain/canary_link.dart';
import '../domain/canary_models.dart';
import 'canary_created_screen.dart';
import 'canary_leak_check_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/glow_card.dart';
import 'ui/proof_chips.dart';
import 'ui/wallet_button.dart';

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
      final status = await ref
          .read(canaryRepositoryProvider)
          .fetchStatus(record);
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
      if (status.isSettled) _poll?.cancel();
    } on CanaryApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load who opened it.');
    } finally {
      _loading = false;
    }
  }

  Future<void> _openSolanaSeal(String signature) async {
    final ok = await launchUrl(
      Uri.parse(canarySolanaExplorerTxUrl(signature)),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the explorer.')),
      );
    }
  }

  /// Solana is on for this note when its seal landed there; an open with no
  /// signature yet is then "still being written" for a short while.
  bool _solanaPending(CanaryNoteStatus status, CanaryCopyStatus copy) =>
      status.sealSolanaSig != null &&
      copy.openSolanaSig == null &&
      DateTime.now().difference(copy.openedAt) < const Duration(minutes: 2);

  @override
  Widget build(BuildContext context) {
    final record = _record;
    if (record == null) {
      return CanaryUi.missing(message: 'This note is not on this device.');
    }
    final status = _status;
    final opened = status?.copies.length ?? 0;

    return CanaryUi.frame(
      title: 'Canary note',
      body: (context) {
        final theme = Theme.of(context);
        final expanded = AppBreakpoints.isExpanded(context);
        final pad = expanded ? 32.0 : 20.0;
        final left = _leftColumn(
          context,
          theme,
          record,
          status,
          opened,
          expanded,
        );
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
                    GlowCard(child: CanaryLeakPanel(noteId: record.noteId)),
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
          if (kCanaryMonad)
            VerifyOnMonadButton(
              noteId: record.noteId,
              localOpened: status?.copies.length,
            ),
          if (status?.sealSolanaSig case final sig?)
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text(
                'Verify on Solana ↗',
                semanticsLabel: 'Verify on Solana. Opens the seal on '
                    'Solana devnet in the explorer.',
              ),
              onPressed: () => _openSolanaSeal(sig),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 8),
                      // Below the name, not beside it: two chips need the
                      // card's full width to wrap on a phone.
                      ProofChips(
                        monadTxHash: copy.openTxHash,
                        solanaSig: copy.openSolanaSig,
                        monadPending: copy.openTxHash == null,
                        solanaPending: _solanaPending(status, copy),
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    ];
  }
}
