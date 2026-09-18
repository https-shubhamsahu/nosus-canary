package foo.nosus.app.security

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.PublicKey
import java.security.spec.ECGenParameterSpec

/**
 * Derives this install's device identity from a non-extractable EC keypair
 * held in the Android Keystore, instead of a random UUID in SharedPreferences.
 *
 * Why: the previous identity was a plain `Uuid().v4()` written to prefs, which
 * on a rooted device — exactly the population DeviceIntegrityService exists to
 * notice — is editable in seconds. That made two detectors defeatable:
 * a device flagged for root could rotate its id and come back clean, and the
 * 'multiple_device_access' detector could be nulled out entirely by reporting
 * one id from every device. The private key here never leaves the TEE (or
 * StrongBox where available), so the id can't be forged or transplanted to
 * another device; clearing app data destroys the key, which is correct.
 *
 * Scope note: this is the *local* half. The server still takes the client's
 * word that the id came from hardware — proving that requires verifying an
 * attestation certificate chain server-side, which needs a real physical
 * device to test against and is deliberately not attempted here. See the
 * "device identity" section of CLAUDE.md.
 */
object KeyAttestationManager {
    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    private const val KEY_ALIAS = "nosus_device_identity_v1"

    /**
     * Returns the stable device id plus the security level the platform
     * actually granted the key. Throws if the Keystore is unusable at all —
     * the Dart side treats that as "no hardware id available" and falls back
     * to the legacy UUID rather than failing the launch.
     */
    fun getOrCreateDeviceKeyId(): Map<String, Any?> {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

        val publicKey = existingPublicKey(keyStore) ?: generateKeyPair()
        val level = securityLevelOf(keyStore)

        return mapOf(
            "deviceId" to sha256Hex(publicKey.encoded),
            "securityLevel" to level,
            "hardwareBacked" to (level != LEVEL_SOFTWARE)
        )
    }

    /**
     * An alias can survive in the keystore while its key material is gone or
     * unreadable (OEM quirks, partial restores). Treat any failure to read it
     * back as "no key" so the caller regenerates rather than throwing.
     */
    private fun existingPublicKey(keyStore: KeyStore): PublicKey? {
        return try {
            if (!keyStore.containsAlias(KEY_ALIAS)) return null
            keyStore.getCertificate(KEY_ALIAS)?.publicKey
        } catch (_: Exception) {
            try {
                keyStore.deleteEntry(KEY_ALIAS)
            } catch (_: Exception) { }
            null
        }
    }

    /**
     * StrongBox (a discrete secure element) is strictly better than the TEE
     * but only exists on some devices, and OEMs have shipped implementations
     * that throw variants beyond StrongBoxUnavailableException — hence the
     * broad catch and unconditional retry without it.
     */
    private fun generateKeyPair(): PublicKey {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                return generateWith(strongBox = true)
            } catch (_: Exception) {
                try {
                    KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }.deleteEntry(KEY_ALIAS)
                } catch (_: Exception) { }
            }
        }
        return generateWith(strongBox = false)
    }

    private fun generateWith(strongBox: Boolean): PublicKey {
        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            KEYSTORE_PROVIDER
        )

        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)

        // Deliberately no setUserAuthenticationRequired: the id has to be
        // readable at launch, before any biometric prompt would be shown, and
        // this key signs nothing sensitive — it exists to *be* an identity.
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }

        generator.initialize(builder.build())
        return generator.generateKeyPair().public
    }

    private fun securityLevelOf(keyStore: KeyStore): String {
        return try {
            val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey ?: return LEVEL_SOFTWARE
            val keyInfo = KeyFactory
                .getInstance(privateKey.algorithm, KEYSTORE_PROVIDER)
                .getKeySpec(privateKey, KeyInfo::class.java)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                when (keyInfo.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> LEVEL_STRONGBOX
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> LEVEL_TEE
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> LEVEL_SOFTWARE
                    // UNKNOWN / UNKNOWN_SECURE: the platform is telling us it
                    // can't characterise the backing. Don't claim hardware.
                    else -> LEVEL_UNKNOWN
                }
            } else {
                @Suppress("DEPRECATION")
                if (keyInfo.isInsideSecureHardware) LEVEL_TEE else LEVEL_SOFTWARE
            }
        } catch (_: Exception) {
            LEVEL_UNKNOWN
        }
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        val out = StringBuilder(digest.size * 2)
        for (b in digest) out.append("%02x".format(b))
        return out.toString()
    }

    private const val LEVEL_STRONGBOX = "strongbox"
    private const val LEVEL_TEE = "tee"
    private const val LEVEL_SOFTWARE = "software"
    private const val LEVEL_UNKNOWN = "unknown"
}
