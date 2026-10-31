import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyB2IxQNKHGAZ1blFbA1W_TD7-3nFl_g2w4',
  );

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
    apiKey: _firebaseApiKey,
    appId: '1:289800550418:web:9100cd54ecd14a19d2c0cb',
    messagingSenderId: '289800550418',
    projectId: 'cambus-connect-iist',
    authDomain: 'cambus-connect-iist.firebaseapp.com',
    databaseURL: 'https://cambus-connect-iist-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'cambus-connect-iist.firebasestorage.app',
    measurementId: 'G-XV5LJDB6YH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:289800550418:web:9100cd54ecd14a19d2c0cb', // Fallback to Web App ID since Android App isn't registered
    messagingSenderId: '289800550418',
    projectId: 'cambus-connect-iist',
    databaseURL: 'https://cambus-connect-iist-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'cambus-connect-iist.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: '1:289800550418:web:9100cd54ecd14a19d2c0cb', // Fallback
    messagingSenderId: '289800550418',
    projectId: 'cambus-connect-iist',
    databaseURL: 'https://cambus-connect-iist-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'cambus-connect-iist.firebasestorage.app',
    iosBundleId: 'com.cambusconnect.app',
  );
}
