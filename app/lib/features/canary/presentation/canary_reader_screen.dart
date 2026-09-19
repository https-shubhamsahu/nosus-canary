import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../theme.dart';
import '../data/canary_api.dart';
import '../domain/canary_models.dart';
import 'canary_providers.dart';
import 'canary_ui.dart';
import 'ui/canary_envelope.dart';
import 'ui/chain_chip.dart';
import 'ui/copy_badge.dart';
import 'ui/glow_card.dart';
import 'ui/liquid_carve_button.dart';
import 'ui/pixel_canary.dart';
import 'ui/canary_strip.dart';

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
        CanaryStrip(child: child ?? const SizedBox.shrink()),
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const Center(child: PixelCanary(size: 96, sing: true)),
          const SizedBox(height: 20),
          card,
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(flex: 9, child: _BrandSide()),
                    const SizedBox(width: 72),
                    Expanded(
                      flex: 10,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: card,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final expanded = AppBreakpoints.isExpanded(context);
    return GlowCard(
      padding: EdgeInsets.all(expanded ? 36 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 3),
              decoration: BoxDecoration(
                color: CanaryTokens.canary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CanaryTokens.text, width: 2),
              ),
              child: const Text(
                'PRIVATE NOTE',
                style: TextStyle(
                  fontFamily: CanaryTokens.monoFont,
                  fontSize: 22,
                  letterSpacing: 2,
                  height: 1,
                  color: CanaryTokens.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Someone shared a private note with you.',
            style: TextStyle(
              fontFamily: CanaryTokens.displayFont,
              fontSize: expanded ? 38 : 28,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.8,
              color: CanaryTokens.text,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Every reader gets their own numbered copy. Type your name to open '
            'yours.',
            style: TextStyle(
              fontSize: 17,
              height: 1.55,
              color: CanaryTokens.textDim,
            ),
          ),
          const SizedBox(height: 28),
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
              style: const TextStyle(fontSize: 18, color: CanaryTokens.text),
              decoration: const InputDecoration(
                labelText: 'Your name',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
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
          const SizedBox(height: 28),
          Container(height: 2, color: CanaryTokens.text.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          const Text(
            'The sender sees your name and when you opened your copy. Monad '
            'testnet records that a copy was opened, without your name.',
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: CanaryTokens.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyView(BuildContext context, CanaryOpenedCopy copy) {
    final theme = Theme.of(context);
    return GlowCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CopyBadge(
            copyIndex: copy.copyIndex,
            copyCount: copy.copyCount,
            readerName: copy.readerName,
          ),
          const SizedBox(height: 24),
          SelectableText(
            copy.text,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 19, height: 1.7),
          ),
          const SizedBox(height: 24),
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

  static const _facts = [
    'YOUR COPY IS UNIQUE TO YOU',
    'OPENING IT = 1 MONAD TRANSACTION',
    'NO WALLET, NO APP, NO SIGN-UP',
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelCanary(size: wide ? 220 : 180, sing: true),
        const SizedBox(height: 32),
        Text(
          'NO SUS',
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontSize: wide ? 88 : 72,
            fontWeight: FontWeight.w700,
            height: 0.95,
            letterSpacing: -2,
            color: CanaryTokens.text,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          ' Your own copy. Recorded on Monad. ',
          style: TextStyle(
            fontFamily: CanaryTokens.displayFont,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: CanaryTokens.text,
            backgroundColor: CanaryTokens.canary,
          ),
        ),
        const SizedBox(height: 32),
        for (final fact in _facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: CanaryTokens.canary,
                    border: Border.all(color: CanaryTokens.text, width: 2),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    fact,
                    style: const TextStyle(
                      fontFamily: CanaryTokens.monoFont,
                      fontSize: 24,
                      letterSpacing: 1,
                      height: 1.1,
                      color: CanaryTokens.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
