plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ Firebase plugins
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")  // ✅ AÑADE ESTA LÍNEA
}

android {
    // ✅ Application ID para smart_pantry
    namespace = "com.example.smart_pantry"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ✅ CRÍTICO: Habilitar desugaring para flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // ✅ Application ID para smart_pantry
        applicationId = "com.example.smart_pantry"
        
        // ✅ Configuración de SDK actualizada
        minSdk = 23  // Mínimo para flutter_local_notifications
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        // ✅ Configuración básica sin NDK específico
        // ndk se configurará automáticamente si es necesario
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // ✅ Optimizaciones para release
            isDebuggable = false
            isJniDebuggable = false
        }
        
        debug {
            isMinifyEnabled = false
            isDebuggable = true
            // applicationIdSuffix = ".debug"
        }
    }

    // ✅ Configuración de lint
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // ✅ Configuración de packaging
    packaging {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }

    // ✅ NUEVO: Configuración para resolver conflictos de Firebase
    configurations.all {
        resolutionStrategy {
            // Fuerza versiones específicas para evitar conflictos
            force("com.google.firebase:firebase-iid:21.1.0")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ CRÍTICO: desugar_jdk_libs versión 2.1.4 - Requerido para flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // ✅ Dependencias básicas de Android actualizadas
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    
    // ✅ Para compatibilidad con notificaciones
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // ✅ Firebase - DESCOMENTADO y actualizado para resolver conflictos
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    
    // ✅ IMPORTANTE: Excluir firebase-iid para evitar conflictos
    implementation("com.google.firebase:firebase-messaging-ktx") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}