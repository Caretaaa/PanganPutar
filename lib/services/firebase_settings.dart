import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public Firebase client configuration.
///
/// Only public identifiers belong here. Never put a service-account JSON,
/// Cloud Functions private key, Midtrans server key, or AWS secret in a
/// Flutter build. Those live in Cloud Functions secrets / environment.
class FirebaseSettings {
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String authDomain;
  final String storageBucket;
  final String measurementId;
  final String functionsRegion;

  const FirebaseSettings({
    this.apiKey = '',
    this.appId = '',
    this.messagingSenderId = '',
    this.projectId = '',
    this.authDomain = '',
    this.storageBucket = '',
    this.measurementId = '',
    this.functionsRegion = 'asia-southeast1',
  });

  factory FirebaseSettings.fromEnvironment() => const FirebaseSettings(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
    functionsRegion: String.fromEnvironment(
      'FIREBASE_FUNCTIONS_REGION',
      defaultValue: 'asia-southeast1',
    ),
  );

  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      messagingSenderId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty;

  String? get configurationError {
    if (isConfigured) return null;
    if (apiKey.trim().isEmpty &&
        appId.trim().isEmpty &&
        projectId.trim().isEmpty) {
      return 'Firebase belum dikonfigurasi. Isi FIREBASE_* lewat '
          '--dart-define-from-file=config/firebase.production.json.';
    }
    return 'Konfigurasi Firebase tidak lengkap: butuh API key, app ID, '
        'sender ID, dan project ID.';
  }

  FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey.trim(),
    appId: appId.trim(),
    messagingSenderId: messagingSenderId.trim(),
    projectId: projectId.trim(),
    authDomain: authDomain.trim().isEmpty ? null : authDomain.trim(),
    storageBucket: storageBucket.trim().isEmpty ? null : storageBucket.trim(),
    measurementId: measurementId.trim().isEmpty ? null : measurementId.trim(),
  );
}

/// Initializes Firebase once and keeps an honest error when the build has no
/// configuration. The demo path never pretends Firebase is ready.
class FirebaseBootstrap {
  static FirebaseSettings settings = FirebaseSettings.fromEnvironment();
  static FirebaseApp? app;
  static String? initializationError;
  static bool _attempted = false;

  static bool get isReady => app != null;

  static Future<void> initialize({FirebaseSettings? override}) async {
    if (_attempted) return;
    _attempted = true;
    settings = override ?? FirebaseSettings.fromEnvironment();
    final configError = settings.configurationError;
    if (configError != null) {
      initializationError = configError;
      return;
    }
    try {
      app = await Firebase.initializeApp(options: settings.options);
    } catch (error) {
      initializationError =
          'Firebase gagal diinisialisasi. Periksa konfigurasi dan mulai '
          'ulang aplikasi. (${error.runtimeType})';
      if (kDebugMode) debugPrint('Firebase initialize error: $error');
    }
  }
}
