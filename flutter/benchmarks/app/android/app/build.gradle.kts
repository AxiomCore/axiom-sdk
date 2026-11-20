plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.axiomcore.axiom_bench_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.axiomcore.axiom_bench_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Size benchmark only: AXIOM_DROP_WASM=1 applies the documented opt-out from
// axiom_flutter/doc/wasm-size.md (drops the web runtime assets from the APK).
if (System.getenv("AXIOM_DROP_WASM") == "1") {
    tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
        doLast {
            outputs.files.forEach { out ->
                fileTree(out) { include("**/packages/axiom_flutter/lib/assets/wasm/**") }
                    .forEach { it.delete() }
            }
        }
    }
}
