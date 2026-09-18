import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../features/files/presentation/providers/secure_file_providers.dart';
import 'secure_viewer/models/watermark_config.dart';
import 'secure_viewer/models/viewer_config.dart';
import 'secure_viewer/secure_document_viewer.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:screen_protector/screen_protector.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/profile/providers/profile_provider.dart';
import '../features/profile/providers/settings_provider.dart';
import '../services/screenshot_guard.dart';
import '../services/audit_service.dart';
import '../services/device_integrity_service.dart';
import '../features/auth/presentation/providers/risk_state_provider.dart';

// ─── User identity resolved from live auth providers ────────────────────────

/// The full-screen secure document viewer page.
///
/// Loads, renders, and purges volatile document bytes from memory upon exit.
class SpyglassViewer extends ConsumerStatefulWidget {
  final String? fileId;
  final String? groupId;
  final String? email;
  final String? phone;
  final String? documentTitle;
  final String? documentCategory;

  const SpyglassViewer({
    super.key,
    this.fileId,
    this.groupId,
    this.email,
    this.phone,
    this.documentTitle,
    this.documentCategory,
  });

  @override
  ConsumerState<SpyglassViewer> createState() => _SpyglassViewerState();
}

class _SpyglassViewerState extends ConsumerState<SpyglassViewer> {
  final String _sessionTimestamp = _buildTimestamp();
  bool _isLoading = true;
  String _documentContent = '';
  double _streamProgress = 0.0;
  String _loadingStatus = 'Requesting secure proxy...';
  bool _isPdf = false;
  bool _isImage = false;
  bool _downloadFailed = false;
  Uint8List? _documentBytes;

