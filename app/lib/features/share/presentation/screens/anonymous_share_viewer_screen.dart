import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../monad/presentation/experiment_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../../../../components/secure_viewer/models/viewer_config.dart';
import '../../../../components/secure_viewer/models/watermark_config.dart';
import '../../../../components/secure_viewer/secure_document_viewer.dart';
import '../../data/share_fetch_client.dart';
import '../../data/share_heartbeat_client.dart';
import '../../../../services/web_security_guard.dart';
import '../../domain/entities/share_link.dart';

/// SecureSend's anonymous recipient view. Deliberately NOT a [ConsumerWidget]
/// and NOT wired to any Supabase session — a share-link recipient may have no
/// NO SUS account at all. Auth for this screen is the link token itself.
///
/// Flow: enter email (the watermark identity + what gets logged) -> resolve
/// the token via the public `share-fetch` function -> fetch bytes from the
/// short-lived signed URL -> render in the SAME secure viewer used in-app.
///
/// HONESTY RULE: this is a browser. Screenshot-blocking is impossible here —
/// protection is watermark-with-identity + blur-until-touch + view logging.
/// Never claim "screenshot-proof" in this screen's copy.
class AnonymousShareViewerScreen extends ConsumerStatefulWidget {
  const AnonymousShareViewerScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AnonymousShareViewerScreen> createState() =>
      _AnonymousShareViewerScreenState();
}

enum _Stage { emailGate, loading, viewing, error }

class _AnonymousShareViewerScreenState
    extends ConsumerState<AnonymousShareViewerScreen> {
  _Stage _stage = _Stage.emailGate;
  final _emailController = TextEditingController();
  String? _errorMessage;
  ShareFetchResult? _result;
  Uint8List? _bytes;
  Timer? _heartbeatTimer;
  final _webGuard = WebSecurityGuard();
  // Broadcasts to SecureDocumentViewer's blur layer whenever WebSecurityGuard
  // reports a signal that suggests active inspection or capture. This can't
  // detect an actual OS screenshot — no browser API exposes that — but
  // DevTools opening or repeated tab-hiding are the closest real proxies,
  // and blurring immediately on them is a genuine reactive deterrent rather
  // than a claim of prevention.
  final _concealSignal = StreamController<void>.broadcast();

  static const _concealTriggers = {
    'devtools_detected',
    'visibility_hidden_repeated',
    'automation_detected',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _stopHeartbeat(close: true);
    _webGuard.detach();
    _concealSignal.close();
    super.dispose();
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

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Enter a valid email to continue.');
      return;
    }

    setState(() {
      _stage = _Stage.loading;
      _errorMessage = null;
    });
    try {
      final result = await ShareFetchClient.instance.fetch(
        token: widget.token,
        viewerEmail: email,
      );
      final bytesRes = await http.get(Uri.parse(result.signedUrl));
      if (bytesRes.statusCode != 200) {
        throw Exception('Could not download the document.');
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _bytes = bytesRes.bodyBytes;
        _stage = _Stage.viewing;
      });
      if (result.viewEventId != null) {
        _startHeartbeat(result.viewEventId!);
      }
      // Deterrent layer for this viewing session — see WebSecurityGuard's
      // honesty-rule docs: this reduces casual leak paths and reports
      // devtools/visibility signals, it does not prevent screenshots.
      _webGuard.attach((eventType) {
        final eventId = _result?.viewEventId;
        if (eventId != null) {
          ShareHeartbeatClient.instance.sendHeartbeat(
            eventId,
            eventType: eventType,
          );
        }
        if (_concealTriggers.contains(eventType)) {
          _concealSignal.add(null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => ExperimentFrame(child: child ?? const SizedBox.shrink()),
      title: 'NO SUS — Secure Document',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: switch (_stage) {
            _Stage.emailGate => _buildEmailGate(),
            _Stage.loading => _buildLoading(),
            _Stage.error => _buildError(),
            _Stage.viewing => _buildViewer(),
          },
        ),
      ),
    );
  }

  Widget _buildEmailGate() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _NoSusWordmark(),
              const SizedBox(height: 36),
              Text(
                'You have been sent a document',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your email to open it. It will appear in the document\'s access activity.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: const TextStyle(color: Colors.white30),
                  errorText: _errorMessage,
                  errorStyle: const TextStyle(color: Colors.redAccent),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _submit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'OPEN DOCUMENT',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Opening document',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'This only takes a moment.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'This document is unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() {
                _stage = _Stage.emailGate;
                _errorMessage = null;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38, width: 1.2),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer() {
    final result = _result!;
    final bytes = _bytes!;
    final email = _emailController.text.trim();

    final watermarkConfig = WatermarkConfig(
      name: email,
      role: 'RECIPIENT',
      email: email,
      timestamp: DateTime.now().toIso8601String(),
    );

    Widget child;
    switch (result.fileType.toLowerCase()) {
      case 'pdf':
        child = PdfViewer.data(
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
        child = InteractiveViewer(child: Center(child: Image.memory(bytes)));
        break;
      default:
        child = const Center(
          child: Text(
            'This file type cannot be previewed in the browser.',
            style: TextStyle(fontSize: 13),
          ),
        );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  result.fileName,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                result.watermarkEnforced ? 'Watermarked' : 'View logged',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
        Expanded(
          child: SecureDocumentViewer(
            watermarkConfig: watermarkConfig,
            viewerConfig: const ViewerConfig(),
            touchToRevealEnabled: result.blurEnforced,
            watermarkEnabled: result.watermarkEnforced,
            forceConcealSignal: _concealSignal.stream,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _NoSusWordmark extends StatelessWidget {
  const _NoSusWordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NO SUS',
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          children: [
            TextSpan(text: 'NO SUS'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: EdgeInsets.only(left: 3),
                child: SizedBox(
                  width: 5,
                  height: 5,
                  child: ColoredBox(color: Color(0xFF808080)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
