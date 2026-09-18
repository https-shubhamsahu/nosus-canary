package foo.nosus.app.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.File

/**
 * Heuristic root detection. No single check here is authoritative — a
 * determined attacker with Magisk's DenyList/Zygisk hiding enabled can evade
 * every file-path and package check below. These findings feed risk scoring
 * as signals, not a hard gate: see DeviceIntegrityService (Dart side) for
 * the "log, don't block" policy this project has chosen.
 */
object RootDetector {

    private val ROOT_PATHS = arrayOf(
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/su/bin/su",
        "/system/app/Superuser.apk",
        "/system/app/SuperSU",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/system/xbin/busybox",
        "/data/local/su"
    )

    private val ROOT_PACKAGES = arrayOf(
        "com.topjohnwu.magisk",
        "eu.chainfire.supersu",
        "com.noshufou.android.su",
        "com.koushikdutta.superuser",
        "com.thirdparty.superuser",
        "com.yellowes.su",
        "me.phh.superuser",
        "com.kingroot.kinguser",
        "com.kingouser.com",
        "com.smedialink.oneclickroot",
        "com.zhiqupk.root.global",
        "com.alephzain.framaroot"
    )

    fun scan(context: Context): Map<String, Any?> {
        val reasons = mutableListOf<String>()

        if (Build.TAGS?.contains("test-keys") == true) {
            reasons.add("test-keys build signature")
        }

        for (path in ROOT_PATHS) {
            if (File(path).exists()) {
                reasons.add("root binary present: $path")
                break // one hit is enough signal — avoid noisy metadata
            }
        }

        val pm = context.packageManager
        for (pkg in ROOT_PACKAGES) {
            try {
                pm.getPackageInfo(pkg, 0)
                reasons.add("root management app installed: $pkg")
            } catch (_: PackageManager.NameNotFoundException) {
                // Not installed — expected on clean devices.
            }
        }

        try {
            val buildProp = File("/system/build.prop")
            if (buildProp.exists() && buildProp.canWrite()) {
                reasons.add("system partition writable")
            }
        } catch (_: SecurityException) {
            // Sandbox denies the check — inconclusive, not a finding.
        }

        return mapOf(
            "rooted" to reasons.isNotEmpty(),
            "reasons" to reasons
        )
    }
}
