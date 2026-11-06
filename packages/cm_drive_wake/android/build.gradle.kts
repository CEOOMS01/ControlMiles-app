group = "com.olimsys.cm_drive_wake"
version = "1.0.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.olimsys.cm_drive_wake"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

dependencies {
    // Activity Recognition transitions. Same floor Tracelet requires (21.4.0).
    implementation("com.google.android.gms:play-services-location:21.4.0")
    implementation("androidx.core:core:1.13.1")
}
