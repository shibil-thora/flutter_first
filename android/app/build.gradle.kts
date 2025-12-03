import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Load local keystore properties if present (android/key.properties)
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
    namespace = "com.example.hello_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Kotlin jvmTarget should be configured using tasks.withType<KotlinCompile>()

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.hello_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // release signing reads values from android/key.properties when present
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // use release signing if key.properties exists, otherwise fall back to debug
            signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            // Resource shrinking requires code shrinking (minification) to be enabled.
            // Keep resource shrinking off unless you enable minification and ProGuard/R8 rules.
            isShrinkResources = false
            isMinifyEnabled = false // change to true and add proguard rules if you enable minification
        }
    }
}

flutter {
    source = "../.."
}

// Configure Kotlin compile options for all Kotlin compile tasks (sets JVM target)
tasks.withType<KotlinCompile>().configureEach {
    // Configure the Kotlin compiler target using the modern compilerOptions DSL
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
