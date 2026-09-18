package foo.nosus.app.security

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.plugin.common.MethodChannel

/**
 * Requests a Play Integrity standard token — a Google-signed attestation of
 * app/device/account integrity, verified server-side (never trust-on-read
 * client-side) by supabase/functions/verify-play-integrity.
 *
 * SCAFFOLDING, NOT ENABLED: [cloudProjectNumber] must be replaced with the
 * real Google Cloud project number linked to this app in Play Console
 * (Play Console → App integrity → Play Integrity API → your project
 * number) before any token request can succeed — 0 will always fail
 * (Google rejects it). The Dart-side call site
 * (lib/services/play_integrity_service.dart) is also gated behind
 * AppIntegrityConfig.enabled, which defaults false, so this native code
 * exists but is never invoked until BOTH are switched on. See CLAUDE.md's
 * "Play Integrity — scaffolded, not enabled" note for the full setup path.
 */
object PlayIntegrityManager {
    private const val cloudProjectNumber: Long = 0L

    fun requestToken(context: Context, nonce: String, result: MethodChannel.Result) {
        if (cloudProjectNumber == 0L) {
            result.error(
                "NOT_CONFIGURED",
                "PlayIntegrityManager.cloudProjectNumber is unset — see the class doc.",
                null,
            )
            return
        }

        val integrityManager = IntegrityManagerFactory.create(context)
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .setCloudProjectNumber(cloudProjectNumber)
            .build()

        integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                result.success(response.token())
            }
            .addOnFailureListener { exception ->
                result.error("INTEGRITY_TOKEN_FAILED", exception.message, null)
            }
    }
}
