import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme.dart';
import '../../domain/canary_link.dart';

/// Ink and tint for one chain's chip. Monad keeps the orange paper tint with
/// an ink border; Solana gets a single restrained teal ink (5.7:1 on the
/// paper background) so the two proofs read apart without a brand gradient.
class _ChainStyle {
  const _ChainStyle({required this.ink, required this.tint});

  final Color ink;
  final Color tint;

  static const Color _solanaInk = Color(0xFF0F6E63);

  static _ChainStyle of(CanaryChain chain) => switch (chain) {
    CanaryChain.monad => const _ChainStyle(
      ink: CanaryTokens.monad,
      tint: Color(0x40F28C28),
    ),
    CanaryChain.solana => const _ChainStyle(
      ink: _solanaInk,
      tint: Color(0x1F0F6E63),
    ),
  };
}

const TextStyle _chipText = TextStyle(
  fontFamily: CanaryTokens.monoFont,
  fontSize: 20,
  color: CanaryTokens.text,
  height: 1.2,
);

/// On-chain status pill. Border and icon take the chain's ink; hash is VT323.
class ChainChip extends StatelessWidget {
  const ChainChip({
    super.key,
    required this.label,
    this.txHash,
    this.chain = CanaryChain.monad,
    this.compact = false,
  });

  final String label;
  final String? txHash;
  final CanaryChain chain;
  final bool compact;

  /// `0x1234…abcd` for hex hashes, `5VfY…Qm2p` for base58 signatures.
  static String shortHash(String hash) {
    final hex = hash.startsWith('0x');
    final h = hex ? hash.substring(2) : hash;
    if (h.length < 10) return hash;
    final short = '${h.substring(0, 4)}…${h.substring(h.length - 4)}';
    return hex ? '0x$short' : short;
  }

  Future<void> _open(BuildContext context) async {
    final hash = txHash;
    if (hash == null) return;
    // A 42-char 0x value is a Monad address (the contract), not a tx.
    final isMonadAddress = chain == CanaryChain.monad && hash.length == 42;
    final ok = await launchUrl(
      Uri.parse(
        isMonadAddress
            ? 'https://testnet.monadscan.com/address/$hash'
            : chain.txUrl(hash),
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the explorer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hash = txHash;
    final style = _ChainStyle.of(chain);
    final text = hash == null ? label : '$label · ${shortHash(hash)}';
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.tint,
          borderRadius: BorderRadius.circular(CanaryTokens.rChip),
          border: Border.all(color: style.ink),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 18, color: style.ink),
              const SizedBox(width: 8),
              Text(text, overflow: TextOverflow.ellipsis, style: _chipText),
            ],
          ),
        ),
      ),
    );

    if (hash == null) {
      return Semantics(label: label, child: chip);
    }
    return Semantics(
      button: true,
      label: '$label. View proof on ${chain.network}.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(CanaryTokens.rChip),
          onTap: () => _open(context),
          child: chip,
        ),
      ),
    );
  }
}

/// Same silhouette as [ChainChip] for a proof that is still being written:
/// a 16 px progress ring plus "Monad…" / "Solana…". Not tappable.
class PendingChainChip extends StatelessWidget {
  const PendingChainChip({
    super.key,
    required this.chain,
    this.compact = false,
  });

  final CanaryChain chain;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _ChainStyle.of(chain);
    final message = 'Recording on ${chain.network}…';
    return Semantics(
      label: message,
      excludeSemantics: true,
      child: Tooltip(
        message: message,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CanaryTokens.rChip),
              border: Border.all(color: style.ink.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: style.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${chain.label}…', style: _chipText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
