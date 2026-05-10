// Bu dosya `flutterfire configure` komutuyla otomatik üretilir.
// Adımlar:
//   1. Firebase Console'da proje oluştur → https://console.firebase.google.com
//   2. Terminalde: dart pub global activate flutterfire_cli
//   3. Terminalde: flutterfire configure
//   4. Bu dosyanın içeriği otomatik doldurulacak.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Bu platform için FirebaseOptions tanımlı değil.',
        );
    }
  }

  // ── Aşağıdaki değerleri Firebase Console > Proje Ayarları'ndan alın ──

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBDz_UBu1B3A577Xc7foj0eY5CiHdwlCxc',
    appId: '1:800976221535:web:5d6f250bf6b983867af2ea',
    messagingSenderId: '800976221535',
    projectId: 'kibris-market',
    authDomain: 'kibris-market.firebaseapp.com',
    storageBucket: 'kibris-market.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDo_XE9Gf-E3Md68WLZTg8zldFn-b61_rw',
    appId:             '1:800976221535:android:88bee302cdffbe8e7af2ea',
    messagingSenderId: '800976221535',
    projectId:         'kibris-market',
    storageBucket:     'kibris-market.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBnFxz69nUFwcYDesHQ9LWdD-DzD5JruVU',
    appId:             '1:800976221535:ios:2c735645db9fbc557af2ea',
    messagingSenderId: '800976221535',
    projectId:         'kibris-market',
    storageBucket:     'kibris-market.firebasestorage.app',
    iosBundleId:       'com.example.kibrisMarket',
  );
}