  static String _buildTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}:${_pad(now.minute)} IST';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ));

    // Register active document context for screenshot/recording audit logs
    ScreenshotGuard.instance.activeGroupId = widget.groupId;
    ScreenshotGuard.instance.activeFileId = widget.fileId;
    ScreenshotGuard.instance.activeFileName = widget.documentTitle;

    _initScreenshotProtection();
    _loadSecureEnclavePayload();

    // Display-mirroring / accessibility-abuse check for this viewing
    // session — logged into this group's tamper-evident audit trail.
    unawaited(DeviceIntegrityService.instance.runViewingChecks(
      groupId: widget.groupId,
      fileId: widget.fileId,
    ));
  }

  Future<void> _initScreenshotProtection() async {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageOn();
  }

  @override
  void dispose() {
    // Clear active document context from screenshot audit logger
    ScreenshotGuard.instance.activeGroupId = null;
    ScreenshotGuard.instance.activeFileId = null;
    ScreenshotGuard.instance.activeFileName = null;

    _documentBytes = null;
    ScreenProtector.preventScreenshotOff();
    ScreenProtector.protectDataLeakageOff();
    super.dispose();
  }

  Future<void> _loadSecureEnclavePayload() async {
    Uint8List? plainBytes;

    if (widget.fileId != null) {
      setState(() {
        _loadingStatus = 'Connecting to secure repository...';
      });
      
      final streamedBytes = await ref.read(secureFileRepositoryProvider).downloadFile(
        fileId: widget.fileId!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _streamProgress = progress;
              _loadingStatus = 'Downloading: ${(progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (streamedBytes != null) {
        if (mounted) {
          setState(() {
            _loadingStatus = 'Loading document...';
          });
        }
        plainBytes = streamedBytes;
      }
    }

    bool downloadFailed = false;

    if (plainBytes == null && widget.fileId != null) {
      downloadFailed = true;
      if (widget.groupId != null) {
        AuditService.instance.logEvent(
          'download_failed',
          'FAILURE',
          groupId: widget.groupId!,
          fileId: widget.fileId,
          metadata: {'file_name': widget.documentTitle ?? 'document'},
        );
      }
    }

    bool isPdfFile = false;
    if (plainBytes != null &&
        plainBytes.length >= 4 &&
        plainBytes[0] == 0x25 &&
        plainBytes[1] == 0x50 &&
        plainBytes[2] == 0x44 &&
        plainBytes[3] == 0x46) {
      isPdfFile = true;
    } else if (plainBytes != null && widget.documentCategory == 'PDF' && !downloadFailed) {
      isPdfFile = true;
    }

    // Detect Image by magic bytes or category
    bool isImageFile = false;
    if (plainBytes != null &&
        plainBytes.length >= 3 &&
        plainBytes[0] == 0xFF &&
        plainBytes[1] == 0xD8 &&
        plainBytes[2] == 0xFF) { // JPEG
      isImageFile = true;
    } else if (plainBytes != null &&
        plainBytes.length >= 4 &&
        plainBytes[0] == 0x89 &&
        plainBytes[1] == 0x50 &&
        plainBytes[2] == 0x4E &&
        plainBytes[3] == 0x47) { // PNG
      isImageFile = true;
    } else if (plainBytes != null && (widget.documentCategory == 'IMAGE' || widget.documentCategory == 'SCAN') && !downloadFailed) {
      isImageFile = true;
    }

    String decoded = '';
    if (plainBytes != null && !isPdfFile && !isImageFile) {
      try {
        decoded = utf8.decode(plainBytes);
      } catch (_) {
        decoded = '[SECURED DOCUMENT PREVIEW]\nThis document is a binary PDF/media asset loaded securely inside the RAM buffer.';
      }
    }

    if (mounted) {
      setState(() {
        _isPdf = isPdfFile;
        _isImage = isImageFile;
        _documentContent = decoded;
        _documentBytes = plainBytes;
        _downloadFailed = downloadFailed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;

    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(profileProvider);
    final isWatermarkVisible = ref.watch(watermarkVisibilityProvider);

    final String userEmail = authState.value?.email ?? widget.email ?? 'student@nosus.app';
    final String displayName = profileAsync.maybeWhen(
      data: (p) => p.displayName,
      orElse: () => userEmail.contains('@') ? userEmail.split('@').first : 'Guest Scholar',
    );

    final watermarkIntensity =
        ref.watch(riskStateProvider).value?.watermarkIntensity ?? 'normal';
    final watermarkConfig = WatermarkConfig(
      name: displayName.toUpperCase(),
      role: 'SECURE MEMBER',
      email: userEmail,
      timestamp: _sessionTimestamp,
      opacity: isWatermarkVisible ? 0.14 : 0.0,
      fontSize: 12.0,
      angleDegrees: -28.0,
    ).scaledForIntensity(watermarkIntensity);

    const viewerConfig = ViewerConfig(
      maxBlurSigma: 22.0,
      revealDuration: Duration(milliseconds: 115),
      concealDuration: Duration(milliseconds: 210),
      revealCurve: Curves.easeOut,
      concealCurve: Curves.easeIn,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fg, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.documentTitle ?? 'Study Notes',
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            if (widget.documentCategory != null)
              Text(
                widget.documentCategory!,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: fg.withValues(alpha: 0.18), width: 0.75),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 11, color: fg.withValues(alpha: 0.5)),
                const SizedBox(width: 5),
                Text(
                  'SECURE',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: fg.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                    if (widget.fileId != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _streamProgress,
                          backgroundColor: fg.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(fg.withValues(alpha: 0.6)),
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : _downloadFailed
              ? _buildDownloadFailedBody(fg)
              : _buildDocumentBody(watermarkConfig, viewerConfig, isDark, fg, bg),
    );
  }

  Widget _buildDownloadFailedBody(Color fg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: fg.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'DOWNLOAD FAILED',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: fg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The document could not be loaded.\n\nPlease verify your connection and ensure you are a registered enclave member of this study group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: fg.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBody(
    WatermarkConfig watermarkConfig,
    ViewerConfig viewerConfig,
    bool isDark,
    Color fg,
    Color bg,
  ) {
    final buffer = _documentBytes;

    // Null guard — if buffer was purged (e.g. widget re-entry) show a safe error state.
    if (buffer == null && (_isPdf || _isImage)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_reset_outlined, size: 36, color: fg.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'SESSION EXPIRED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: fg.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document buffer was purged.\nReturn and open the document again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return SecureDocumentViewer(
      watermarkConfig: watermarkConfig,
      viewerConfig: viewerConfig,
      showHint: true,
      touchToRevealEnabled: ref.watch(touchToRevealProvider),
      child: _isPdf
          ? PdfViewer.data(
              buffer!,
              sourceName: widget.documentTitle ?? 'document.pdf',
              // Text selection off: it's a copy-out leak in a protected
              // viewer, and pdfrx 2.4.4's selection painter crashes on
              // pages with no extractable text (StateError: No element).
              params: const PdfViewerParams(
                textSelectionParams: PdfTextSelectionParams(enabled: false),
              ),
            )
          : _isImage
              ? InteractiveViewer(
                  child: Center(
                    child: Image.memory(buffer!),
                  ),
                )
              : _DocumentContent(
                  isDark: isDark,
                  fg: fg,
                  bg: bg,
                  text: _documentContent,
                ),
    );
  }
}

// ─── Demo Document Content ────────────────────────────────────────────────────

class _DocumentContent extends StatelessWidget {
  final bool isDark;
  final Color fg;
  final Color bg;
  final String text;

  const _DocumentContent({
    required this.isDark,
    required this.fg,
    required this.bg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = fg.withValues(alpha: 0.08);
    final subtleColor = fg.withValues(alpha: 0.45);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    final paragraphs = text.split('\n\n');

    return SingleChildScrollView(
      physics: NoSusTheme.getScrollPhysics(context),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocHeader(
            subject: 'DOCUMENT VIEWER',
            chapter: paragraphs.isNotEmpty ? paragraphs.first.split('\n').first : 'Document Content',
            date: 'SECURE VIEWER',
            fg: fg,
            subtleColor: subtleColor,
          ),
          const SizedBox(height: 28),
          Divider(color: dividerColor, thickness: 0.5),
          const SizedBox(height: 28),
          for (final p in paragraphs) ...[
            if (p.trim().isNotEmpty) ...[
              _renderParagraph(p, cardBg, dividerColor),
              const SizedBox(height: 24),
            ],
          ],
          const SizedBox(height: 40),
          Center(
            child: Text(
              '— DOCUMENT CLEARED ON EXIT —',
              style: TextStyle(
                color: subtleColor,
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _renderParagraph(String p, Color cardBg, Color dividerColor) {
    final lines = p.split('\n');
    final title = lines.first;
    final body = lines.skip(1).join('\n');

    if (body.isEmpty) {
      return Text(
        title,
        style: TextStyle(
          color: fg.withValues(alpha: 0.8),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.75,
        ),
      );
    }

    return _Section(
      title: title,
      body: body,
      fg: fg,
      subtleColor: fg.withValues(alpha: 0.45),
      cardBg: cardBg,
      dividerColor: dividerColor,
    );
  }
}

// ─── Document sub-widgets ─────────────────────────────────────────────────────

class _DocHeader extends StatelessWidget {
  final String subject;
  final String chapter;
  final String date;
  final Color fg;
  final Color subtleColor;

  const _DocHeader({
    required this.subject,
    required this.chapter,
    required this.date,
    required this.fg,
    required this.subtleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subject.toUpperCase(),
          style: TextStyle(
            color: subtleColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          chapter,
          style: TextStyle(
            color: fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          date,
          style: TextStyle(
            color: subtleColor,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final Color fg;
  final Color subtleColor;
  final Color cardBg;
  final Color dividerColor;

  const _Section({
    required this.title,
    required this.body,
    required this.fg,
    required this.subtleColor,
    required this.cardBg,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: fg,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: TextStyle(
            color: fg.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.75,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
