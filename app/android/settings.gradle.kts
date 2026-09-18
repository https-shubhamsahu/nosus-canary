pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Declared but never applied here — app/build.gradle.kts applies it only
    // when google-services.json is present. Applying it unconditionally makes
    // the build fail outright on any checkout without that file, which is
    // every checkout today.
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

include(":app")
