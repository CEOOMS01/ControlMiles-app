import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real release signing (launch-readiness fix): the release buildType below
// used to sign with the debug keystore unconditionally -- fine for local
// `flutter run --release`, but Google Play will not accept (and Play App
// Signing itself requires) a real upload keystore. Standard Flutter
// pattern: read from android/key.properties (gitignored, created locally
// by whoever holds the keystore) when present, fall back to the debug
// config only when it's missing so local release builds still work before
// the real keystore exists.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.olimsys.controlmiles"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications (usa APIs de java.time
        // que no existen nativamente en versiones viejas de Android).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.olimsys.controlmiles"
        // tracelet_android's native code (FusedLocationProvider/WorkManager
        // APIs it relies on) requires API 26 (Android 8.0, 2017) --
        // flutter.minSdkVersion defaults to 24, which the Gradle manifest
        // merger correctly rejects rather than silently risk a runtime
        // crash on those two API levels. By 2026, API 24/25 devices are a
        // vanishing sliver of the active Android install base (Play
        // Console's own distribution data puts it well under ~1-2%), so
        // raising the floor here is the standard trade-off, not a
        // workaround -- NOT using tools:overrideLibrary, which Gradle's own
        // error suggests as an alternative: that only silences this check,
        // it doesn't make tracelet's APIs exist on API 24/25, so it would
        // still crash at runtime on exactly the devices it claims to support.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Real signing once android/key.properties exists (see comment
            // above) -- falls back to the debug keystore only so a release
            // build still compiles locally before the real keystore is
            // created. A debug-signed build must never be the one uploaded
            // to Play Console.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // BUG FIX (found live, 2026-09-19, first real release AAB build
            // attempted for this app): R8 failed outright with "Missing
            // classes" for google_mlkit_text_recognition's non-Latin script
            // recognizers (Chinese/Devanagari/Japanese/Korean) -- this app
            // never depends on those optional ML Kit modules (odometer OCR
            // only needs Latin), so R8 has no class to resolve them against.
            // See proguard-rules.pro's own header for the full explanation;
            // this just wires that file in alongside AGP's default rules.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Requerido por flutter_local_notifications junto con
    // isCoreLibraryDesugaringEnabled = true arriba.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
