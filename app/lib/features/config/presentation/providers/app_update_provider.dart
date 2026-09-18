import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/app_update.dart';
import 'config_provider.dart';

/// One-shot update check, evaluated once per app start (same point-in-time
/// contract as OfflineBanner's reachability flag — no polling).
///
/// The "latest version" comes from the app's own `remote_configs` table
/// (`app_latest_version`), never a third-party API — see
/// lib/features/config/domain/app_update.dart.
final appUpdateProvider = FutureProvider<AppUpdateStatus>((ref) async {
  // Web always runs the latest deploy, and there is no sideload/update path
  // on platforms other than Android.
  if (kIsWeb || !Platform.isAndroid) {
    return const AppUpdateNotApplicable();
  }

  final service = ref.watch(remoteConfigServiceProvider);
  await service.ensureInitialized();

  final latest = service.getConfigValue<String>(
    SecureSendConfigs.appLatestVersion.key,
    '',
  );
  if (latest.trim().isEmpty) {
    // Latest version unknown (config row missing or fetch failed) — stay
    // quiet rather than guessing.
    return const AppUpToDate();
  }

  final info = await PackageInfo.fromPlatform();
  if (compareVersions(latest, info.version) > 0) {
    final downloadUrl = service.getConfigValue<String>(
      SecureSendConfigs.appDownloadUrl.key,
      SecureSendConfigs.appDownloadUrl.defaultValue as String,
    );
    return AppUpdateAvailable(latestVersion: latest, downloadUrl: downloadUrl);
  }
  return const AppUpToDate();
});
