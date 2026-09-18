package foo.nosus.app.security

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.view.accessibility.AccessibilityManager

/**
 * Flags enabled accessibility services outside a known-legitimate allowlist.
 * Accessibility-service abuse (auto-clickers, overlay-based credential
 * theft, remote-control trojans) is a well-documented Android attack
 * pattern — a hit here does not prove malicious intent, it surfaces a
 * service worth a user prompt or admin review.
 */
object AccessibilityAuditor {

    private val KNOWN_SAFE_PREFIXES = arrayOf(
        "com.google.android.marvin.talkback",
        "com.google.android.accessibility",
        "com.android.talkback",
        "com.samsung.android.accessibility",
        "com.samsung.accessibility"
    )

    fun scan(context: Context): Map<String, Any?> {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabled = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)

        val suspicious = enabled.mapNotNull { serviceInfo ->
            val id = serviceInfo.id ?: return@mapNotNull null
            val isKnownSafe = KNOWN_SAFE_PREFIXES.any { id.startsWith(it) }
            if (isKnownSafe) null else id
        }

        return mapOf(
            "suspiciousServicesFound" to suspicious.isNotEmpty(),
            "services" to suspicious
        )
    }
}
