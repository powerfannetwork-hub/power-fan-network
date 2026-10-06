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

    /*
     * Required by the native dependencies used by the project.
     *
     * The previous GitHub Actions build reported that a dependency
     * requires NDK 28.2.13676358 while the project was using NDK 27.
     */
    ndkVersion = "28.2.13676358"

    packaging {
        resources {
            excludes +=
                "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }

    defaultConfig {
        applicationId = "com.fanmining.app"

        // Android 7.0 (API 24) and newer.
        minSdk = 24
        targetSdk = 36

        versionCode = 1
        versionName = "1.0.0"

        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {

            if (keystorePropertiesFile.exists()) {

                keyAlias =
                    keystoreProperties["keyAlias"] as String

                keyPassword =
                    keystoreProperties["keyPassword"] as String

                storeFile =
                    file(
                        keystoreProperties["storeFile"] as String
                    )

                storePassword =
                    keystoreProperties["storePassword"] as String
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

            signingConfig =
                signingConfigs.getByName("release")

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

    implementation(
        "androidx.multidex:multidex:2.0.1"
    )

    implementation(
        "com.google.android.gms:play-services-appset:16.0.2"
    )

    implementation(
        "com.google.android.gms:play-services-ads-identifier:18.0.1"
    )

    implementation(
        "com.google.android.gms:play-services-basement:18.3.0"
    )

    implementation(
        "com.unity3d.ads-mediation:yandex-adapter:5.14.0"
    )

    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.5"
    )
}
