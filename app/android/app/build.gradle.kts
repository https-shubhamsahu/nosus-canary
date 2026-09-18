import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase Cloud Messaging, applied only when the project has actually been
// provisioned. The google-services plugin fails the build with "File
// google-services.json is missing" if it is applied without one, so putting it
// in the plugins {} block above would break every build in CI and on every
// fresh clone — the repo has no such file and must not (it is per-project
// config, and checking one in would tie the open repo to one Firebase project).
//
// Drop the file in android/app/ and this wires itself up on the next build.
// Nothing else needs to change. See AGENTS.md §8.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Repo-root .env, the same file CI writes and `--dart-define-from-file=.env`
// reads. Git-ignored and usually absent, in which case this stays empty and
// every lookup below falls back to "". rootProject here is android/, so the
// repo root is one level up.
val measureEnv = Properties().apply {
    val envFile = rootProject.file("../.env")
    if (envFile.exists()) {
        envFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "foo.nosus.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "foo.nosus.app"
        minSdk = flutter.minSdkVersion  // flutter_secure_storage requires API 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Measure (measure.sh) credentials for AndroidManifest.xml.
        //
        // The native SDK initialises in Application.onCreate, before the
        // Flutter engine exists, so it cannot be handed a --dart-define. It
        // reads meta-data from the manifest instead. Sourcing both sides from
        // the one repo-root .env is what keeps the native gate and the Dart
        // gate (lib/config/measure_reporting_config.dart, fed by
        // --dart-define-from-file=.env) in agreement.
        //
        // Empty when .env is absent — a fresh clone and a CI run without the
        // secrets both build fine and ship the SDK inert. Placeholders must
        // always be set to *something*: an unresolved ${...} in the manifest
        // is a merge failure, not a warning.
        manifestPlaceholders["measureApiKey"] = measureEnv.getProperty("MEASURE_API_KEY") ?: ""
        manifestPlaceholders["measureApiUrl"] = measureEnv.getProperty("MEASURE_API_URL") ?: ""
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = Properties()
            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.inputStream().use { stream ->
                    keystoreProperties.load(stream)
                }
                // A present-but-blank key.properties (e.g. checked out fresh,
                // template never filled in) must be treated the same as a
                // missing file. Properties.getProperty("storeFile") on a line
                // like "storeFile=" returns "" (empty string), which is not
                // null — file("") resolves to the project directory itself,
                // a non-null File that would otherwise slip past the
                // `storeFile != null` check below and get selected as a
                // broken "release" signing config instead of falling back
                // to debug signing.
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                if (!storeFilePath.isNullOrBlank()) {
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    storeFile = file(storeFilePath)
                    storePassword = keystoreProperties.getProperty("storePassword")
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.findByName("release")
            if (releaseConfig != null && releaseConfig.storeFile != null && releaseConfig.storeFile!!.exists()) {
                signingConfig = releaseConfig
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            // Enable R8 minification and resource shrinking with custom rules
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Required for pdfrx native PDF renderer — AGP 8+ equivalent of extractNativeLibs="true"
            packaging {
                jniLibs {
                    useLegacyPackaging = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Modern Android 12+ SplashScreen API, backported to minSdk via the
    // compat shim so pre-12 devices get equivalent behavior through the
    // same windowSplashScreen* theme attributes (see styles.xml).
    implementation("androidx.core:core-splashscreen:1.0.1")

    // Play Integrity API (standard request) — server-verifiable device/app
    // attestation, complementing the client-side heuristics in
    // RootDetector.kt/InstrumentationDetector.kt (which a sufficiently
    // capable attacker can spoof; Play Integrity's response is signed by
    // Google and verified server-side in supabase/functions/verify-play-integrity).
    // See PlayIntegrityManager.kt for why this is scaffolded, not enabled.
    implementation("com.google.android.play:integrity:1.4.0")
}
