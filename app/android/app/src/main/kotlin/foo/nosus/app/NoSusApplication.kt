package foo.nosus.app

import android.app.Application
import android.content.pm.PackageManager
import android.os.Build
import sh.measure.android.Measure
import sh.measure.android.config.MeasureConfig

/**
 * Exists for exactly one reason: the Measure SDK has no Dart-side
 * initialisation path.
 *
 * `measure_flutter`'s MethodChannel exposes `start`/`stop`/`trackEvent`/… but
 * no `init` — the native SDK must already be running by the time Dart calls
 * anything, and it has to come up in `Application.onCreate` to catch crashes
 * that happen before the Flutter engine exists. That is why this class is
 * registered as `android:name` in AndroidManifest.xml instead of the
 * `${applicationName}` placeholder Flutter fills in by default.
 *
 * It extends plain [Application]: this app is on Flutter's v2 embedding
 * (`flutterEmbedding` = 2 in the manifest), which does not require
 * `FlutterApplication`.
 */
class NoSusApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initMeasureIfConfigured()
    }

    /**
     * No-op unless both `MEASURE_API_KEY` and `MEASURE_API_URL` reached the
     * manifest. They are injected as manifest placeholders by
     * `android/app/build.gradle.kts`, read out of the repo-root `.env` — the
     * same file `--dart-define-from-file` feeds to
     * `lib/config/measure_reporting_config.dart`. A build without that `.env`
     * (fresh clone, CI without the secrets) gets empty strings here and the SDK
     * never starts.
     *
     * Guarding on the value rather than letting the SDK read the meta-data
     * itself is deliberate: an unconfigured `Measure.init` would still spin up
     * the SDK's storage and its periodic export machinery pointed at nothing.
     */
    private fun initMeasureIfConfigured() {
        try {
            val metaData = applicationMetaData() ?: return
            val apiKey = metaData.getString(META_API_KEY).orEmpty()
            val apiUrl = metaData.getString(META_API_URL).orEmpty()
            if (apiKey.isBlank() || apiUrl.isBlank()) return

            Measure.init(
                this,
                MeasureConfig(
                    // Initialise, but collect nothing until Dart explicitly
                    // calls start() — see main.dart. This is the single control
                    // point for collection, and the place a user-consent gate
                    // would attach. With the default (true) the native SDK
                    // would already be recording during the anonymous
                    // burn-note / share-viewer entry points, which never reach
                    // the normal app bootstrap at all.
                    autoStart = false,
                    // Load-bearing, despite matching the SDK default. Every
                    // link this app mints carries its AES key in the URL
                    // fragment (#/burn/<id>?k=<key>&v=<iv>), and those arrive
                    // as Activity intent data. Flipping this to true would
                    // upload plaintext decryption keys to a third party. Do
                    // not remove this line on the grounds that it is
                    // redundant — it is pinning a default that must never
                    // drift. See AGENTS.md §5.
                    trackActivityIntentData = false,
                ),
            )
        } catch (_: Exception) {
            // Monitoring must never be the reason the app fails to launch.
            // Deliberately not logged: printStackTrace() writes to logcat
            // unconditionally, including in release builds (same reasoning as
            // MainActivity.saveUriToCache).
        }
    }

    private fun applicationMetaData() = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getApplicationInfo(
                packageName,
                PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
            ).metaData
        } else {
            @Suppress("DEPRECATION")
            packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData
        }
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    private companion object {
        const val META_API_KEY = "sh.measure.android.API_KEY"
        const val META_API_URL = "sh.measure.android.API_URL"
    }
}
