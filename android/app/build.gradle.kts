plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.mrfragger.substitcher"
    compileSdk = 36

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
            assets.srcDirs("../../fonts")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
    jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "io.github.mrfragger.substitcher"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    dependencies {
    implementation("com.github.media-kit:libmpv-android-audio-build:...")
    }

    splits {
        abi {
            isEnable = false
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            excludes += listOf(
                "**/armeabi-v7a/**",
                "**/x86/**",
                "**/x86_64/**"
            )
        }
    }
}

configurations.all {
    exclude(mapOf("group" to "com.github.media-kit", "module" to "default-armeabi-v7a"))
    exclude(mapOf("group" to "com.github.media-kit", "module" to "default-x86_64"))
    exclude(mapOf("group" to "com.github.media-kit", "module" to "default-x86"))
}

flutter {
    source = "../.."
}
