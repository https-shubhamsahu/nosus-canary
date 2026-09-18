import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import '../../../monad/presentation/experiment_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../services/burn_file_crypto.dart';
import '../../data/burn_file_client.dart';

typedef BurnFileTarget = ({String id, String keyHex, String ivHex});

/// Anonymous recipient side of "Burn Files" — no account, no email gate,
/// single tap. Handles both a single file (the original link shape) and a
/// multi-file share (a NEW link shape, see extractBurnFilesToken in
/// lib/main.dart) through the same code path: [files] is just a
/// single-element list for the classic case.
///
/// Every file in [files] is independently fetched, claimed, and decrypted —
/// each with its own key/IV, exactly like the single-file crypto always
/// worked (no new crypto primitive for the multi-file case, just N of them
/// run in parallel for speed). Fetch/claim is a one-time, irreversible burn
/// PER FILE, so a multi-file share can partially succeed (e.g. one link
/// already used) — this screen tracks and reports that honestly rather than
/// treating the batch as all-or-nothing.
class BurnFileViewerScreen extends ConsumerStatefulWidget {
  final List<BurnFileTarget> files;

  const BurnFileViewerScreen({super.key, required this.files});

  @override
  ConsumerState<BurnFileViewerScreen> createState() => _BurnFileViewerScreenState();
}

enum _Stage { gate, fetching, delivered, error }

class _FileOutcome {
  final String fileName;
  final bool ok;
  final String? error;
  const _FileOutcome({required this.fileName, required this.ok, this.error});
}

class _BurnFileViewerScreenState extends ConsumerState<BurnFileViewerScreen> {
  _Stage _stage = _Stage.gate;
  List<_FileOutcome> _outcomes = [];

  bool get _isBatch => widget.files.length > 1;

  Future<void> _downloadAndDecryptOne(BurnFileTarget target) async {
    final signedUrl = await BurnFileClient.instance.fetch(target.id);
    final res = await http.get(Uri.parse(signedUrl));
    if (res.statusCode != 200) {
      throw Exception('Could not download the file.');
    }
    final key = enc.Key(hexToBytes(target.keyHex));
    final iv = enc.IV(hexToBytes(target.ivHex));
    final packed = decryptBurnFilePayload(res.bodyBytes, key, iv);
    final payload = unpackBurnFilePayload(packed);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(payload.bytes, name: payload.fileName, mimeType: payload.mimeType)],
      ),
    );
    return;
  }

  Future<void> _downloadAndDecryptAll() async {
    setState(() => _stage = _Stage.fetching);
    ref.read(noxMascotProvider.notifier).play(MascotMood.guard);

    // Each file's fetch→decrypt→hand-off pipeline is fully independent of
    // every other file's — running them concurrently (rather than one at a
    // time) is the actual "as fast as possible" win for a multi-file share.
    // errors are captured per-file so one bad/expired link in the batch
    // doesn't hide whether the OTHER files were delivered successfully.
    final results = await Future.wait(widget.files.map((target) async {
      try {
        await _downloadAndDecryptOne(target);
        return _FileOutcome(fileName: target.id, ok: true);
      } catch (e) {
        return _FileOutcome(
          fileName: target.id,
          ok: false,
          error: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }));

    if (!mounted) return;
    final anyOk = results.any((r) => r.ok);
    setState(() {
      _outcomes = results;
      _stage = anyOk ? _Stage.delivered : _Stage.error;
    });
    ref.read(noxMascotProvider.notifier).play(anyOk ? MascotMood.approve : MascotMood.alert);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => ExperimentFrame(child: child ?? const SizedBox.shrink()),
      title: 'NO SUS — Burn File',
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
                  _Stage.gate => _buildGate(),
                  _Stage.fetching => _buildFetching(),
                  _Stage.delivered => _buildDelivered(),
                  _Stage.error => _buildError(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGate() {
    final count = widget.files.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, size: 56, color: Colors.orangeAccent),
        const SizedBox(height: 24),
        Text(
          _isBatch ? '$count BURN FILES DETECTED' : 'BURN FILE DETECTED',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          _isBatch
              ? 'This is $count encrypted, one-time file drops shared together. No account needed. Once downloaded, they are permanently deleted from the server.'
              : 'This is an encrypted, one-time file drop. No account needed. Once you download it, it is permanently deleted from the server.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
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
            onPressed: _downloadAndDecryptAll,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(
              _isBatch ? 'DOWNLOAD $count FILES' : 'DOWNLOAD FILE',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFetching() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.orangeAccent),
        const SizedBox(height: 20),
        Text(
          _isBatch ? 'DECRYPTING & DELIVERING ${widget.files.length} FILES...' : 'DECRYPTING & DELIVERING...',
          style: const TextStyle(fontSize: 10, letterSpacing: 1.0, color: Colors.orangeAccent),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDelivered() {
    final okCount = _outcomes.where((o) => o.ok).length;
    final failed = _outcomes.where((o) => !o.ok).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MascotView(
          character: MascotCharacter.nox,
          size: 48,
          fallback: Icon(Icons.verified_user_outlined, size: 48, color: Colors.green),
        ),
        const SizedBox(height: 20),
        Text(
          _isBatch ? '$okCount OF ${_outcomes.length} FILES DELIVERED' : 'FILE DELIVERED',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        const Text(
          'Delivered files have been permanently deleted from our servers. These links will never work again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${failed.length} could not be delivered (already used or expired).',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    final err = _outcomes.isNotEmpty ? _outcomes.first.error : null;
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
          err ?? 'THIS LINK HAS EXPIRED OR ALREADY BEEN USED.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.redAccent),
        ),
      ],
    );
  }
}
