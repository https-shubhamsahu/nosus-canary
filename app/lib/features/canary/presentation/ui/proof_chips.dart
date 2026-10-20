import 'package:flutter/material.dart';

import '../../../../config/app_mode.dart';
import '../../domain/canary_link.dart';
import 'chain_chip.dart';

/// The on-chain proofs for one seal or one open.
///
/// Solana devnet is the receipt: its chip shows whenever a signature exists.
/// The Monad testnet chip (earlier prototype) shows only when [showMonad] is
/// true, which defaults to the CANARY_MONAD build flag ([kCanaryMonad]).
///
/// A [ChainChip] is shown for every hash that exists. A null hash shows a
/// [PendingChainChip] only when the matching `pending` flag is true, so a
/// chain that is switched off simply does not appear. Chips wrap onto new
/// rows instead of clipping on narrow screens.
class ProofChips extends StatelessWidget {
  const ProofChips({
    super.key,
    this.monadTxHash,
    this.solanaSig,
    this.monadPending = false,
    this.solanaPending = false,
    this.labelPrefix = '',
    this.compact = false,
    bool? showMonad,
  }) : showMonad = showMonad ?? kCanaryMonad;

  final String? monadTxHash;
  final String? solanaSig;

  /// Show a progress chip while the Monad record is still being written.
  final bool monadPending;

  /// Show a progress chip while the Solana record is still being written.
  final bool solanaPending;

  /// 'Sealed on' / 'Recorded on' / '' (bare chain name).
  final String labelPrefix;
  final bool compact;

  /// Whether the Monad chip may appear at all.
  final bool showMonad;

  String _label(CanaryChain chain) =>
      labelPrefix.isEmpty ? chain.label : '$labelPrefix ${chain.label}';

  Widget? _chip(CanaryChain chain, String? hash, bool pending) {
    if (hash != null) {
      return ChainChip(
        chain: chain,
        label: _label(chain),
        txHash: hash,
        compact: compact,
      );
    }
    if (pending) return PendingChainChip(chain: chain, compact: compact);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (showMonad) _chip(CanaryChain.monad, monadTxHash, monadPending),
      _chip(CanaryChain.solana, solanaSig, solanaPending),
    ].nonNulls.toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}
