import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/debug_logger.dart';
import 'audit_service.dart';
import 'supabase_service.dart';

/// Aggregates device/session-level tamper signals from the native Android
/// scanner (root, Frida/Xposed/LSPosed instrumentation, display mirroring,
/// accessibility-service abuse).
///
/// Two different findings get logged to two different ledgers, deliberately:
///
/// - Root/instrumentation are properties of the *device*, not of any one
///   group action, so [runStartupChecks] writes them to the self-scoped
///   `device_integrity_events` hash chain (see [SupabaseService.logDeviceIntegrityEvent]).
/// - Display mirroring and accessibility abuse are checked per viewing
///   session in [runViewingChecks] and logged into the existing group-scoped
///   `audit_logs` chain via [AuditService], exactly like screenshot_attempt —
///   because "was someone mirroring my screen while I viewed this document"
///   is a fact about that document's audit trail, not about the device.
///
/// Policy for this app (see project decision): findings are logged, not used
/// to block access — a false positive (e.g. a legitimately rooted power-user
/// phone) should never lock a user out of their own notes.
class DeviceIntegrityService {
  DeviceIntegrityService._();
  static final DeviceIntegrityService instance = DeviceIntegrityService._();

  static const _channel = MethodChannel('co.nosus.app/device_integrity');
  static const _deviceIdPrefsKey = 'nosus_device_id_v1';
  static const _deviceIdMigratedPrefsKey = 'nosus_device_id_migrated_v2';

  String? _deviceId;
  String? _deviceIdSecurityLevel;
  bool _startupScanDone = false;
  bool _deviceRegistered = false;

  /// How the current [deviceId] is backed: 'strongbox', 'tee', 'software',
  /// 'unknown', or null on the legacy/non-Android path. Null or 'software'
  /// means the id is not hardware-protected and carries no more weight than
  /// the old random UUID did — don't present it as if it does.
  String? get deviceIdSecurityLevel => _deviceIdSecurityLevel;

