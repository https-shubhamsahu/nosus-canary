package foo.nosus.app.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Debug
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Best-effort detection of dynamic instrumentation (Frida) and hook
 * frameworks (Xposed/LSPosed). These are signals, not proof — LSPosed's
 * per-app hide list and Frida's stealth/agent-injection modes can evade the
 * file, port, and class checks below. Treated as "critical" severity
 * upstream because, unlike root, active instrumentation implies someone is
 * *right now* attached to this process, not merely that the device could be
 * tampered with.
 */
object InstrumentationDetector {

    private val XPOSED_PACKAGES = arrayOf(
        "de.robv.android.xposed.installer",
        "org.meowcat.edxposed.manager",
        "io.github.lsposed.manager",
        "org.lsposed.manager"
    )

    private val FRIDA_MAP_MARKERS = arrayOf("frida", "gum-js-loop", "linjector", "frida-agent")

    fun scan(context: Context): Map<String, Any?> {
        val reasons = mutableListOf<String>()

        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            reasons.add("debugger attached")
        }

        try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            reasons.add("xposed bridge class loaded")
        } catch (_: ClassNotFoundException) {
            // Not present — expected when no hook framework is active.
        }

        val pm = context.packageManager
        for (pkg in XPOSED_PACKAGES) {
            try {
                pm.getPackageInfo(pkg, 0)
                reasons.add("hook framework manager installed: $pkg")
            } catch (_: PackageManager.NameNotFoundException) {
                // Not installed.
            }
        }

        try {
            val maps = File("/proc/self/maps").readLines()
            val hasFridaMarker = maps.any { line ->
                FRIDA_MAP_MARKERS.any { marker -> line.contains(marker, ignoreCase = true) }
            }
            if (hasFridaMarker) {
                reasons.add("frida artifact in process memory map")
            }
        } catch (_: Exception) {
            // SELinux may block reading our own maps on newer Android — this
            // is inconclusive, not a false negative claim.
        }

        try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", 27042), 150)
                reasons.add("frida-server listening on default port 27042")
            }
        } catch (_: Exception) {
            // Closed/filtered — expected on clean devices.
        }

        return mapOf(
            "instrumented" to reasons.isNotEmpty(),
            "reasons" to reasons.distinct()
        )
    }
}
