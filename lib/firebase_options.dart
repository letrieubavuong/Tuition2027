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
    apiKey: 'AIzaSyAalk10jjDFPeRkFxClA5frKH3Yya2nnWg',
    appId: '1:1030301766778:web:tuition2025',
    messagingSenderId: '1030301766778',
    projectId: 'tuition2025-d4e25',
    databaseURL: databaseURL,
    storageBucket: 'tuition2025-d4e25.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAalk10jjDFPeRkFxClA5frKH3Yya2nnWg',
    appId: '1:1030301766778:android:336fc140b6fd1250e6d7c3',
    messagingSenderId: '1030301766778',
    projectId: 'tuition2025-d4e25',
    databaseURL: databaseURL,
    storageBucket: 'tuition2025-d4e25.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAalk10jjDFPeRkFxClA5frKH3Yya2nnWg',
    appId: '1:1030301766778:ios:tuition2025',
    messagingSenderId: '1030301766778',
    projectId: 'tuition2025-d4e25',
    databaseURL: databaseURL,
    storageBucket: 'tuition2025-d4e25.firebasestorage.app',
  );
}
