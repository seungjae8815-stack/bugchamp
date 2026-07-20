import java.util.Properties

// 릴리즈 서명 키. `android/key.properties` 가 있으면 그 키로 서명하고,
// 없으면 디버그 키로 폴백한다(키 없는 환경에서도 빌드는 되게).
// key.properties 와 .jks 는 절대 커밋하지 않는다 — .gitignore 확인.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

// AdMob 앱 ID. **공개값**이라 저장소에 두어도 문제없다(APK 안에 어차피 들어간다).
// gitignore 되는 local.properties 에만 두면 새로 클론했을 때 조용히 테스트 ID 로
// 떨어져 실사용자에게 테스트 광고가 나가므로, 실제 값을 기본값으로 못박는다.
// 다른 계정으로 빌드할 땐 local.properties 의 admobAppId 로 덮어쓰면 된다.
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val admobAppIdValue: String =
    localProps.getProperty("admobAppId") ?: "ca-app-pub-9286376018372718~3392603608"

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bugchamp.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications(예약 알림)용 core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bugchamp.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppIdValue
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 업로드 키가 있으면 그것으로, 없으면 디버그 키로 서명한다.
            // ⚠️ 디버그 키로 서명된 빌드는 Play Console 에 업로드할 수 없고
            //    인앱결제·구글 로그인도 동작하지 않는다.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
