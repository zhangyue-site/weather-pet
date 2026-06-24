plugin {
    id 'com.android.library'
}

android {
    namespace 'com.skydiver.weatherpet.plugin'
    compileSdk 34
    defaultConfig {
        minSdk 24
        targetSdk 34
    }
}

dependencies {
    implementation 'org.godotengine:godot:4.4.0'
    implementation 'androidx.work:work-runtime:2.9.1'
    implementation 'com.google.android.gms:play-services-location:21.3.0'
    implementation 'com.squareup.retrofit2:retrofit:2.11.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.11.0'
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
}
