import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/canary_fingerprint.dart';
import '../domain/canary_models.dart';
import 'canary_note_screen.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';

/// Shown right after creating a note, and from the dashboard's "Show QR".
class CanaryCreatedScreen extends ConsumerWidget {
  const CanaryCreatedScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.read(canaryRepositoryProvider).findNote(noteId);
    final theme = Theme.of(context);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This note is not on this device.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Canary link')),
      body: CanaryUi.page(
        children: [
          Text(
            'Share this one link with the group.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Each person who opens it gets their own copy '
            '(${record.copyCount} copies available).',
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: record.readerLink,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(record.readerLink, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: record.readerLink),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Canary link copied')),
                    );
                  }
                },
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
            ],
          ),
          if (record.sealTxHash != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Sealed on Monad testnet · view proof'),
                onPressed: () => CanaryUi.openTx(context, record.sealTxHash!),
              ),
            ),
          ],
          const Divider(height: 40),
          _MagicView(record: record),
        ],
      ),
    );
  }
}

/// "See the magic": three copies with the swapped words highlighted.
class _MagicView extends StatelessWidget {
  const _MagicView({required this.record});

  final CanaryOwnerRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    final highlight = base.copyWith(
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );
    final shown = record.copyCount < 3 ? record.copyCount : 3;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('See the magic', style: theme.textTheme.titleMedium),
      subtitle: const Text('The same note, as three different readers get it'),
      children: [
        for (var i = 0; i < shown; i++) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Copy ${i + 1}', style: theme.textTheme.labelLarge),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (_) {
              final tokens = renderCanaryTokens(record.plan, record.codewords[i]);
              return Text.rich(
                TextSpan(
                  children: [
                    for (var t = 0; t < tokens.length; t++)
                      TextSpan(
                        text: tokens[t],
                        style: tokens[t] == record.plan.tokens[t] ? base : highlight,
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
