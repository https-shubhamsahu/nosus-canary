# Custom ProGuard / R8 Rules for NO SUS
# Applied in release builds via build.gradle.kts

# ─── Flutter Engine ────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Platform Channel Plugins ──────────────────────────────────────────────────
-keep class com.it_club.flutter_secure_storage.** { *; }
-keep class dk.itst.android.security.** { *; }
-keep class com.mr.flutter.filepicker.** { *; }
-keep class com.protect.screen_protector.** { *; }

# ─── pdfrx (native PDF renderer — JNI bridge must be preserved) ───────────────
-keep class dev.majrie.pdfrx.** { *; }
-keep class com.pdfrx.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ─── Supabase / Ktor / OkHttp (WebSocket + HTTP client) ──────────────────────
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn io.ktor.**

# ─── JSON / Serialization ─────────────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep Kotlin serialization metadata (used by Supabase Kotlin client)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# ─── Suppress known harmless warnings ─────────────────────────────────────────
-dontwarn com.google.android.play.core.**
-dontwarn android.support.**
-dontwarn androidx.**
