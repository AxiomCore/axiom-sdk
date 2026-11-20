plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.axiomcore.fixture.axiom_fixture_app"
    compileSdk = 36 // flutter_secure_storage 10 (axiom_flutter_auth)
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
        applicationId = "dev.axiomcore.fixture.axiom_fixture_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // axiom_flutter needs API 24 (libaxiom_runtime.so is built for android-24).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // `flutter build --target-platform android-arm64` only drops other ABIs of
        // libflutter.so; also drop the other ABIs of plugin libraries
        // (libaxiom_runtime.so). Not with --split-per-abi (AGP rejects both).
        val abiByPlatform = mapOf(
            "android-arm64" to "arm64-v8a",
            "android-arm" to "armeabi-v7a",
            "android-x64" to "x86_64",
        )
        val targetAbis = (project.findProperty("target-platform") as String?)
            ?.split(",")?.mapNotNull { abiByPlatform[it.trim()] }.orEmpty()
        if (targetAbis.isNotEmpty() && project.findProperty("split-per-abi") != "true") {
            ndk { abiFilters += targetAbis }
        }
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
