import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.municipalidad"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keyPropertiesFile = rootProject.file("key.properties")
    val keyProperties = Properties()
    val hasKeyProps = keyPropertiesFile.exists()
    if (hasKeyProps) {
        keyProperties.load(FileInputStream(keyPropertiesFile))
    } else {
        logger.warn(
            "key.properties no encontrado en: ${keyPropertiesFile.absolutePath}. " +
                "Se usará el signingConfig de debug para buildType=release. " +
                "Para firmar release correctamente, crea android/key.properties y el keystore."
        )
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.municipalidad"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseSigningConfig = if (hasKeyProps) {
        signingConfigs.create("release") {
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            // Resolve relative to the Android root project (android/), not android/app/.
            storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
            storePassword = keyProperties.getProperty("storePassword")
        }
    } else {
        signingConfigs.getByName("debug")
    }

    buildTypes {
        release {
            signingConfig = releaseSigningConfig
        }
    }
}

flutter {
    source = "../.."
}
