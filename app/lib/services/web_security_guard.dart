import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'automation_signal_stub.dart'
    if (dart.library.js_interop) 'automation_signal_web.dart';

/// Browser-side deterrent layer for documents rendered in Flutter Web.
///
/// HONESTY RULE (matches anonymous_share_viewer_screen.dart): none of this
/// *prevents* screenshots, and a determined user can still open real
/// browser DevTools and inspect network traffic. What this actually buys:
///
/// - Removes the "right-click > Save As" / Ctrl+P / Ctrl+S paths a casual
///   user would otherwise reach for first.
/// - Surfaces a best-effort DevTools-open heuristic and repeated
///   tab-visibility switching as forensic signals (reported upstream via
///   [onSuspicious], not blocked — you cannot block a user from opening
///   DevTools from page JS).
/// - Never touches INPUT/TEXTAREA elements, so the email-gate form on the
///   anonymous share screen keeps working normally.
///
/// Each protection is an independent flag so callers can opt out of ones
/// that conflict with an intentional UX choice — e.g. burn_note_viewer_screen
/// uses `SelectableText` on purpose (a recipient may need to copy a
/// password), so it enables blockRightClick/blockPrint/blockSave/blockDrag
/// but leaves blockCopy/blockSelect off.
///
/// NOT covered here, and not coverable from page JS at all: OS-level
/// screenshot tools, OS/extension-level screen recording, a `<canvas>`
/// pixel dump via DevTools console (`toDataURL()` — this app's CanvasKit
/// web build renders the whole UI to one canvas, so this is the single
/// most severe residual web vector once DevTools is open), and an external
/// camera. See the threat-model breakdown this class's callers were built
/// against for the full enumeration.
class WebSecurityGuard {
  WebSecurityGuard({
    this.blockRightClick = true,
    this.blockCopy = true,
    this.blockCut = true,
    this.blockPrint = true,
    this.blockSave = true,
    this.blockDrag = true,
    this.blockSelect = true,
    this.detectDevTools = true,
    this.detectVisibilityChanges = true,
    this.detectAutomation = true,
  });

  final bool blockRightClick;
  final bool blockCopy;
  final bool blockCut;
  final bool blockPrint;
  final bool blockSave;
  final bool blockDrag;
  final bool blockSelect;
  final bool detectDevTools;
  final bool detectVisibilityChanges;
  final bool detectAutomation;

  /// DevTools' docked-panel width/height heuristic. Undocked (separate
  /// window) DevTools defeats this entirely — that limitation is inherent
  /// to any page-JS-based check, not specific to this implementation.
  static const _devToolsThresholdPx = 160;
  static const _devToolsPollInterval = Duration(seconds: 2);

  /// Reporting one repeated-visibility-switch event per this window avoids
  /// spamming the ledger every time a user legitimately alt-tabs once.
  static const _visibilityWindow = Duration(seconds: 30);
  static const _visibilityThreshold = 3;

  final List<html.EventListener> _cleanups = [];
  Timer? _devToolsTimer;
  bool _devToolsReported = false;
  final List<DateTime> _hiddenTimestamps = [];
  bool _attached = false;
  html.StyleElement? _printStyleEl;

  bool _isFormField(html.EventTarget? target) {
    if (target is! html.Element) return false;
    final tag = target.tagName.toUpperCase();
    return tag == 'INPUT' || tag == 'TEXTAREA';
  }

