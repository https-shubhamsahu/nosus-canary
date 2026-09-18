import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../monad/presentation/experiment_frame.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:encrypt/encrypt.dart' as enc;
import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../services/web_security_guard.dart';

List<int> _hexToBytes(String hex) {
  final bytes = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

class BurnNoteViewerScreen extends ConsumerStatefulWidget {
  const BurnNoteViewerScreen({
    super.key,
    required this.noteId,
    required this.keyHex,
    required this.ivHex,
  });

  final String noteId;
  final String keyHex;
  final String ivHex;

  @override
  ConsumerState<BurnNoteViewerScreen> createState() => _BurnNoteViewerScreenState();
}

enum _BurnStage { gate, decrypting, active, burned, error }

class _BurnNoteViewerScreenState extends ConsumerState<BurnNoteViewerScreen> {
  _BurnStage _stage = _BurnStage.gate;
  String? _decryptedContent;
  String? _errorMessage;
  int _secondsLeft = 60;
  Timer? _timer;
  StreamSubscription? _blurSubscription;
  // Deliberately does NOT block copy/select: the note body below uses
  // SelectableText on purpose (a recipient may need to copy the secret
  // before it burns). No server reporting either — burn notes have no
  // view-event ledger the way SecureSend share links do.
  final _webGuard = WebSecurityGuard(
    blockCopy: false,
    blockCut: false,
    blockSelect: false,
    detectDevTools: false,
    detectVisibilityChanges: false,
  );

  @override
  void dispose() {
    _timer?.cancel();
    _blurSubscription?.cancel();
    _webGuard.detach();
    super.dispose();
  }

  void _burnImmediately() {
    if (_stage != _BurnStage.active) return;
    _timer?.cancel();
    _blurSubscription?.cancel();
    _webGuard.detach();
    setState(() {
      _decryptedContent = null;
      _stage = _BurnStage.burned;
    });
    ref.read(noxMascotProvider.notifier).play(MascotMood.returnToLogo);
  }

  Future<void> _reveal() async {
    setState(() {
      _stage = _BurnStage.decrypting;
    });

    try {
      // 1. Fetch ciphertext & delete instantly from DB using the RPC
      final response = await Supabase.instance.client
          .rpc('read_and_burn_note', params: {'note_id': widget.noteId});

      if (response == null) {
        throw Exception('This secret has already been burned, read, or expired.');
      }

      final ciphertext = response as String;

      // 2. Decrypt in memory using the hash key and IV
      final keyBytes = _hexToBytes(widget.keyHex);
      final ivBytes = _hexToBytes(widget.ivHex);
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(Uint8List.fromList(ivBytes));
      final encrypter = enc.Encrypter(enc.AES(key));

      final decrypted = encrypter.decrypt(
        enc.Encrypted.fromBase64(ciphertext),
        iv: iv,
      );

      if (!mounted) return;
      setState(() {
        _decryptedContent = decrypted;
        _stage = _BurnStage.active;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.guard);
      if (kIsWeb) _webGuard.attach((_) {});

      // 3. Start 60s countdown
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft <= 1) {
          _burnImmediately();
        } else {
          setState(() {
            _secondsLeft--;
          });
          if (_secondsLeft == 10) {
            ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
          }
        }
      });

      // 4. Tab Blur detection on Web (Burn note immediately if tab switched)
      if (kIsWeb) {
        _blurSubscription = html.window.onBlur.listen((_) {
          _burnImmediately();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _BurnStage.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => ExperimentFrame(child: child ?? const SizedBox.shrink()),
      title: 'NO SUS — Burn Secret',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: switch (_stage) {
                  _BurnStage.gate => _buildGate(),
                  _BurnStage.decrypting => _buildDecrypting(),
                  _BurnStage.active => _buildActive(),
                  _BurnStage.burned => _buildBurned(),
                  _BurnStage.error => _buildError(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGate() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, size: 56, color: Colors.orangeAccent)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 800.ms),
        const SizedBox(height: 24),
        const Text(
          'BURN NOTE DETECTED',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'This is a zero-knowledge encrypted burn note. Once you open it, the server deletes it permanently. You will have exactly 60 seconds to read it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _reveal,
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text(
              'DECRYPT & REVEAL NOTE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecrypting() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.orangeAccent),
        SizedBox(height: 20),
        Text(
          'CONNECTING TO ENCLAVE & BURNING DATA...',
          style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: Colors.orangeAccent),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActive() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department, size: 16, color: Colors.orangeAccent),
                SizedBox(width: 6),
                MascotView(character: MascotCharacter.nox, size: 18),
                SizedBox(width: 6),
                Text(
                  'BURN-ON-READ ACTIVE',
                  style: TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.redAccent, width: 0.5),
              ),
              child: Text(
                '${_secondsLeft}s LEFT',
                style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Progress burning bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _secondsLeft / 60,
            color: Colors.orangeAccent,
            backgroundColor: Colors.white10,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.2)),
          ),
          child: SelectableText(
            _decryptedContent ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Courier',
              height: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _burnImmediately,
          icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
          label: const Text('BURN IMMEDIATELY', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildBurned() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MascotView(
          character: MascotCharacter.duo,
          size: 56,
          fallback: Icon(Icons.whatshot, size: 56, color: Colors.grey),
        ).animate().shake(duration: 400.ms).fadeOut(duration: 800.ms),
        const SizedBox(height: 24),
        const Text(
          'SECRET ZEROIZED',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        const Text(
          'This note has been completely deleted from the database and cleared from browser memory. It cannot be recovered.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MascotView(
          character: MascotCharacter.nox,
          size: 48,
          fallback: Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        ),
        const SizedBox(height: 20),
        Text(
          _errorMessage ?? 'Failed to decrypt note.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
