/// Web and non-Android fallback for optional Measure reporting.
///
/// Keeping this no-op in a separate conditional implementation means the web
/// compiler never resolves the Android-only `measure_flutter` package.
Future<void> initializeMeasureReporting() async {}
