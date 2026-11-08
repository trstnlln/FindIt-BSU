import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_options.dart';

class BackendSetup {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static Future<FirebaseApp> initialize() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    final app = await Firebase.initializeApp(
      options: useEmulators
          ? FirebaseOptions(
              apiKey: options.apiKey,
              appId: options.appId,
              messagingSenderId: options.messagingSenderId,
              projectId: 'demo-finditbsu',
              authDomain: 'localhost',
            )
          : options,
    );
    if (useEmulators) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
    }
    return app;
  }
}
