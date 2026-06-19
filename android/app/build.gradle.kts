plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 署名鍵の設定
// ローカル: android/key.properties（git管理外）
// CI:      Forgejo Secrets（RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS, RELEASE_KEY_PASSWORD）
val keystoreProps = java.util.Properties().apply {
    val localFile = rootProject.file("../key.properties")
    if (localFile.exists()) load(localFile.inputStream())
}

android {
    namespace = "com.h1.core"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.h1.core"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    splits {
        abi {
            isUniversalApk = true
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = rootProject.file(keystoreProps.getProperty("storeFile") ?: "../keystore/debug.keystore")
            storePassword = keystoreProps.getProperty("storePassword")
                ?: (System.getenv("RELEASE_STORE_PASSWORD")?.takeIf { it.isNotEmpty() } ?: "android")
            keyAlias = keystoreProps.getProperty("keyAlias")
                ?: (System.getenv("RELEASE_KEY_ALIAS")?.takeIf { it.isNotEmpty() } ?: "androiddebugkey")
            keyPassword = keystoreProps.getProperty("keyPassword")
                ?: (System.getenv("RELEASE_KEY_PASSWORD")?.takeIf { it.isNotEmpty() } ?: "android")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs["release"]
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
