import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme.dart';
import '../../domain/canary_link.dart';

/// On-chain status pill. Monad purple only; hash is VT323.
class ChainChip extends StatelessWidget {
  const ChainChip({
    super.key,
    required this.label,
    this.txHash,
    this.compact = false,
  });

  final String label;
  final String? txHash;
  final bool compact;

  static String shortHash(String hash) {
    final h = hash.startsWith('0x') ? hash.substring(2) : hash;
    if (h.length < 10) return hash;
    return '0x${h.substring(0, 4)}…${h.substring(h.length - 4)}';
  }

  Future<void> _open(BuildContext context) async {
    final hash = txHash;
    if (hash == null) return;
    final ok = await launchUrl(
      Uri.parse(
        hash.length == 42
            ? 'https://testnet.monadscan.com/address/$hash'
            : canaryExplorerTxUrl(hash),
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
    final text = hash == null ? label : '$label · ${shortHash(hash)}';
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x40F28C28),
          borderRadius: BorderRadius.circular(CanaryTokens.rChip),
          border: Border.all(color: CanaryTokens.monad),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 18, color: CanaryTokens.monad),
              const SizedBox(width: 8),
              Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: CanaryTokens.monoFont,
                  fontSize: 20,
                  color: CanaryTokens.text,
                  height: 1.2,
                ),
              ),
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
      label: '$label. View proof on Monad testnet.',
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
