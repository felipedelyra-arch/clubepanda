import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release. O keystore e as senhas ficam FORA do versionamento:
// crie `android/key.properties` (modelo em `android/key.properties.example`).
// Sem esse arquivo o release continua saindo assinado com a chave de debug —
// roda no aparelho, mas a Play Store recusa o envio.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val temAssinatura = keystorePropertiesFile.exists()

android {
    namespace = "com.tiopanda.clube_panda"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tiopanda.clube_panda"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (temAssinatura) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (temAssinatura) "release" else "debug")
            // Símbolos nativos no bundle: sem isso a Play Console mostra o crash
            // do engine como endereço de memória.
            ndk { debugSymbolLevel = "SYMBOL_TABLE" }
        }
    }
}

// Os plugins do Firebase só entram quando o `google-services.json` existir —
// ele é criado por `flutterfire configure`. Declarar antes disso quebraria o
// build com "File google-services.json is missing".
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
