// PLACEHOLDER — gerado de verdade por `flutterfire configure`.
//
// Rode (com Firebase CLI logado e projeto criado):
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=clube-panda
//
// Isso sobrescreve este arquivo com as chaves reais e adiciona
// google-services.json (Android) e GoogleService-Info.plist (iOS).
// Até lá, os valores abaixo são fictícios e o app não conecta.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _placeholder;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _placeholder;
      case TargetPlatform.iOS:
        return _placeholder;
      default:
        return _placeholder;
    }
  }

  static const FirebaseOptions _placeholder = FirebaseOptions(
    apiKey: 'TODO_API_KEY',
    appId: 'TODO_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'clube-panda',
    storageBucket: 'clube-panda.appspot.com',
  );
}
