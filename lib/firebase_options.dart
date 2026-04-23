import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCn06SQoFoGmtt79hEVS1WVptBvslWTCE4',
    appId: '1:174103157478:web:135ff096dbca79f039f927',
    messagingSenderId: '174103157478',
    projectId: 'collegenoticeboard-49628',
    authDomain: 'collegenoticeboard-49628.firebaseapp.com',
    storageBucket: 'collegenoticeboard-49628.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVFbRbffG0IeZAJu8qBR6MzOkUEuuzr1k',
    appId: '1:174103157478:android:4e322a7ad9806cfa39f927',
    messagingSenderId: '174103157478',
    projectId: 'collegenoticeboard-49628',
    storageBucket: 'collegenoticeboard-49628.firebasestorage.app',
  );
}
