import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.fanmining.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.fanmining.app"

        minSdk = 24
        targetSdk = 36

        versionCode = 1
        versionName = "1.0.0"

        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(
                    keystoreProperties["storeFile"] as String
                )
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile(
                    "proguard-android-optimize.txt"
                ),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {

    // ============================================================
    // MULTIDEX
    // ============================================================

    implementation(
        "androidx.multidex:multidex:2.0.1"
    )

    // ============================================================
    // LEVELPLAY / GOOGLE PLAY SERVICES
    // ============================================================

    implementation(
        "com.google.android.gms:play-services-appset:16.0.2"
    )

    implementation(
        "com.google.android.gms:play-services-ads-identifier:18.0.1"
    )

    implementation(
        "com.google.android.gms:play-services-basement:18.3.0"
    )

    // ============================================================
    // YANDEX ADS - UNITY LEVELPLAY ADAPTER
    // Adapter 5.14.0 includes the compatible Yandex Ads SDK 8.4.0
    // ============================================================

    implementation(
        "com.unity3d.ads-mediation:yandex-adapter:5.14.0"
    )

    // ============================================================
    // CORE LIBRARY DESUGARING
    // Required by flutter_local_notifications
    // ============================================================

    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.5"
    )
}
