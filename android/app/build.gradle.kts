plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.substitcher"
    compileSdk = 34  // Explicit version for consistency

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
            // Add fonts directory as assets
            assets.srcDirs("../../fonts")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.substitcher"
        minSdk = 24  // Android 7.0 - good tablet/phone coverage
        targetSdk = 34  // Latest Android
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with debug keys for now
            signingConfig = signingConfigs.getByName("debug")
            
            // ProGuard for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
        }
    }
}

flutter {
    source = "../.."
}