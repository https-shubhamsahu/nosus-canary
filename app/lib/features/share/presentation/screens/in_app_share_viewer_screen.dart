import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../../../../components/secure_viewer/models/viewer_config.dart';
import '../../../../components/secure_viewer/models/watermark_config.dart';
import '../../../../components/secure_viewer/secure_document_viewer.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_gate.dart';
import '../../data/share_fetch_client.dart';
import '../../data/share_heartbeat_client.dart';
import '../../domain/entities/share_link.dart';

/// Entry point wrapper that forces the recipient to be signed in
/// (via [AuthGate]) before resolving and displaying the secure document.
class InAppShareViewerScreen extends StatelessWidget {
  const InAppShareViewerScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      child: _InAppShareViewerContent(token: token),
    );
  }
}

class _InAppShareViewerContent extends ConsumerStatefulWidget {
  const _InAppShareViewerContent({required this.token});

  final String token;

  @override
  ConsumerState<_InAppShareViewerContent> createState() =>
      __InAppShareViewerContentState();
}

class __InAppShareViewerContentState
    extends ConsumerState<_InAppShareViewerContent> {
  bool _isLoading = true;
  String? _errorMessage;
  ShareFetchResult? _result;
  Uint8List? _bytes;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDocument();
    });
  }

  @override
  void dispose() {
    _stopHeartbeat(close: true);
    super.dispose();
  }

  Future<void> _loadDocument() async {
    final user = ref.read(authStateProvider).value;
    final email = user?.email ?? 'app-user@nosus.internal';

    try {
      final result = await ShareFetchClient.instance.fetch(
        token: widget.token,
        viewerEmail: email,
        deviceType: 'app',
      );

      final bytesRes = await http.get(Uri.parse(result.signedUrl));
      if (bytesRes.statusCode != 200) {
        throw Exception('Could not download the document.');
      }

      if (!mounted) return;
      setState(() {
        _result = result;
        _bytes = bytesRes.bodyBytes;
        _isLoading = false;
      });

      if (result.viewEventId != null) {
        _startHeartbeat(result.viewEventId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startHeartbeat(String eventId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      ShareHeartbeatClient.instance.sendHeartbeat(eventId);
    });
  }

  void _stopHeartbeat({bool close = false}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final eventId = _result?.viewEventId;
    if (eventId != null && close) {
      ShareHeartbeatClient.instance.sendHeartbeat(eventId, close: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? '';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PREPARING DOCUMENT', style: TextStyle(fontSize: 12, letterSpacing: 1.0)),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.0),
              SizedBox(height: 16),
              Text('Fetching secure file…', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ERROR', style: TextStyle(fontSize: 12)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadDocument();
                  },
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result!;
    final bytes = _bytes!;

    final watermarkConfig = WatermarkConfig(
      name: email,
      role: 'RECIPIENT',
      email: email,
      timestamp: DateTime.now().toIso8601String(),
    );

    Widget docWidget;
    switch (result.fileType.toLowerCase()) {
      case 'pdf':
        docWidget = PdfViewer.data(
          bytes,
          sourceName: result.fileName,
          // No text selection in the protected viewer (copy leak + pdfrx
          // 2.4.4 selection painter crash on textless pages).
          params: const PdfViewerParams(
            textSelectionParams: PdfTextSelectionParams(enabled: false),
          ),
        );
        break;
      case 'image':
      case 'scan':
        docWidget = InteractiveViewer(child: Center(child: Image.memory(bytes)));
        break;
      default:
        docWidget = Center(
          child: Text(
            'This file type cannot be previewed in the app.',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.fileName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'SHARED LINK VIEW',
                    style: TextStyle(fontSize: 9, color: Colors.blueAccent, letterSpacing: 1.0, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SecureDocumentViewer(
          watermarkConfig: watermarkConfig,
          viewerConfig: const ViewerConfig(),
          touchToRevealEnabled: result.blurEnforced,
          watermarkEnabled: result.watermarkEnforced,
          child: docWidget,
        ),
      ),
    );
  }
}
