import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'contracts.dart';
import 'firebase_settings.dart';

class AppAuthException implements Exception {
  final String message;
  const AppAuthException(this.message);
  @override
  String toString() => message;
}

/// Firebase Authentication (Google) + the user's Firestore profile.
///
/// The demo session (`SessionState`) remains completely separate. Signing in
/// here never calls `signInDemo`, and demo orders are never presented as real.
class FirebaseAuthService extends ChangeNotifier
    implements PanganAuthService {
  static final instance = FirebaseAuthService();

  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  bool _initialized = false;
  bool _busy = false;
  bool _disposed = false;

  String? _initializationError;
  String? _profileError;
  Map<String, dynamic>? _profile;

  @override
  bool get isReady => _auth != null;

  @override
  bool get isConfigured => FirebaseBootstrap.settings.isConfigured;

  @override
  bool get isSignedIn => _auth?.currentUser != null;

  @override
  bool get busy => _busy;

  @override
  String? get initializationError => _initializationError;

  @override
  String? get profileError => _profileError;

  @override
  String? get userId => _auth?.currentUser?.uid;

  @override
  String? get email => _auth?.currentUser?.email;

  @override
  String? get displayName =>
      (_profile?['display_name'] as String?)?.trim().isNotEmpty == true
      ? (_profile!['display_name'] as String).trim()
      : _auth?.currentUser?.displayName;

  @override
  String? get photoUrl =>
      (_profile?['photo_url'] as String?) ?? _auth?.currentUser?.photoURL;

  @override
  String? get role => _profile?['role'] as String?;

  @override
  String? get faceIdentityId => _profile?['face_identity_id'] as String?;

  @override
  DateTime? get faceVerifiedAt => _timestamp(_profile?['face_verified_at']);

  @override
  int? get weeklyPorsi => (_profile?['weekly_porsi'] as num?)?.toInt();

  @override
  int? get weeklyPesanan => (_profile?['weekly_pesanan'] as num?)?.toInt();

  @override
  int get maxPorsiPerWeek =>
      (_profile?['max_porsi_per_week'] as num?)?.toInt() ?? 4;

  @override
  int get maxPesananPerWeek =>
      (_profile?['max_pesanan_per_week'] as num?)?.toInt() ?? 2;

  @override
  bool get needsFaceVerification {
    if (faceIdentityId == null || faceIdentityId!.isEmpty) return true;
    final verified = faceVerifiedAt;
    if (verified == null) return true;
    return DateTime.now().difference(verified) > const Duration(days: 7);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!FirebaseBootstrap.isReady) {
      _initializationError =
          FirebaseBootstrap.initializationError ??
          'Firebase belum siap. Mode demo tetap tersedia.';
      _emit();
      return;
    }

    try {
      _auth = FirebaseAuth.instance;
      _authSub = _auth!.authStateChanges().listen((user) {
        if (_disposed) return;
        if (user == null) {
          _profile = null;
          _profileError = null;
          _profileSub?.cancel();
          _profileSub = null;
          _emit();
        } else {
          _watchProfile(user.uid);
          unawaited(_ensureProfile(user));
        }
      });
      final current = _auth!.currentUser;
      if (current != null) {
        _watchProfile(current.uid);
        await _ensureProfile(current);
      }
      _emit();
    } catch (error) {
      _initializationError =
          'Firebase Auth tidak dapat dimulai. Periksa konfigurasi aplikasi.';
      if (kDebugMode) debugPrint('FirebaseAuth initialize error: $error');
      _emit();
    }
  }

  void _watchProfile(String uid) {
    _profileSub?.cancel();
    _profileSub = FirebaseFirestore.instance
        .collection('profiles')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            if (_disposed) return;
            _profile = snap.data();
            _profileError = null;
            _emit();
          },
          onError: (Object error) {
            if (_disposed) return;
            _profileError =
                'Profil belum dapat dimuat. Periksa koneksi dan aturan '
                'Firestore.';
            _emit();
          },
        );
  }

  Future<void> _ensureProfile(User user) async {
    final ref = FirebaseFirestore.instance
        .collection('profiles')
        .doc(user.uid);
    try {
      final snap = await ref.get();
      final fallbackName = _fallbackName(user);
      if (!snap.exists) {
        await ref.set({
          'display_name': fallbackName,
          'role': 'penerima',
          'email': user.email,
          'photo_url': user.photoURL,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snap.data() ?? const <String, dynamic>{};
        // Backfill Google identity without overwriting a user-chosen name.
        final patch = <String, dynamic>{
          'updated_at': FieldValue.serverTimestamp(),
        };
        if ((data['email'] as String?)?.isNotEmpty != true &&
            user.email != null) {
          patch['email'] = user.email;
        }
        if ((data['photo_url'] as String?)?.isNotEmpty != true &&
            user.photoURL != null) {
          patch['photo_url'] = user.photoURL;
        }
        if (patch.length > 1) await ref.update(patch);
      }
      await refreshProfile();
    } catch (error) {
      _profileError =
          'Profil Firebase belum tersedia. Pastikan Firestore aktif dan '
          'aturan sudah diterapkan.';
      if (kDebugMode) debugPrint('ensureProfile error: $error');
      _emit();
    }
  }

  String _fallbackName(User user) {
    final raw = (user.displayName ?? user.email ?? '').trim();
    if (raw.length >= 3) return raw.length > 40 ? raw.substring(0, 40) : raw;
    return 'Pengguna';
  }

  @override
  Future<void> refreshProfile() async {
    final uid = userId;
    if (uid == null) {
      _profile = null;
      _profileError = null;
      _emit();
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      _profile = snap.data();
      _profileError = null;
    } catch (_) {
      _profileError =
          'Profil belum dapat dimuat. Periksa koneksi dan migrasi Firestore.';
    }
    _emit();
  }

  @override
  Future<bool> signInGoogle() async {
    if (!isReady) {
      throw AppAuthException(
        _initializationError ??
            'Firebase belum dikonfigurasi. Mode demo tetap tersedia.',
      );
    }
    return _perform(() async {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await _auth!.signInWithPopup(provider);
      } else {
        await _auth!.signInWithProvider(provider);
      }
      final user = _auth!.currentUser;
      if (user == null) return false;
      await _ensureProfile(user);
      return true;
    });
  }

  @override
  Future<void> signOut() => _perform(() async {
    await _auth?.signOut();
    _profile = null;
    _profileError = null;
    _profileSub?.cancel();
    _profileSub = null;
    _emit();
  });

  @override
  Future<void> updateProfile({
    required String name,
    required String role,
  }) => _perform(() async {
    final uid = userId;
    if (uid == null) throw const AppAuthException('Belum masuk.');
    final clean = name.trim();
    if (clean.length < 3 || clean.length > 40) {
      throw const AppAuthException('Nama harus berisi 3–40 karakter.');
    }
    if (role != 'penerima' && role != 'penyedia') {
      throw const AppAuthException('Peran akun tidak valid.');
    }
    await FirebaseFirestore.instance.collection('profiles').doc(uid).update({
      'display_name': clean,
      'role': role,
      'updated_at': FieldValue.serverTimestamp(),
    });
    await refreshProfile();
  });

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth?.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  Future<T> _perform<T>(Future<T> Function() operation) async {
    _busy = true;
    _profileError = null;
    _emit();
    try {
      return await operation();
    } on FirebaseAuthException catch (error) {
      throw AppAuthException(_authErrorMessage(error));
    } on FirebaseException catch (error) {
      throw AppAuthException(_firebaseErrorMessage(error));
    } finally {
      _busy = false;
      _emit();
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'popup-closed-by-user':
      case 'cancelled':
      case 'web-context-cancelled':
        return 'Masuk dengan Google dibatalkan.';
      case 'operation-not-allowed':
        return 'Google Sign-In belum diaktifkan di Firebase Console.';
      case 'unauthorized-domain':
        return 'Domain ini belum diizinkan di Firebase Auth → Authorized '
            'domains.';
      case 'account-exists-with-different-credential':
        return 'Email ini sudah memakai metode masuk lain.';
      case 'network-request-failed':
        return 'Jaringan bermasalah. Coba lagi.';
      default:
        return error.message ?? 'Masuk dengan Google gagal.';
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Akses Firestore ditolak. Pastikan aturan keamanan sudah '
          'diterapkan.';
    }
    if (error.code == 'unavailable') {
      return 'Layanan Firebase tidak terjangkau. Periksa koneksi.';
    }
    return error.message ?? 'Layanan Firebase gagal.';
  }

  static DateTime? _timestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
