import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme.dart';
import '../../wallet/monad_wallet.dart';
import '../canary_ui.dart';

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _friendly(Object e) {
  if (e is WalletError && e.code == 4001) return 'Request rejected in your wallet.';
  if (e is WalletError && e.code == -32002) {
    return 'Your wallet already has a request open. Check the wallet window.';
  }
  return e.toString();
}

/// "Connect wallet" for Monad testnet: connect, switch or add the network,
/// then show the address and MON balance with a small menu.
class WalletButton extends StatelessWidget {
  const WalletButton({super.key, this.compact = false});

  final bool compact;

  Future<void> _connect(BuildContext context) async {
    final wallet = MonadWallet.instance;
    if (!wallet.available) {
      await _noWalletDialog(context);
      return;
    }
    try {
      await wallet.connect();
      if (context.mounted && wallet.value.onMonad) {
        _toast(context, 'Wallet connected on Monad testnet.');
      }
    } catch (e) {
      if (context.mounted) _toast(context, _friendly(e));
    }
  }

  Future<void> _switch(BuildContext context) async {
    try {
      await MonadWallet.instance.switchToMonad();
    } catch (e) {
      if (context.mounted) _toast(context, _friendly(e));
    }
  }

  Future<void> _noWalletDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('No wallet found'),
      content: const Text(
        'Install a browser wallet such as MetaMask, Rabby or Phantom, then '
        'reload this page.\n\nYou do not need one to use Canary: the NO SUS '
        'relayer pays for every Monad transaction. A wallet lets you check '
        'the seal on Monad yourself.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            _open('https://metamask.io/download/');
            Navigator.of(context).pop();
          },
          child: const Text('Get MetaMask'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return ValueListenableBuilder<WalletState>(
      valueListenable: MonadWallet.instance,
      builder: (context, state, _) {
        if (state.busy) {
          return _shell(
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            label: 'Connecting…',
            onPressed: null,
          );
        }
        if (!state.connected) {
          return _shell(
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: 'Connect wallet',
            onPressed: () => _connect(context),
          );
        }
        if (!state.onMonad) {
          return _shell(
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: 'Switch to Monad',
            filled: true,
            onPressed: () => _switch(context),
          );
        }
        return _ConnectedMenu(state: state, compact: compact);
      },
    );
  }

  Widget _shell({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: filled ? CanaryTokens.canary : null,
        ),
        icon: icon,
      );
    }
    final style = OutlinedButton.styleFrom(
      foregroundColor: CanaryTokens.text,
      backgroundColor: filled ? CanaryTokens.canary : CanaryTokens.surface,
      side: const BorderSide(color: CanaryTokens.text, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CanaryTokens.rChip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    );
    return OutlinedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}

class _ConnectedMenu extends StatelessWidget {
  const _ConnectedMenu({required this.state, required this.compact});

  final WalletState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: CanaryTokens.surface,
        borderRadius: BorderRadius.circular(CanaryTokens.rChip),
        border: Border.all(color: CanaryTokens.text, width: 2),
        boxShadow: const [
          BoxShadow(color: CanaryTokens.text, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: CanaryTokens.canary,
              shape: BoxShape.circle,
              border: Border.all(color: CanaryTokens.text, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            compact
                ? state.shortAddress
                : '${state.shortAddress} · ${state.balanceMon} MON',
            style: const TextStyle(
              fontFamily: CanaryTokens.monoFont,
              fontSize: 18,
              color: CanaryTokens.text,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: CanaryTokens.text),
        ],
      ),
    );

