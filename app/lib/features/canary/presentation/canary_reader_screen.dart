import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../../monad/presentation/experiment_frame.dart';
import '../data/canary_api.dart';
import '../domain/canary_models.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/canary_mark.dart';
import 'ui/chain_chip.dart';
import 'ui/glow_card.dart';

/// Standalone app for the web reader path (main.dart runs it directly for
/// `#/canary/<id>?k=...` links, like the Burn viewers).
class CanaryReaderApp extends StatelessWidget {
  const CanaryReaderApp({super.key, required this.noteId, required this.keyHex});

  final String noteId;
  final String keyHex;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NO SUS',
    debugShowCheckedModeBanner: false,
    theme: CanaryTokens.theme(),
    darkTheme: CanaryTokens.theme(),
    themeMode: ThemeMode.dark,
    builder: (context, child) =>
        ExperimentFrame(child: child ?? const SizedBox.shrink()),
    home: CanaryReaderScreen(noteId: noteId, keyHex: keyHex),
  );
}

/// What a reader sees: type a name, get their own numbered copy.
class CanaryReaderScreen extends ConsumerStatefulWidget {
  const CanaryReaderScreen({
    super.key,
    required this.noteId,
    required this.keyHex,
  });

  final String noteId;
  final String keyHex;

  @override
  ConsumerState<CanaryReaderScreen> createState() => _CanaryReaderScreenState();
}

class _CanaryReaderScreenState extends ConsumerState<CanaryReaderScreen> {
  final _name = TextEditingController();
  CanaryOpenedCopy? _copy;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(canaryRepositoryProvider).lastReaderName() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final copy = await ref.read(canaryRepositoryProvider).openCopy(
        noteId: widget.noteId,
        keyHex: widget.keyHex,
        readerName: _name.text,
      );
      if (mounted) setState(() => _copy = copy);
    } on CanaryUserException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on CanaryApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the note: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    return CanaryUi.scaffold(
      title: CanaryUi.featureName,
      builder: (context) => copy == null ? _gate(context) : _copyView(context, copy),
    );
  }

  List<Widget> _gate(BuildContext context) {
    final theme = Theme.of(context);
    return [
      const Center(child: CanaryMark(size: 64)),
      const SizedBox(height: 16),
      Text(
        'Someone shared a private note with you.',
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Every reader gets their own numbered copy. Type your name to open yours.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _name,
        enabled: !_busy,
        maxLength: 40,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _busy ? null : _open(),
        decoration: const InputDecoration(
          labelText: 'Your name',
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CanaryTokens.onCanary,
                ),
              )
            : const Icon(Icons.lock_open),
        label: Text(_busy ? 'Making your copy…' : 'Open my copy'),
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
        'The sender sees your name and when you opened your copy. Monad testnet '
        'records that a copy was opened, without your name.',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _copyView(BuildContext context, CanaryOpenedCopy copy) {
    final theme = Theme.of(context);
    return [
      GlowCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Copy ${copy.copyIndex + 1} of ${copy.copyCount} · made for ${copy.readerName}',
          style: theme.textTheme.titleSmall,
        ),
      ),
      const SizedBox(height: 16),
      SelectableText(copy.text, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 20),
      Text(
        'This copy is unique to you. If it gets shared, NO SUS can tell it was '
        'this copy.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      if (copy.openTxHash == null)
        Text(
          'Recorded on Monad testnet at ${CanaryUi.clock(copy.openedAt)}',
          style: const TextStyle(fontFamily: CanaryTokens.monoFont),
        )
      else
        Align(
          alignment: Alignment.centerLeft,
          child: ChainChip(
            label: 'Recorded on Monad',
            txHash: copy.openTxHash,
          ),
        ),
    ];
  }
}
