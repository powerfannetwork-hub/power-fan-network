import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web Firebase configuration is not configured.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS Firebase configuration is not configured.',
        );

      case TargetPlatform.macOS:
        throw UnsupportedError(
          'macOS Firebase configuration is not configured.',
        );

      case TargetPlatform.windows:
        throw UnsupportedError(
          'Windows Firebase configuration is not configured.',
        );

      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux Firebase configuration is not configured.',
        );

      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Fuchsia Firebase configuration is not configured.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB98nKyylZ57fM8OZkbDaiNPHf0KhJCimE',
    appId: '1:983417377998:android:26e41e5de6f1668c90ac9f',
    messagingSenderId: '983417377998',
    projectId: 'fanmining-dcdc0',
    storageBucket: 'fanmining-dcdc0.firebasestorage.app',
  );
}
