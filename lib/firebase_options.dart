import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB98nKyylZ57fM8OZkbDaiNPHf0KhJCimE',
    appId: '1:983417377998:android:26e41e5de6f1668c90ac9f',
    messagingSenderId: '983417377998',
    projectId: 'fanmining-dcdc0',
    databaseURL: 'https://fanmining-dcdc0-default-rtdb.firebaseio.com',
    storageBucket: 'fanmining-dcdc0.firebasestorage.app',
  );
}
