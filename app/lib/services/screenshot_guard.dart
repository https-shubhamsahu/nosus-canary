import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../core/utils/debug_logger.dart';
import 'audit_service.dart';

class ScreenshotGuard {
  ScreenshotGuard._();
  static final ScreenshotGuard instance = ScreenshotGuard._();

  static const _channel = MethodChannel('co.nosus.app/security');
  static const _eventChannel = EventChannel('co.nosus.app/screenshot');

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // Active secure context fields for security audit logging
  String? activeGroupId;
  String? activeFileId;
  String? activeFileName;
  bool _isDialogShowing = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;


    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}

    // Listen to screenshot/recording/overlay events
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      final type = event['type'] as String?;
      if (type == 'screenshot' || type == 'recording') {
        _showFunnyPopup(type!);
      } else if (type == 'overlay_detected') {
        _logOverlayDetected();
      }
    }, onError: (err) {
      debugLog("ScreenshotGuard event error: $err");
    });
  }

  void _logOverlayDetected() {
    if (activeGroupId == null) return;
    AuditService.instance.logEvent(
      'overlay_detected',
      'SECURITY',
      groupId: activeGroupId!,
      fileId: activeFileId,
      metadata: {'file_name': activeFileName ?? 'Vault Dashboard'},
    );
  }

  void _showFunnyPopup(String type) {
    if (_isDialogShowing) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    _isDialogShowing = true;

    // Log the screenshot or recording attempt to the secure audit logs if group ID is available
    if (activeGroupId != null) {
      AuditService.instance.logEvent(
        type == 'recording' ? 'recording_attempt' : 'screenshot_attempt',
        'SECURITY',
        groupId: activeGroupId!,
        fileId: activeFileId,
        metadata: {'file_name': activeFileName ?? 'Vault Dashboard'},
      );
    }

    final messages = type == 'recording'
        ? [
            "Stop recording! 🎥 No bootleg tapes of NO SUS! 🙅‍♂️",
            "Screen recording detected! 🚨 Our secrets are not for your movie! 🍿",
            "Are you filming a documentary? 🕵️‍♂️ No recordings of the vault! 🔐",
            "Nice try recording, but we've gone incognito! 🕶️",
          ]
        : [
            "Caught in 4K! 📸 Nice try, but NO SUS allowed here! 🙅‍♂️",
            "Whoa there, inspector! 🕵️‍♂️ No screenshots of the vault! 🔐",
            "Trying to leak the secret sauce? 🧪 Not on our watch! 🤫",
            "Nice screenshot attempt! 📸 But we've blurred the evidence! 💨",
            "Access Denied! 🚫 Did you think it was that easy? 😏",
            "Selfie with the vault? 🤳 Not today, buddy! 🙅‍♀️",
          ];

    final randomMessage = messages[Random().nextInt(messages.length)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0xFF1A1A1A),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.redAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  type == 'recording' ? 'RECORDING DETECTED' : 'SCREENSHOT DETECTED',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  randomMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? NoSusTheme.dText : NoSusTheme.lText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _isDialogShowing = false;
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      "UNDERSTOOD",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }
}

