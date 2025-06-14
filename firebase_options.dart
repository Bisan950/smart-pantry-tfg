// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '1:97019197959:web:ab0124c789d5fd1db7c8a2',
    messagingSenderId: '97019197959',
    projectId: 'smart-pantry-e8355',
    authDomain: 'smart-pantry-e8355.firebaseapp.com',
    storageBucket: 'smart-pantry-e8355.firebasestorage.app',
    measurementId: 'G-JPGZY51JLM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '1:97019197959:android:93a7399abd0a7130b7c8a2',
    messagingSenderId: '97019197959',
    projectId: 'smart-pantry-e8355',
    storageBucket: 'smart-pantry-e8355.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '1:97019197959:ios:4d840656494d48f8b7c8a2',
    messagingSenderId: '97019197959',
    projectId: 'smart-pantry-e8355',
    storageBucket: 'smart-pantry-e8355.firebasestorage.app',
    iosBundleId: 'com.example.smartPantry',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '',
    appId: '1:97019197959:ios:4d840656494d48f8b7c8a2',
    messagingSenderId: '97019197959',
    projectId: 'smart-pantry-e8355',
    storageBucket: 'smart-pantry-e8355.firebasestorage.app',
    iosBundleId: 'com.example.smartPantry',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '',
    appId: '1:97019197959:web:1ea9fbe2a211db07b7c8a2',
    messagingSenderId: '97019197959',
    projectId: 'smart-pantry-e8355',
    authDomain: 'smart-pantry-e8355.firebaseapp.com',
    storageBucket: 'smart-pantry-e8355.firebasestorage.app',
    measurementId: 'G-7EGDH4G7J9',
  );
}