  /// Stable per-install identifier. Deliberately *not* a hardware ID
  /// (IMEI/serial/etc.) — this app doesn't collect those, in keeping with the
  /// no-third-party-tracking privacy stance (see web/privacy.html). It only
  /// needs to be stable enough to notice "this same device flagged again" and
  /// "multiple devices for one user".
  ///
  /// On Android this is the digest of a non-extractable Keystore key, so it
  /// survives no better than the app's data but can't be edited into a
  /// different value or copied to another device — which the previous
  /// prefs-stored UUID could, defeating both of the detectors above on
  /// exactly the rooted devices they target. Web, iOS, and any Android device
  /// whose Keystore is unusable keep the original UUID behaviour.
  Future<String> get deviceId async {
    if (_deviceId != null) return _deviceId!;

    final hardwareId = await _hardwareDeviceId();
    if (hardwareId != null) {
      _deviceId = hardwareId;
      return hardwareId;
    }

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdPrefsKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdPrefsKey, id);
    }
    _deviceId = id;
    return id;
  }

  /// Null whenever a hardware-backed id can't be produced — non-Android, or
  /// a Keystore that failed outright. Never throws: an unusable Keystore must
  /// degrade to the legacy id, not break launch.
  Future<String?> _hardwareDeviceId() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod('getDeviceKeyId');
      if (raw is! Map) return null;
      final result = Map<String, dynamic>.from(raw);
      final id = result['deviceId'];
      if (id is! String || id.isEmpty) return null;
      _deviceIdSecurityLevel = result['securityLevel'] as String?;
      // Level only, never the id itself — the id is a stable per-device
      // identifier and logcat is readable by any debug tooling on the box.
      debugLog('DeviceIntegrityService: device id backing=$_deviceIdSecurityLevel');
      return id;
    } catch (e) {
      debugLog('DeviceIntegrityService: hardware device id unavailable: $e');
      return null;
    }
  }

  /// One-time move of this device's server-side history from the legacy UUID
  /// onto the hardware-backed id. Runs from [registerDeviceSeen] rather than
  /// the [deviceId] getter because it needs an authenticated session, and
  /// only sets the completion flag on success so a transient failure retries
  /// on the next launch instead of silently orphaning the old row.
  ///
  /// Returns whether it's safe to register [currentId] now. False means a
  /// migration was genuinely needed and failed — registering anyway would
  /// make this already-known device look new and write a false
  /// 'multiple_device_access' into an append-only hash chain that can't be
  /// retracted. Skipping one session's `last_seen_at` refresh is the cheaper
  /// error; the next launch retries.
  Future<bool> _migrateLegacyDeviceId(String currentId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_deviceIdMigratedPrefsKey) == true) return true;

    final legacyId = prefs.getString(_deviceIdPrefsKey);
    if (legacyId == null || legacyId == currentId) {
      await prefs.setBool(_deviceIdMigratedPrefsKey, true);
      return true;
    }

    final migrated = await SupabaseService.instance.migrateDeviceId(
      oldDeviceId: legacyId,
      newDeviceId: currentId,
    );
    if (migrated) {
      await prefs.setBool(_deviceIdMigratedPrefsKey, true);
    }
    return migrated;
  }

  Future<Map<String, dynamic>?> _runNativeScan() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod('runChecks');
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } catch (e) {
      debugLog('DeviceIntegrityService: native scan failed: $e');
      return null;
    }
  }

  /// Call once per app launch (see main.dart). Fire-and-forget — never
  /// awaited by startup code, since file/socket probing shouldn't delay
  /// first paint.
  Future<void> runStartupChecks() async {
    if (_startupScanDone) return;
    _startupScanDone = true;

    final result = await _runNativeScan();
    if (result == null) return;

    final id = await deviceId;

    final root = Map<String, dynamic>.from(result['root'] as Map? ?? {});
    if (root['rooted'] == true) {
      await SupabaseService.instance.logDeviceIntegrityEvent(
        eventType: 'root_detected',
        severity: 'warning',
        deviceId: id,
        metadata: {'reasons': root['reasons']},
      );
    }

    final instrumentation =
        Map<String, dynamic>.from(result['instrumentation'] as Map? ?? {});
    if (instrumentation['instrumented'] == true) {
      await SupabaseService.instance.logDeviceIntegrityEvent(
        eventType: 'tamper_detected',
        severity: 'critical',
        deviceId: id,
        metadata: {'reasons': instrumentation['reasons']},
      );
    }
  }

  /// Call once per app session, right after a user is confirmed signed in
  /// (see AuthGate) — needs auth.uid() server-side, so it can't run before
  /// that. Platform-agnostic (works on web too, unlike the native root/
  /// instrumentation scan): just a persisted device id + a Supabase RPC.
  Future<void> registerDeviceSeen() async {
    if (_deviceRegistered) return;
    _deviceRegistered = true;
    try {
      final id = await deviceId;
      // Must precede the register call: it renames the existing row, so
      // running it after would leave register_device_seen() to see the new id
      // as unknown and log a spurious 'multiple_device_access'. If it was
      // needed and failed, don't register at all this session — see the
      // method's doc comment.
      if (!await _migrateLegacyDeviceId(id)) {
        _deviceRegistered = false;
        return;
      }
      await SupabaseService.instance.registerDeviceSeen(id);
    } catch (e) {
      debugLog('DeviceIntegrityService: registerDeviceSeen failed: $e');
    }
  }

  /// Call when a sensitive viewer (Spyglass, secure notes, etc.) opens.
  /// Checks display mirroring + accessibility abuse *for this viewing
  /// session* and logs into the group's tamper-evident audit trail.
  Future<void> runViewingChecks({
    required String? groupId,
    String? fileId,
  }) async {
    if (groupId == null) return;

    final result = await _runNativeScan();
    if (result == null) return;

    final mirroring =
        Map<String, dynamic>.from(result['displayMirroring'] as Map? ?? {});
    if (mirroring['mirroring'] == true) {
      AuditService.instance.logEvent(
        'display_mirroring_detected',
        'SECURITY',
        groupId: groupId,
        fileId: fileId,
        metadata: {'displays': mirroring['displays']},
      );
    }

    final accessibility =
        Map<String, dynamic>.from(result['accessibility'] as Map? ?? {});
    if (accessibility['suspiciousServicesFound'] == true) {
      AuditService.instance.logEvent(
        'accessibility_detected',
        'SECURITY',
        groupId: groupId,
        fileId: fileId,
        metadata: {'services': accessibility['services']},
      );
    }
  }
}
