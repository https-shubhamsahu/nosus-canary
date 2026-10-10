import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/config/app_mode.dart';
import 'package:no_sus/features/canary/presentation/ui/chain_chip.dart';
import 'package:no_sus/features/canary/presentation/ui/proof_chips.dart';
import 'package:no_sus/theme.dart';

/// Widget tests draw text in a placeholder font whose glyphs are full
/// squares, which makes the pixel-font labels measure about twice their real
/// width. Load the real bundled fonts so layout checks match the browser.
Future<void> _loadFonts() async {
  const families = {
    'Outfit': ['Outfit-Regular', 'Outfit-SemiBold', 'Outfit-Bold'],
    'Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
    'VT323': ['VT323-Regular'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/google_fonts/$file.ttf'));
    }
    await loader.load();
  }
}

const _monadTx =
    '0x9f2c4b1e7d3a5c6b8e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d';
const _solanaSig =
    '5VfYmGZ8s3kQxq2wE1rT9yU4iO6pA7sD8fG0hJ1kL2zX3cV4bN5mQm2p';

Widget _host(Widget child, {double? width}) => MaterialApp(
  theme: CanaryTokens.theme(),
  home: Scaffold(
    body: Center(
      child: width == null ? child : SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('Monad only shows one linked chip and nothing for Solana', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProofChips(
          monadTxHash: _monadTx,
          labelPrefix: 'Sealed on',
          showMonad: true,
        ),
      ),
    );

    expect(find.byType(ChainChip), findsOneWidget);
    expect(find.text('Sealed on Monad · 0x9f2c…1c2d'), findsOneWidget);
    expect(find.textContaining('Solana'), findsNothing);
    expect(find.byType(PendingChainChip), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'View proof on Monad testnet')),
      findsOneWidget,
    );
  });

  testWidgets('Monad + Solana shows both chips with bounded hashes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProofChips(
          monadTxHash: _monadTx,
          solanaSig: _solanaSig,
          labelPrefix: 'Recorded on',
          showMonad: true,
        ),
      ),
    );

    expect(find.byType(ChainChip), findsNWidgets(2));
    expect(find.text('Recorded on Monad · 0x9f2c…1c2d'), findsOneWidget);
    // Base58 signature: no 0x prefix, first 4 + last 4.
    expect(find.text('Recorded on Solana · 5VfY…Qm2p'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'View proof on Solana devnet')),
      findsOneWidget,
    );
  });

  testWidgets('pending Solana shows a progress ring and no link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProofChips(
          monadTxHash: _monadTx,
          solanaPending: true,
          showMonad: true,
        ),
      ),
    );
    // One frame only: the progress ring animates forever.
    await tester.pump();

    expect(find.byType(ChainChip), findsOneWidget);
    expect(find.byType(PendingChainChip), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Solana…'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Recording on Solana devnet')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'View proof on Solana')), findsNothing);
    expect(find.byType(InkWell), findsOneWidget); // only the Monad chip taps
  });

  testWidgets('Solana off (null, not pending) renders nothing for Solana', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ProofChips(monadTxHash: _monadTx, showMonad: true)),
    );

    expect(find.byType(ChainChip), findsOneWidget);
    expect(find.byType(PendingChainChip), findsNothing);
    expect(find.textContaining('Solana'), findsNothing);
  });

  testWidgets('two chips wrap onto a second row at 320 px without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProofChips(
          monadTxHash: _monadTx,
          solanaSig: _solanaSig,
          labelPrefix: 'Recorded on',
          showMonad: true,
        ),
        width: 320,
      ),
    );

    expect(tester.takeException(), isNull);
    final chips = find.byType(ChainChip);
    expect(chips, findsNWidgets(2));
    final first = tester.getRect(chips.at(0));
    final second = tester.getRect(chips.at(1));
    expect(second.top, greaterThanOrEqualTo(first.bottom));
    expect(first.height, greaterThanOrEqualTo(48));
    expect(second.height, greaterThanOrEqualTo(48));
    expect(first.right, lessThanOrEqualTo(tester.getRect(find.byType(ProofChips)).right));
  });

  group('Monad hidden (CANARY_MONAD off)', () {
    testWidgets('only the Solana chip shows, even when a Monad hash exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ProofChips(
            monadTxHash: _monadTx,
            solanaSig: _solanaSig,
            monadPending: true,
            labelPrefix: 'Sealed on',
            showMonad: false,
          ),
        ),
      );

      expect(find.byType(ChainChip), findsOneWidget);
      expect(find.text('Sealed on Solana · 5VfY…Qm2p'), findsOneWidget);
      expect(find.byType(PendingChainChip), findsNothing);
      expect(find.textContaining('Monad'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Monad')), findsNothing);
    });

    testWidgets('a Solana-only proof renders on its own', (tester) async {
      await tester.pumpWidget(
        _host(const ProofChips(solanaSig: _solanaSig, showMonad: false)),
      );

      expect(find.byType(ChainChip), findsOneWidget);
      expect(find.text('Solana · 5VfY…Qm2p'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'View proof on Solana devnet')),
        findsOneWidget,
      );
    });

    testWidgets('pending Solana alone shows only the progress chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ProofChips(
            monadPending: true,
            solanaPending: true,
            showMonad: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ChainChip), findsNothing);
      expect(find.byType(PendingChainChip), findsOneWidget);
      expect(find.text('Solana…'), findsOneWidget);
      expect(find.textContaining('Monad'), findsNothing);
    });

    testWidgets('nothing to show renders an empty box', (tester) async {
      await tester.pumpWidget(
        _host(const ProofChips(monadTxHash: _monadTx, showMonad: false)),
      );

      expect(find.byType(ChainChip), findsNothing);
      expect(find.byType(PendingChainChip), findsNothing);
    });
  });

  testWidgets('showMonad defaults to the CANARY_MONAD build flag', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ProofChips(monadTxHash: _monadTx)));

    expect(
      find.byType(ChainChip),
      kCanaryMonad ? findsOneWidget : findsNothing,
    );
  });
}
