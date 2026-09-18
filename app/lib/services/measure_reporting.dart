// Platform-safe entry point for the optional Android Measure integration.
//
// `measure_flutter` currently contains JavaScript-incompatible code, so a
// direct import would fail every Flutter web build even when reporting is
// disabled. Conditional export keeps the Android implementation out of the
// web program entirely.
export 'measure_reporting_stub.dart'
    if (dart.library.io) 'measure_reporting_android.dart';
