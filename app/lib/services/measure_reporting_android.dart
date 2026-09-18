import 'package:measure_flutter/measure_flutter.dart';

import '../config/measure_reporting_config.dart';

/// Starts Measure only for a configured Android build.
///
/// This stays after the app's FlutterError handler has been installed in
/// `main.dart`, so Measure can chain it rather than replacing it.
Future<void> initializeMeasureReporting() async {
  if (!MeasureReportingConfig.isEnabled) return;

  await Measure.instance.init(
    () {},
    config: const MeasureConfig(autoStart: false),
  );
  await Measure.instance.start();
}
