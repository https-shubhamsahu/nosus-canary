package foo.nosus.app.security

import android.content.Context

/**
 * Aggregates the individual detectors into one payload the Dart-side
 * MethodChannel handler in MainActivity returns as-is. Kept as a thin
 * facade so MainActivity's platform-channel wiring doesn't need to know
 * about each detector individually.
 */
object DeviceIntegrityManager {
    fun runAllChecks(context: Context): Map<String, Any?> {
        return mapOf(
            "root" to RootDetector.scan(context),
            "instrumentation" to InstrumentationDetector.scan(context),
            "displayMirroring" to DisplayMirrorDetector.scan(context),
            "accessibility" to AccessibilityAuditor.scan(context)
        )
    }
}