  /// Starts listening. [onSuspicious] is called with a stable event-type
  /// string (matching the share-heartbeat allowlist) whenever a deterrent
  /// fires or a detection heuristic trips.
  void attach(void Function(String eventType) onSuspicious) {
    if (!kIsWeb || _attached) return;
    _attached = true;

    if (blockRightClick) {
      _listen(html.document, 'contextmenu', (e) {
        if (_isFormField(e.target)) return;
        e.preventDefault();
        onSuspicious('right_click_attempted');
      });
    }

    if (blockCopy) {
      _listen(html.document, 'copy', (e) {
        if (_isFormField(e.target)) return;
        e.preventDefault();
        onSuspicious('copy_attempted');
      });
    }

    if (blockCut) {
      _listen(html.document, 'cut', (e) {
        if (_isFormField(e.target)) return;
        e.preventDefault();
      });
    }

    if (blockDrag) {
      _listen(html.document, 'dragstart', (e) {
        if (_isFormField(e.target)) return;
        e.preventDefault();
        onSuspicious('drag_attempted');
      });
    }

    if (blockSelect) {
      _listen(html.document, 'selectstart', (e) {
        if (_isFormField(e.target)) return;
        e.preventDefault();
      });
    }

    if (blockPrint) {
      // The keydown listener below only catches Ctrl+P/Cmd+P. A print
      // triggered from the browser's File menu (or a raw window.print()
      // call) never fires a keydown at all — this print stylesheet closes
      // that gap regardless of how printing was invoked, since the browser
      // applies @media print rules independent of the trigger path.
      final style = html.StyleElement()
        ..id = 'nosus-print-block'
        ..text = '@media print { html, body { visibility: hidden !important; } }';
      html.document.head?.append(style);
      _printStyleEl = style;
    }

    if (detectAutomation) {
      // A one-time check, not polled — navigator.webdriver is fixed for the
      // lifetime of the page. See automation_signal_web.dart for why this
      // can't just use universal_html's own (non-functional) getter.
      if (readNavigatorWebdriverFlag() == true) {
        onSuspicious('automation_detected');
      }
    }

    if (blockPrint || blockSave) {
      _listen(html.document, 'keydown', (e) {
        final ev = e as html.KeyboardEvent;
        final ctrlOrMeta = ev.ctrlKey || ev.metaKey;
        if (!ctrlOrMeta) return;

        final key = ev.key?.toLowerCase();
        if (blockPrint && key == 'p') {
          e.preventDefault();
          onSuspicious('print_attempted');
        } else if (blockSave && key == 's') {
          e.preventDefault();
          onSuspicious('save_attempted');
        }
      });
    }

    if (detectVisibilityChanges) {
      _listen(html.document, 'visibilitychange', (_) {
        if (html.document.visibilityState != 'hidden') return;
        final now = DateTime.now();
        _hiddenTimestamps.add(now);
        _hiddenTimestamps.removeWhere(
          (t) => now.difference(t) > _visibilityWindow,
        );
        if (_hiddenTimestamps.length >= _visibilityThreshold) {
          onSuspicious('visibility_hidden_repeated');
          _hiddenTimestamps.clear();
        }
      });
    }

    if (detectDevTools) {
      _devToolsTimer = Timer.periodic(_devToolsPollInterval, (_) {
        if (_devToolsReported) return;
        final widthDiff = html.window.outerWidth - (html.window.innerWidth ?? 0);
        final heightDiff = html.window.outerHeight - (html.window.innerHeight ?? 0);
        if (widthDiff > _devToolsThresholdPx || heightDiff > _devToolsThresholdPx) {
          _devToolsReported = true;
          onSuspicious('devtools_detected');
        }
      });
    }
  }

  void _listen(
    html.EventTarget target,
    String type,
    void Function(html.Event) handler,
  ) {
    target.addEventListener(type, handler);
    _cleanups.add(handler);
    _listenerTargets.add(target);
    _listenerTypes.add(type);
  }

  final List<html.EventTarget> _listenerTargets = [];
  final List<String> _listenerTypes = [];

  /// Removes every listener and stops the DevTools poll. Must be called
  /// from the owning widget's dispose() — leaked document-level listeners
  /// would otherwise keep firing (and holding a closure over disposed
  /// state) for the lifetime of the page.
  void detach() {
    if (!_attached) return;
    _attached = false;

    for (var i = 0; i < _cleanups.length; i++) {
      _listenerTargets[i].removeEventListener(_listenerTypes[i], _cleanups[i]);
    }
    _cleanups.clear();
    _listenerTargets.clear();
    _listenerTypes.clear();

    _devToolsTimer?.cancel();
    _devToolsTimer = null;
    _devToolsReported = false;
    _hiddenTimestamps.clear();

    _printStyleEl?.remove();
    _printStyleEl = null;
  }
}
