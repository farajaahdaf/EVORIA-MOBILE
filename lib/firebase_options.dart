import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web tidak didukung');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Platform tidak didukung');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBvFYf_ctPJK7yUn4GuP3VRW52Xue9VqcY',
    appId: '1:487262848447:android:0ccaf8501326640b828d0a',
    messagingSenderId: '487262848447',
    projectId: 'evoria-859bb',
    storageBucket: 'evoria-859bb.firebasestorage.app',
  );

  // iOS belum dikonfigurasi — tambahkan app iOS di Firebase Console jika diperlukan
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBvFYf_ctPJK7yUn4GuP3VRW52Xue9VqcY',
    appId: '1:487262848447:ios:000000000000000000000000',
    messagingSenderId: '487262848447',
    projectId: 'evoria-859bb',
    storageBucket: 'evoria-859bb.firebasestorage.app',
    iosBundleId: 'com.evoria.evoriaMobile',
  );
}