    return Tooltip(
      message: 'Wallet',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(CanaryTokens.rChip),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const _WalletPanel(),
          ),
          child: pill,
        ),
      ),
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WalletState>(
      valueListenable: MonadWallet.instance,
      builder: (context, state, _) {
        final wallet = MonadWallet.instance;
        final address = state.address;
        Widget action(IconData icon, String label, Future<void> Function() run) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: Icon(icon, size: 18),
                label: Text(label),
                onPressed: run,
              ),
            );
        return AlertDialog(
          title: const Text('Your wallet'),
          content: SizedBox(
            width: 400,
            child: address == null
                ? const Text('Not connected.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CanaryTokens.canary,
                          borderRadius: BorderRadius.circular(CanaryTokens.rChip),
                          border: Border.all(color: CanaryTokens.text, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.onMonad ? 'MONAD TESTNET' : 'WRONG NETWORK',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: CanaryTokens.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${state.balanceMon} MON',
                              style: const TextStyle(
                                fontFamily: CanaryTokens.monoFont,
                                fontSize: 34,
                                color: CanaryTokens.text,
                              ),
                            ),
                            SelectableText(
                              address,
                              style: const TextStyle(
                                fontFamily: CanaryTokens.monoFont,
                                fontSize: 16,
                                color: CanaryTokens.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!state.onMonad)
                        action(Icons.swap_horiz, 'Switch to Monad testnet', () async {
                          try {
                            await wallet.switchToMonad();
                          } catch (e) {
                            if (context.mounted) _toast(context, _friendly(e));
                          }
                        }),
                      action(Icons.copy, 'Copy address', () async {
                        await Clipboard.setData(ClipboardData(text: address));
                        if (context.mounted) _toast(context, 'Address copied.');
                      }),
                      action(Icons.open_in_new, 'My wallet on Monadscan',
                          () => _open(monadAddressUrl(address))),
                      if (canaryContractAddress.isNotEmpty)
                        action(Icons.description_outlined, 'Canary contract on Monadscan',
                            () => _open(monadAddressUrl(canaryContractAddress))),
                      action(Icons.water_drop_outlined, 'Get testnet MON',
                          () => _open('https://faucet.monad.xyz/')),
                      action(Icons.refresh, 'Refresh balance', wallet.refresh),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await wallet.disconnect();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _toast(context, 'Wallet disconnected.');
                }
              },
              child: const Text('Disconnect'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

/// Reads this note's seal straight from the NoSusCanary contract and shows it.
class VerifyOnMonadButton extends StatelessWidget {
  const VerifyOnMonadButton({super.key, required this.noteId, this.localOpened});

  final String noteId;

  /// How many opens the NO SUS server reports, to compare with the chain.
  final int? localOpened;

  @override
  Widget build(BuildContext context) {
    if (canaryContractAddress.isEmpty) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const Icon(Icons.verified_outlined),
      label: const Text('Verify on Monad'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => _VerifyDialog(noteId: noteId, localOpened: localOpened),
      ),
    );
  }
}

class _VerifyDialog extends StatelessWidget {
  const _VerifyDialog({required this.noteId, this.localOpened});

  final String noteId;
  final int? localOpened;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('On-chain seal'),
      content: SizedBox(
        width: 440,
        child: FutureBuilder<CanaryChainNote>(
          future: readCanaryNoteOnChain(noteId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 14),
                    Text('Reading NoSusCanary on Monad…'),
                  ],
                ),
              );
            }
            if (snap.hasError) {
              return Text('Could not read Monad: ${snap.error}');
            }
            final n = snap.data!;
            if (!n.exists) {
              return const Text(
                'This note is not sealed on Monad yet. Sealing takes a few '
                'seconds after the link is created; try again shortly.',
              );
            }
            Widget row(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: SelectableText(
                      v,
                      style: const TextStyle(fontFamily: CanaryTokens.monoFont, fontSize: 18),
                    ),
                  ),
                ],
              ),
            );
            final hash = n.copiesHash;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: CanaryTokens.canary,
                  child: const Text(
                    'SEALED ON MONAD',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 12),
                row('Sealed', '${n.sealedAt!.toLocal()}'),
                row('Copies', '${n.copyCount}'),
                row(
                  'Opened',
                  localOpened == null
                      ? '${n.openedCount}'
                      : '${n.openedCount} on-chain · $localOpened on NO SUS',
                ),
                if (n.expiresAt != null) row('Expires', CanaryUi.clock(n.expiresAt!)),
                row('Copies hash', '${hash.substring(0, 10)}…${hash.substring(hash.length - 6)}'),
                row('Read via', n.readVia),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _open(monadAddressUrl(canaryContractAddress)),
          child: const Text('Contract on Monadscan ↗'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
