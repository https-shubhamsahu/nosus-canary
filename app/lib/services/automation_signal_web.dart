// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';

/// Reads the real, standardized `navigator.webdriver` property via static
/// JS interop. universal_html's own `Navigator.webdriver` getter is a stub
/// that always returns null regardless of platform — it does not forward to
/// the browser's actual property — so it's useless for real detection and
/// must be bypassed here. This file is only ever compiled in on web builds,
/// selected via the conditional import in web_security_guard.dart.
@JS('navigator.webdriver')
external JSBoolean? get _webdriverFlag;

bool? readNavigatorWebdriverFlag() {
  try {
    return _webdriverFlag?.toDart;
  } catch (_) {
    return null;
  }
}
