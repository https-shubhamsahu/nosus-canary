import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:uuid/uuid.dart';
import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../core/utils/web_links.dart';
import '../../../../services/burn_file_crypto.dart' show bytesToHex;
import '../../data/redemption_code_client.dart';

class BurnNoteCreatorScreen extends ConsumerStatefulWidget {
  const BurnNoteCreatorScreen({super.key});

  @override
  ConsumerState<BurnNoteCreatorScreen> createState() =>
      _BurnNoteCreatorScreenState();
}

class _BurnNoteCreatorScreenState extends ConsumerState<BurnNoteCreatorScreen> {
  final _textController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedLink;
  String? _generatedCode;
  String? _generatedPairingLink;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a secret note first.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });
    ref.read(noxMascotProvider.notifier).play(MascotMood.guard);

    try {
      // 1. Generate 256-bit AES Key and 128-bit IV
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key));

      // 2. Encrypt plaintext note
      final encrypted = encrypter.encrypt(text, iv: iv);
      final ciphertext = encrypted.base64;

      // 3. Upload to Supabase database (Server only gets UUID and ciphertext).
      // The id is generated client-side (not read back via .select()) so the
      // burn_notes table needs no public SELECT policy — reads only ever
      // happen through the atomic read_and_burn_note RPC.
      final noteId = const Uuid().v4();
      await Supabase.instance.client.from('burn_notes').insert({
        'id': noteId,
        'ciphertext': ciphertext,
      });

      // 4. Construct URL with key and iv as query params inside the hash fragment (Zero-Knowledge)
      // We use ?k=<key>&v=<iv> INSIDE the fragment so they are never sent to the server.
      // Double-hash (#...#...) breaks in most browsers — query params inside the
      // hash are spec-compliant and preserved reliably.
      final (:origin, :basePath) = webShareLinkBase();
      final keyHex = bytesToHex(key.bytes);
      final ivHex = bytesToHex(iv.bytes);
      final link = '$origin$basePath/#/burn/$noteId?k=$keyHex&v=$ivHex';

      // 5. Also mint a short redemption code pointing at the same key/IV —
      // best-effort: the link already works on its own.
      String? code;
      String? pairingLink;
      try {
        final codeResult = await RedemptionCodeClient.instance.createCode(
          targetKind: 'note',
          targetId: noteId,
          keyHex: keyHex,
          ivHex: ivHex,
        );
        code = codeResult.code;
        pairingLink = '$origin$basePath/#/redeem/${codeResult.redeemToken}';
      } catch (_) {
        code = null;
        pairingLink = null;
      }

      setState(() {
        _generatedLink = link;
        _generatedCode = code;
        _generatedPairingLink = pairingLink;
        _isGenerating = false;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate link: $e')));
    }
  }

  void _copyToClipboard() {
    if (_generatedLink == null) return;
    Clipboard.setData(ClipboardData(text: _generatedLink!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Secret link copied to clipboard! Share it in your Story.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink() {
    if (_generatedLink == null) return;
    SharePlus.instance.share(
      ShareParams(
        text: 'Read my self-destructing secret note: $_generatedLink',
      ),
    );
  }

  void _copyCodeToClipboard() {
    if (_generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedCode!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyPairingLinkToClipboard() {
    final pairingLink = _generatedPairingLink;
    if (pairingLink == null) return;
    Clipboard.setData(ClipboardData(text: pairingLink));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secure pairing link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BURN NOTES',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'ZERO-KNOWLEDGE SELF-DESTRUCTS',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orangeAccent,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_generatedLink == null) ...[
                  Text(
                    'Write a secret message to share. The recipient can only view it once before it burns.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 240,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161616)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: fg.withValues(alpha: 0.12)),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        // Well under the server's 100 KB ciphertext cap, so a
                        // legitimate note can never hit the raw DB error.
                        maxLength: 10000,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type your secret message here...',
                          border: InputBorder.none,
                          counterStyle: TextStyle(
                            fontSize: 9,
                            color: fg.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isGenerating ? null : _generateLink,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.lock_outline, size: 16),
                      label: Text(
                        _isGenerating
                            ? 'ENCRYPTING...'
                            : 'ENCRYPT & GENERATE LINK',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const MascotView(
                          character: MascotCharacter.nox,
                          size: 48,
                          fallback: Icon(
                            Icons.verified_user_outlined,
                            size: 48,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'NOTE READY TO SHARE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your note is encrypted. The key is embedded in the link fragment. The server cannot read it, and it will be deleted permanently once opened.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161616)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _generatedLink!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        if (_generatedCode != null &&
                            _generatedPairingLink != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            'OPTIONAL QUICK PAIRING',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.0,
                              color: fg.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF161616)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.lightBlueAccent.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _generatedCode!,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: _copyCodeToClipboard,
                                  tooltip: 'Copy code',
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Send the secure pairing link, then share these two digits. The link controls access; the code only confirms the share.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: fg.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        if (_generatedPairingLink != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: _copyPairingLinkToClipboard,
                              icon: const Icon(Icons.link_rounded, size: 16),
                              label: const Text(
                                'COPY PAIRING LINK',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text(
                              'COPY LINK',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _shareLink,
                            icon: const Icon(Icons.ios_share_rounded, size: 16),
                            label: const Text(
                              'SHARE LINK',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _generatedLink = null;
                              _generatedCode = null;
                              _generatedPairingLink = null;
                              _textController.clear();
                            });
                          },
                          child: const Text(
                            'CREATE ANOTHER NOTE',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
