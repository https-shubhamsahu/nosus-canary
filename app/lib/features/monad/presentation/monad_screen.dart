import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/monad_receipt.dart';
import 'monad_providers.dart';

class MonadScreen extends ConsumerStatefulWidget {
  const MonadScreen({super.key, this.dropId});
  final String? dropId;
  @override
  ConsumerState<MonadScreen> createState() => _MonadScreenState();
}

class _MonadScreenState extends ConsumerState<MonadScreen> {
  final _input = TextEditingController();
  MonadReceipt? _receipt;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _input.text = widget.dropId ?? '';
    if (widget.dropId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verify();
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    final id = parseMonadDropId(_input.text);
    setState(() {
      _receipt = null;
      _error = null;
    });
    if (id == null) {
      setState(
        () => _error =
            'Enter a 0x receipt ID (64 hex characters), or a Monad receipt link.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final receipt = await ref.read(monadRepositoryProvider).receiptOf(id);
      if (mounted) setState(() => _receipt = receipt);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not reach Monad. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _step(String number, String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
  String _time(int seconds) => seconds == 0
      ? '—'
      : '${DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toIso8601String()} (UTC)';

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(monadRepositoryProvider).isConfigured;
    final receipt = _receipt;
    return Scaffold(
      appBar: AppBar(title: const Text('Monad receipts')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'NO SUS — MONAD EXPERIMENT',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 20),
              Text(
                'Share a note.\nKeep the acknowledgement.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 14),
              const Text(
                'An optional receipt for handoffs where the receiving wallet matters. '
                'Your Workspace, Vault, Study Desk and Burn tools remain part of this app.',
              ),
              const SizedBox(height: 24),
              const Card.outlined(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encrypted Monad sharing is not available yet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'We still need to verify that only the acknowledged wallet can decrypt. '
                        'Use harmless test data in this experimental app.',
                      ),
                      SizedBox(height: 16),
                      FilledButton(
                        onPressed: null,
                        child: Text('Send with a Monad receipt'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How the planned handoff works',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              _step(
                '01',
                'Address it to a wallet',
                'Encrypt a note for a recipient and choose an expiry.',
              ),
              _step(
                '02',
                'The recipient acknowledges',
                'Their wallet records an acknowledgement on Monad testnet.',
              ),
              _step(
                '03',
                'Unlock and verify',
                'Threshold custody permits decryption; the public receipt remains verifiable.',
              ),
              const Divider(height: 40),
              Text(
                'Verify a receipt',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Read public acknowledgement metadata directly from Monad. No wallet connection required.',
              ),
              if (!configured)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Waiting for the testnet contract deployment. Receipt lookup will become available here.',
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _input,
                enabled: !_loading,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Receipt ID or Monad receipt link',
                  hintText: '0x…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_receipt != null || _error != null) {
                    setState(() {
                      _receipt = null;
                      _error = null;
                    });
                  }
                },
                onSubmitted: configured ? (_) => _verify() : null,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: configured && !_loading ? _verify : null,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_loading ? 'Checking Monad…' : 'Verify receipt'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (receipt != null) ...[
                const SizedBox(height: 20),
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            receipt.status(DateTime.now()),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          'Sender\n${receipt.sender}\n\nRecipient\n${receipt.recipient == MonadReceipt.zeroAddress ? 'First eligible wallet' : receipt.recipient}'
                          '\n\nAcknowledged by\n${receipt.acknowledged ? receipt.opener : 'No wallet yet'}'
                          '\n\nSealed\n${_time(receipt.sealedAt)}\n\nAcknowledged\n${_time(receipt.openedAt)}'
                          '\n\nExpiry\n${receipt.expiresAt == 0 ? 'No expiry' : _time(receipt.expiresAt)}'
                          '\n\nEncrypted-content digest\n${receipt.ciphertextDigest}',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy receipt link'),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    'https://monad.nosus.foo/#/monad/${receipt.id}',
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Receipt link copied'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'A receipt proves a wallet acknowledged an encrypted drop. It does not prove '
                'that a person read it or that decryption succeeded. Wallet addresses and timestamps '
                'are public. Recipients can keep content after decrypting it.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
