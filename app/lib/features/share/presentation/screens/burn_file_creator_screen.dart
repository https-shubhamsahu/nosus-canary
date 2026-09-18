import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../core/utils/web_links.dart';
import '../../../../services/burn_file_crypto.dart';
import '../../data/burn_file_client.dart';
import '../../data/redemption_code_client.dart';

/// "Burn Files" creator — file.io-style anonymous upload. No login on
/// either end (product decision): the sender doesn't need an account, and
/// neither does the recipient. Mirrors BurnNoteCreatorScreen's zero-
/// knowledge design, extended to arbitrary binary files — see
/// lib/services/burn_file_crypto.dart for why the filename/mimetype are
/// packed INSIDE the encrypted payload rather than sent to the server.
///
/// Supports sharing multiple files as one link: each file keeps its own
/// independent key/IV (same crypto as a single file, just N of them) and
/// the whole encrypt→upload→confirm pipeline runs in PARALLEL across files
/// — for real speed, not just as a checkbox feature. The combined ciphertext
/// across every file in one share is capped at [_maxTotalBytes] (25MB);
/// the per-file cap is enforced authoritatively server-side via
/// remote_configs' burn_files_max_size_bytes.
class BurnFileCreatorScreen extends ConsumerStatefulWidget {
  /// Pre-fills the picker with a file shared into the app from another app
  /// (Photos, Files, WhatsApp, etc. via Android's share intent) — the
  /// highest-leverage "seamless" entry point: share a file into NO SUS and
  /// land here with it already selected.
  final fp.PlatformFile? prefilledFile;

  const BurnFileCreatorScreen({super.key, this.prefilledFile});

  @override
  ConsumerState<BurnFileCreatorScreen> createState() =>
      _BurnFileCreatorScreenState();
}

enum _ExpiryOption { oneHour, oneDay, sevenDays }

extension on _ExpiryOption {
  int get hours => switch (this) {
    _ExpiryOption.oneHour => 1,
    _ExpiryOption.oneDay => 24,
    _ExpiryOption.sevenDays => 24 * 7,
  };

  String get label => switch (this) {
    _ExpiryOption.oneHour => '1 HOUR',
    _ExpiryOption.oneDay => '24 HOURS',
    _ExpiryOption.sevenDays => '7 DAYS',
  };
}

// Combined cap across every file in ONE share. The per-file cap is the
// authoritative server-side remote_configs value (also 25MB by default) —
// this is the client-side "does this whole share fit" pre-flight check, so
// the user gets instant feedback instead of a failed network call partway
// through a multi-file upload.
const int _maxTotalBytes = 25 * 1024 * 1024;
const int _maxFilesPerShare = 10;

class _EncryptJob {
  final Uint8List packed;
  final Uint8List keyBytes;
  final Uint8List ivBytes;
  const _EncryptJob(this.packed, this.keyBytes, this.ivBytes);
}

// Top-level so it's eligible to run on a background isolate via compute() —
// AES-CBC over a multi-MB file is real CPU work, and running it off the UI
// thread is what keeps the picker/progress UI responsive while several
// files encrypt at once. compute() degrades to a plain synchronous call on
// platforms without isolate support, so this is safe everywhere.
Uint8List _encryptOnIsolate(_EncryptJob job) {
  return encryptBurnFilePayload(
    job.packed,
    enc.Key(job.keyBytes),
    enc.IV(job.ivBytes),
  );
}

