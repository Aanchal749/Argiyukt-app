import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ⚠️ Comment this out if google-services.json is missing
}

android {
    namespace = "com.example.agriyukt_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 🔴 REMOVED: broken 'kotlinOptions' block
    // The fix is added at the bottom of the file

    defaultConfig {
        applicationId = "com.example.agriyukt_app"
        minSdk = flutter.minSdkVersion // ✅ Hardcoded to 21 for Firebase/Multidex support
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    // implementation(platform("com.google.firebase:firebase-bom:33.1.0")) // Optional: Add if using Firebase
}

// ✅ FIX 1: Modern Kotlin Compiler Options (Fixes 'jvmTarget' error)
tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

// ✅ FIX 2: Downgrade dependencies to prevent "AGP 8.9.1" error
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        eachDependency {
            if (requested.group == "androidx.browser") {
                useVersion("1.8.0")
            }
            if (requested.group == "androidx.activity") {
                useVersion("1.9.0")
            }
            if (requested.group == "androidx.core") {
                useVersion("1.13.1")
            }
        }
    }
}
