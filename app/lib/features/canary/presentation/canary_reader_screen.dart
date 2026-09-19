import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../../monad/presentation/experiment_frame.dart';
import '../data/canary_api.dart';
import '../domain/canary_models.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/canary_envelope.dart';
import 'ui/chain_chip.dart';
import 'ui/copy_badge.dart';
import 'ui/glow_card.dart';
import 'ui/liquid_carve_button.dart';

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
  final _nameFocus = FocusNode();
  CanaryOpenedCopy? _copy;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(canaryRepositoryProvider).lastReaderName() ?? '';
    _nameFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
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
    return CanaryUi.frame(
      title: CanaryUi.featureName,
      body: (context) => _layout(context, _card(context)),
    );
  }

  Widget _layout(BuildContext context, Widget card) {
    final expanded = AppBreakpoints.isExpanded(context);
    if (!expanded) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [card],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(flex: 2, child: _BrandSide()),
          const SizedBox(width: 32),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: card,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final copy = _copy;
    if (copy == null && !_busy) return _gate(context);
    return CanaryFlipCard(
      showBack: copy != null,
      front: const CanaryEnvelope(),
      back: copy == null ? const CanaryEnvelope() : _copyView(context, copy),
    );
  }

  Widget _gate(BuildContext context) {
    final theme = Theme.of(context);
    final focused = _nameFocus.hasFocus;
    return GlowCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BobbingCanaryMark(size: 64)),
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
          AnimatedContainer(
            duration: CanaryTokens.reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CanaryTokens.rCard),
              boxShadow: focused ? CanaryTokens.glow : null,
            ),
            child: TextField(
              controller: _name,
              focusNode: _nameFocus,
              enabled: !_busy,
              maxLength: 40,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _busy ? null : _open(),
              decoration: const InputDecoration(
                labelText: 'Your name',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: LiquidCarveButton(
              label: 'Open my copy',
              icon: Icons.lock_open,
              busy: _busy,
              onPressed: _busy ? null : _open,
            ),
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
        ],
      ),
    );
  }

  Widget _copyView(BuildContext context, CanaryOpenedCopy copy) {
    final theme = Theme.of(context);
    return GlowCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CopyBadge(
            copyIndex: copy.copyIndex,
            copyCount: copy.copyCount,
            readerName: copy.readerName,
          ),
          const SizedBox(height: 16),
          SelectableText(copy.text, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Text(
            'This copy is unique to you. If it gets shared, NO SUS can tell it was '
            'this copy.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          DelayedFadeIn(
            delay: const Duration(milliseconds: 450),
            child: copy.openTxHash == null
                ? Text(
                    'Recorded on Monad testnet at ${CanaryUi.clock(copy.openedAt)}',
                    style: const TextStyle(fontFamily: CanaryTokens.monoFont),
                  )
                : ChainChip(
                    label: 'Recorded on Monad',
                    txHash: copy.openTxHash,
                  ),
          ),
        ],
      ),
    );
  }
}

class _BrandSide extends StatelessWidget {
  const _BrandSide();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BobbingCanaryMark(size: 160),
        SizedBox(height: 20),
        Text(
          'NO SUS',
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: CanaryTokens.text,
          ),
        ),
        Text(
          '× MONAD',
          style: TextStyle(
            fontFamily: CanaryTokens.monoFont,
            fontSize: 22,
            color: CanaryTokens.monad,
            letterSpacing: 1.4,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'A unique copy, recorded on testnet.',
          style: TextStyle(color: CanaryTokens.textDim),
        ),
      ],
    );
  }
}
