/// Non-web fallback. Automation/headless-browser signals only exist in a
/// browser context — see automation_signal_web.dart for the real
/// implementation, selected via conditional import in web_security_guard.dart.
bool? readNavigatorWebdriverFlag() => null;
