apply(from = "jcenter_stub.gradle")

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "file_picker" || name == "screen_protector") {
        plugins.apply("org.jetbrains.kotlin.android")
    }
}

// Path A: Proper Gradle JVM Toolchain fix for JVM Target mismatches
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            // Some third-party plugin modules (observed: sentry_flutter) ship
            // without an explicit Kotlin languageVersion, which Gradle/AGP
            // then defaults to something ancient (1.6) that this project's
            // Kotlin 2.2.x compiler rejects outright ("Language version 1.6
            // is no longer supported"). Same fix shape as the jvmTarget
            // force above — apply a sane modern floor across every
            // subproject rather than patching one plugin at a time.
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
            apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
        }
    }
}

subprojects {
    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            // Force compileSdk 36 (Android 16/Baklava)
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                setCompileSdk.invoke(android, 36)
            } catch (_: Exception) {
                try {
                    val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    compileSdkVersion.invoke(android, 36)
                } catch (_: Exception) { }
            }
            
            // Force Java 17 Compatibility across all modules (Path A)
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val setSourceCompatibility = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTargetCompatibility = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                setSourceCompatibility.invoke(compileOptions, JavaVersion.VERSION_17)
                setTargetCompatibility.invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (_: Exception) { }
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
