import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
val mobileTestPackage = providers.gradleProperty("mobileTestPackage")
    .map(String::toBoolean)
    .getOrElse(false)
// Public Firebase app registration values, selected by the actual APK package.
val firebasePropertiesFile = file(
    if (mobileTestPackage) "firebase/mobiletest.properties" else "firebase/production.properties"
)
val firebaseProperties = Properties()
if (firebasePropertiesFile.exists()) {
    firebasePropertiesFile.inputStream().use(firebaseProperties::load)
}
val buildingRelease = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releasePropertiesFile.exists()) {
    FileInputStream(releasePropertiesFile).use(releaseProperties::load)
} else if (buildingRelease) {
    throw GradleException("android/key.properties is required for a release build")
}

android {
    namespace = "com.manugopinath.battlechessarena"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The opt-in testing identity installs alongside builds signed with an
        // older development key, avoiding Android's signature-conflict error.
        applicationId = if (mobileTestPackage) {
            "com.manugopinath.battlechessarena.mobiletest"
        } else {
            "com.manugopinath.battlechessarena"
        }
        if (firebasePropertiesFile.exists()) {
            val firebaseResources = mapOf(
                "google_app_id" to "appId",
                "gcm_defaultSenderId" to "senderId",
                "google_api_key" to "apiKey",
                "project_id" to "projectId",
            )
            firebaseResources.forEach { (resource, property) ->
                val value = firebaseProperties.getProperty(property)?.trim()
                require(!value.isNullOrEmpty()) {
                    "Missing $property in ${firebasePropertiesFile.name}"
                }
                resValue("string", resource, value)
            }
        }
        manifestPlaceholders["appLabel"] = if (mobileTestPackage) {
            "Battle Chess Arena Beta"
        } else {
            "Battle Chess Arena"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releasePropertiesFile.exists()) {
            create("release") {
                keyAlias = releaseProperties["keyAlias"] as String
                keyPassword = releaseProperties["keyPassword"] as String
                storeFile = file(releaseProperties["storeFile"] as String)
                storePassword = releaseProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
