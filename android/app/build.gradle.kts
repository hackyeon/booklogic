plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val sampleAndroidAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val missingReleaseAdMobAppId = "ca-app-pub-0000000000000000~0000000000"

fun isReleaseBuildRequested(): Boolean {
    return gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true)
    }
}

fun releaseAdMobAppId(): String {
    val configuredId =
        providers.gradleProperty("ADMOB_ANDROID_APP_ID").orNull
            ?: providers.environmentVariable("ADMOB_ANDROID_APP_ID").orNull
            ?: ""
    if (!isReleaseBuildRequested()) {
        return configuredId.ifBlank { missingReleaseAdMobAppId }
    }
    if (configuredId.isBlank()) {
        throw GradleException("ADMOB_ANDROID_APP_ID is required for release builds.")
    }
    if (configuredId == sampleAndroidAdMobAppId) {
        throw GradleException("Release builds must not use the sample AdMob App ID.")
    }
    return configuredId
}

android {
    namespace = "com.hack.booklogic.booklogic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hack.booklogic.booklogic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["ADMOB_APP_ID"] = sampleAndroidAdMobAppId
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["ADMOB_APP_ID"] = sampleAndroidAdMobAppId
        }
        maybeCreate("profile").apply {
            initWith(getByName("debug"))
            matchingFallbacks += listOf("debug")
            manifestPlaceholders["ADMOB_APP_ID"] = sampleAndroidAdMobAppId
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            manifestPlaceholders["ADMOB_APP_ID"] = releaseAdMobAppId()
        }
    }
}

flutter {
    source = "../.."
}
