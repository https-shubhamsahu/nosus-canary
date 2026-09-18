// Domain model for the in-app update check.
//
// The latest released version is published to the `app_latest_version` row
// in `remote_configs` as part of the release flow (see CLAUDE.md, CI
// section) — the app never calls out to GitHub or any other third party to
// learn about updates, consistent with the product's privacy stance.

/// Compares two dotted version strings numerically, segment by segment.
///
/// Returns a negative number if [a] < [b], zero if equal, positive if
/// [a] > [b]. Tolerates a leading `v`/`V` and unequal segment counts
/// ("1.2" == "1.2.0"). Non-numeric segments are treated as 0.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();

  final pa = parse(a);
  final pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

/// Outcome of an update check.
sealed class AppUpdateStatus {
  const AppUpdateStatus();
}

/// The check doesn't apply on this platform (web always runs the latest
/// deploy; there is no sideload path outside Android).
class AppUpdateNotApplicable extends AppUpdateStatus {
  const AppUpdateNotApplicable();
}

/// Installed version is current (or the latest version is unknown).
class AppUpToDate extends AppUpdateStatus {
  const AppUpToDate();
}

/// A newer version exists.
class AppUpdateAvailable extends AppUpdateStatus {
  final String latestVersion;
  final String downloadUrl;
  const AppUpdateAvailable({required this.latestVersion, required this.downloadUrl});
}