class _BurnFileCreatorScreenState extends ConsumerState<BurnFileCreatorScreen> {
  final List<fp.PlatformFile> _selectedFiles = [];
  _ExpiryOption _expiry = _ExpiryOption.oneDay;
  bool _isProcessing = false;
  String? _statusLabel;
  String? _generatedLink;
  String? _generatedCode;
  String? _generatedPairingLink;
  int _filesDoneCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledFile != null) _selectedFiles.add(widget.prefilledFile!);
  }

  int get _totalBytes => _selectedFiles.fold(0, (sum, f) => sum + f.size);
  bool get _overLimit => _totalBytes > _maxTotalBytes;

  Future<void> _pickFiles() async {
    final result = await fp.FilePicker.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final f in result.files) {
        if (_selectedFiles.length >= _maxFilesPerShare) break;
        _selectedFiles.add(f);
      }
    });
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  Future<({String fileId, String keyHex, String ivHex})> _burnOneFile(
    fp.PlatformFile file,
  ) async {
    final bytes = file.bytes!;
    final keyMaterial = generateBurnFileKeyMaterial();
    final packed = packBurnFilePayload(
      fileName: file.name,
      mimeType: _guessMimeType(file.extension),
      fileBytes: bytes,
    );
    final ciphertext = await compute(
      _encryptOnIsolate,
      _EncryptJob(packed, keyMaterial.key.bytes, keyMaterial.iv.bytes),
    );

    final initResult = await BurnFileClient.instance.init(
      declaredSizeBytes: ciphertext.length,
      expiryHours: _expiry.hours,
    );

    await Supabase.instance.client.storage
        .from('burn-files')
        .uploadBinaryToSignedUrl(
          initResult.fileId,
          initResult.uploadToken,
          ciphertext,
        );

    await BurnFileClient.instance.confirm(initResult.fileId);

    if (mounted) setState(() => _filesDoneCount++);

    return (
      fileId: initResult.fileId,
      keyHex: bytesToHex(keyMaterial.key.bytes),
      ivHex: bytesToHex(keyMaterial.iv.bytes),
    );
  }

  Future<void> _burnAndUpload() async {
    if (_selectedFiles.isEmpty || _selectedFiles.any((f) => f.bytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose at least one file first.')),
      );
      return;
    }
    if (_overLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total size is ${_formatSize(_totalBytes)} — Burn Files shares are capped at 25MB combined.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _filesDoneCount = 0;
      _statusLabel = _selectedFiles.length > 1
          ? 'ENCRYPTING ${_selectedFiles.length} FILES...'
          : 'ENCRYPTING...';
    });
    ref.read(noxMascotProvider.notifier).play(MascotMood.guard);

    try {
      // Every file's encrypt→init→upload→confirm pipeline is independent —
      // running them concurrently is the real speed win for a multi-file
      // share, not just parallelizing the upload step.
      final triples = await Future.wait(
        _selectedFiles.map((f) => _burnOneFile(f)),
      );

      setState(() => _statusLabel = 'SEALING...');

      final (:origin, :basePath) = webShareLinkBase();
      final String link;
      String? code;
      String? pairingLink;
      if (triples.length == 1) {
        // Exactly the original single-file link shape — unchanged so every
        // burn-file link already shared into the wild keeps working, and so
        // the common case doesn't pay for multi-file link overhead.
        final t = triples.single;
        link =
            '$origin$basePath/#/burnfile/${t.fileId}?k=${t.keyHex}&v=${t.ivHex}';
        try {
          final codeResult = await RedemptionCodeClient.instance.createCode(
            targetKind: 'file',
            targetId: t.fileId,
            keyHex: t.keyHex,
            ivHex: t.ivHex,
          );
          code = codeResult.code;
          pairingLink = '$origin$basePath/#/redeem/${codeResult.redeemToken}';
        } catch (_) {
          code = null;
          pairingLink = null;
        }
      } else {
        // New multi-file shape. Redemption codes stay single-target only
        // (see supabase/migrations/20260713000000_burn_redemption_codes.sql)
        // — a multi-file share only gets the link, not a short code.
        final ids = triples.map((t) => t.fileId).join(',');
        final keys = triples.map((t) => t.keyHex).join(',');
        final ivs = triples.map((t) => t.ivHex).join(',');
        link = '$origin$basePath/#/burnfiles/$ids?k=$keys&v=$ivs';
        code = null;
        pairingLink = null;
      }

      setState(() {
        _generatedLink = link;
        _generatedCode = code;
        _generatedPairingLink = pairingLink;
        _isProcessing = false;
        _statusLabel = null;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusLabel = null;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create Burn File: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  static String _guessMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  void _copyToClipboard() {
    if (_generatedLink == null) return;
    Clipboard.setData(ClipboardData(text: _generatedLink!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Burn Files link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink() {
    if (_generatedLink == null) return;
    SharePlus.instance.share(
      ShareParams(
        text:
            'Here\'s a file — it self-destructs after one download: $_generatedLink',
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
              'BURN FILES',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'ANONYMOUS · SELF-DESTRUCTS ON DOWNLOAD',
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
                    'Drop up to $_maxFilesPerShare files, get one link. Nobody needs an account — not you, not them. Once downloaded, they\'re gone.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedFiles.isNotEmpty) ...[
                    ..._selectedFiles.asMap().entries.map((entry) {
                      final i = entry.key;
                      final f = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161616)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orangeAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                size: 18,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  f.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: fg.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatSize(f.size),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: fg.withValues(alpha: 0.4),
                                ),
                              ),
                              if (!_isProcessing) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _removeFile(i),
                                  tooltip: 'Remove ${f.name}',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: fg.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedFiles.length}/$_maxFilesPerShare files · ${_formatSize(_totalBytes)} / 25.0 MB',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _overLimit
                                ? Colors.redAccent
                                : fg.withValues(alpha: 0.45),
                          ),
                        ),
                        if (_selectedFiles.length < _maxFilesPerShare &&
                            !_isProcessing)
                          TextButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text(
                              'ADD MORE',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else
                    Semantics(
                      button: true,
                      enabled: !_isProcessing,
                      label: 'Choose files',
                      child: InkWell(
                        onTap: _isProcessing ? null : _pickFiles,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161616)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: fg.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.upload_file_outlined,
                                size: 36,
                                color: fg.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'TAP TO CHOOSE FILES',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: fg.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'LINK EXPIRES AFTER',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.0,
                      color: fg.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<_ExpiryOption>(
                    segments: _ExpiryOption.values
                        .map(
                          (e) => ButtonSegment(
                            value: e,
                            label: Text(
                              e.label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                    selected: {_expiry},
                    onSelectionChanged: _isProcessing
                        ? null
                        : (s) => setState(() => _expiry = s.first),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed:
                          (_isProcessing ||
                              _selectedFiles.isEmpty ||
                              _overLimit)
                          ? null
                          : _burnAndUpload,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.local_fire_department_outlined,
                              size: 16,
                            ),
                      label: Text(
                        _isProcessing
                            ? '${_statusLabel ?? 'WORKING...'} ${_selectedFiles.length > 1 ? '($_filesDoneCount/${_selectedFiles.length})' : ''}'
                            : (_selectedFiles.length > 1
                                  ? 'ENCRYPT & GENERATE LINK (${_selectedFiles.length} FILES)'
                                  : 'ENCRYPT & GENERATE LINK'),
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
                        Text(
                          _selectedFiles.length > 1
                              ? '${_selectedFiles.length} FILES READY TO SHARE'
                              : 'FILE READY TO SHARE',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFiles.length > 1
                              ? 'Your files are encrypted. The keys live only in this link — the server cannot read them, and each is deleted permanently the moment it\'s downloaded.'
                              : 'Your file is encrypted. The key lives only in this link — the server cannot read it, and it\'s deleted permanently the moment it\'s downloaded.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
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
                              _selectedFiles.clear();
                            });
                          },
                          child: const Text(
                            'BURN MORE FILES',
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
