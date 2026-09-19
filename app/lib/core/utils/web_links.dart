import 'package:flutter/foundation.dart';

/// Where the Flutter web app lives in production. The marketing landing page
/// owns the bare `nosus.foo` root; the app is served from this subdomain.
/// The landing page carries a forwarding shim, so legacy `nosus.foo/#/...`
/// links (shared before the split) still resolve into the app here.
/// Override at build time for the APK, e.g.
/// --dart-define=WEB_APP_ORIGIN=https://https-shubhamsahu.github.io
const String kWebAppOrigin = String.fromEnvironment(
  'WEB_APP_ORIGIN',
  defaultValue: 'http://shubham-sahu.me',
);

/// The path prefix the Flutter web app is deployed under on [kWebAppOrigin].
/// Empty — the app sits at the subdomain root.
/// Override at build time, e.g. --dart-define=WEB_APP_BASE_PATH=/nosus-canary
/// (leading slash, no trailing slash).
const String kWebAppBasePath = String.fromEnvironment('WEB_APP_BASE_PATH');

/// Origin + base path to prefix any deep link shared out of the app with.
///
/// On web, [Uri.base] already reflects wherever this session is actually
/// running (a local dev server, a PR preview, production) so the base path
/// is derived from the current URL rather than hardcoded. On native, there
/// is no "current URL": every generated link must point at the fixed
/// production location instead, via [kWebAppOrigin]/[kWebAppBasePath].
({String origin, String basePath}) webShareLinkBase() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    final basePath = Uri.base.path
        .replaceAll('index.html', '')
        .replaceAll(RegExp(r'/$'), '');
    return (origin: origin, basePath: basePath);
  }
  return (origin: kWebAppOrigin, basePath: kWebAppBasePath);
}
