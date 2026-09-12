// File: lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String databaseURL =
      'https://tuition2025-d4e25-default-rtdb.asia-southeast1.firebasedatabase.app/';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA-tuition2025-web-key',
    appId: '1:1052673238914:web:tuition2025',
    messagingSenderId: '1052673238914',
    projectId: 'tuition2025-d4e25',
    databaseURL: databaseURL,
    storageBucket: 'tuition2025-d4e25.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-tuition2025-android-key',
    appId: '1:1052673238914:android:tuition2025',
    messagingSenderId: '1052673238914',
    projectId: 'tuition2025-d4e25',
    databaseURL: databaseURL,
    storageBucket: 'tuition2025-d4e25.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA-tuition2025-ios-key',
    appId: '1:1052673238914:ios:tuition2025',
    messagingSenderId: '1052673238914',
    projectId: 'tuition2025-d4e25',
    databaseURL: databaseURL,
    storageBucket: 'tuition2025-d4e25.appspot.com',
  );
}
