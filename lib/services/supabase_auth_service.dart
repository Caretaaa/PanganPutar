import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contracts.dart';
import 'supabase_settings.dart';

class AccountProfile {
  final String id;
  final String displayName;
  final String role;

  const AccountProfile({
    required this.id,
    required this.displayName,
    required this.role,
  });

  factory AccountProfile.fromJson(Map<String, Object?> json) => AccountProfile(
    id: json['id'] as String,
    displayName: json['display_name'] as String? ?? 'Pengguna',
    // Never interpret client metadata or an unknown role as administrator.
    role: json['role'] == 'penyedia' ? 'penyedia' : 'penerima',
  );
}

class AuthActionException implements Exception {
  final String message;
  const AuthActionException(this.message);
  @override
  String toString() => message;
}

/// Real Supabase identity, deliberately separate from local SessionState.
/// This service NEVER signs a user into the demo or claims a demo order is real.
class SupabaseAuthService extends ChangeNotifier implements PanganAuthService {
  static final instance = SupabaseAuthService();

  final SupabaseSettings settings;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  bool _initialized = false;
  bool _disposed = false;
  int _profileGeneration = 0;
  DateTime? _lastSmsRequest;

  String? initializationError;
  String? profileError;
  AccountProfile? profile;
  bool busy = false;
  bool recoveryRequired = false;

  SupabaseAuthService({SupabaseSettings? settings, this._client})
    : settings = settings ?? SupabaseSettings.fromEnvironment();

  bool get isReady => _client != null;
  bool get isConfigured => settings.isConfigured;
  bool get isSignedIn => user != null;
  User? get user => _client?.auth.currentUser;

  /// Access token aktif (ketika valid) — dipakai header Bearer ke Edge
  /// Functions pembayaran. Null bila belum masuk.
  String? get accessToken => _client?.auth.currentSession?.accessToken;
  String get redirectUrl =>
      settings.redirectUrl(isWeb: kIsWeb, currentUri: Uri.base);

  @override
  String? get userId => user?.id;

  @override
  String? get email => user?.email;

  @override
  String? get displayName => profile?.displayName;

  @override
  String? get photoUrl => user?.userMetadata?['avatar_url'] as String?;

  @override
  String? get role => profile?.role;

  /// Supabase legacy path tidak memiliki verifikasi wajah server.
  @override
  String? get faceIdentityId => null;

  @override
  DateTime? get faceVerifiedAt => null;

  @override
  int? get weeklyPorsi => null;

  @override
  int? get weeklyPesanan => null;

  @override
  int get maxPorsiPerWeek => 4;

  @override
  int get maxPesananPerWeek => 2;

  @override
  bool get needsFaceVerification => false;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _client?.auth.refreshSession();
    }
    return accessToken;
  }

  int get smsRetrySeconds {
    if (_lastSmsRequest == null) return 0;
    final remaining =
        60 - DateTime.now().difference(_lastSmsRequest!).inSeconds;
    return remaining.clamp(0, 60);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (_client == null) {
      initializationError = settings.configurationError;
      if (!settings.isConfigured || initializationError != null) {
        _emit();
        return;
      }
      try {
        await Supabase.initialize(
          url: settings.url.trim(),
          publishableKey: settings.publishableKey.trim(),
          debug: false,
        );
        _client = Supabase.instance.client;
      } catch (_) {
        initializationError = 'Supabase belum dapat diinisialisasi. Periksa konfigurasi dan mulai ulang aplikasi.';
        _emit();
        return;
      }
    }
    _subscription = _client!.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          recoveryRequired = true;
        }
        if (state.event == AuthChangeEvent.signedOut) {
          recoveryRequired = false;
          profile = null;
          profileError = null;
          _profileGeneration++;
          _emit();
        } else {
          _emit();
          unawaited(refreshProfile());
        }
      },
      onError: (Object error, StackTrace stack) {
        profileError =
            'Sesi belum dapat diperbarui. Periksa koneksi atau masuk kembali.';
        _emit();
      },
    );
    await refreshProfile();
    _emit();
  }

  Future<void> refreshProfile() async {
    final id = user?.id;
    final generation = ++_profileGeneration;
    if (id == null) {
      profile = null;
      profileError = null;
      _emit();
      return;
    }
    try {
      final data = await _client!
          .from('profiles')
          .select('id, display_name, role')
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (generation != _profileGeneration || user?.id != id || _disposed) {
        return;
      }
      profile = data == null ? null : AccountProfile.fromJson(data);
      profileError = data == null
          ? 'Profil belum tersedia. Terapkan migrasi Supabase lalu muat ulang profil.'
          : null;
    } catch (_) {
      if (generation != _profileGeneration || user?.id != id || _disposed) {
        return;
      }
      profileError =
          'Profil belum dapat dimuat. Periksa koneksi dan migrasi database.';
    }
    _emit();
  }

  /// True only if Supabase returned a real session. False requires email confirmation.
  Future<bool> signUpEmail({
    required String email,
    required String password,
    required String name,
  }) => _perform(() async {
    _validateEmail(email);
    _validate(displayNameValidationError(name));
    _validate(passwordValidationError(password));
    final response = await _client!.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: redirectUrl,
    );
    await refreshProfile();
    return response.session != null;
  });

  Future<void> signInEmail({required String email, required String password}) =>
      _perform(() async {
        _validateEmail(email);
        if (password.isEmpty) {
          throw const AuthActionException('Isi kata sandi.');
        }
        await _client!.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        await refreshProfile();
      });

  /// A true result means the browser opened, NOT that authentication succeeded.
  Future<bool> signInGoogle() => _perform(
    () => _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    ),
  );

  Future<void> sendPhoneOtp(String phone) => _perform(() async {
    _validate(phoneValidationError(phone));
    if (smsRetrySeconds > 0) {
      throw AuthActionException(
        'Tunggu $smsRetrySeconds detik sebelum meminta SMS lagi.',
      );
    }
    await _client!.auth.signInWithOtp(
      phone: phone.trim(),
      channel: OtpChannel.sms,
    );
    _lastSmsRequest = DateTime.now();
  });

  Future<void> verifyPhoneOtp({required String phone, required String code}) =>
      _perform(() async {
        _validate(phoneValidationError(phone));
        if (!RegExp(r'^[0-9]{6,10}$').hasMatch(code.trim())) {
          throw const AuthActionException(
            'Masukkan kode OTP dari SMS (6–10 digit).',
          );
        }
        await _client!.auth.verifyOTP(
          type: OtpType.sms,
          phone: phone.trim(),
          token: code.trim(),
        );
        await refreshProfile();
      });

  Future<void> resetPassword(String email) => _perform(() async {
    _validateEmail(email);
    await _client!.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectUrl,
    );
  });

  Future<void> resendConfirmation(String email) => _perform(() async {
    _validateEmail(email);
    await _client!.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: redirectUrl,
    );
  });

  Future<void> updatePassword(String password) => _perform(() async {
    _requireSignedIn();
    _validate(passwordValidationError(password));
    await _client!.auth.updateUser(UserAttributes(password: password));
    recoveryRequired = false;
  });

  Future<void> updateProfile({required String name, required String role}) =>
      _perform(() async {
        _requireSignedIn();
        _validate(displayNameValidationError(name));
        if (role != 'penerima' && role != 'penyedia') {
          throw const AuthActionException('Peran akun tidak valid.');
        }
        await _client!
            .from('profiles')
            .update({'display_name': name.trim(), 'role': role})
            .eq('id', user!.id);
        await refreshProfile();
      });

  Future<void> signOut() => _perform(() async {
    await _client!.auth.signOut(scope: SignOutScope.local);
    profile = null;
    profileError = null;
    recoveryRequired = false;
    _profileGeneration++;
  });

  Future<T> _perform<T>(Future<T> Function() operation) async {
    if (!isReady) {
      throw AuthActionException(
        initializationError ??
            'Supabase belum dikonfigurasi. Mode demo tetap tersedia.',
      );
    }
    if (busy) {
      throw const AuthActionException('Tunggu proses sebelumnya selesai.');
    }
    busy = true;
    _emit();
    try {
      return await operation();
    } on AuthActionException {
      rethrow;
    } on AuthException catch (error) {
      throw AuthActionException(_authMessage(error));
    } catch (_) {
      throw const AuthActionException(
        'Proses belum berhasil. Periksa koneksi dan konfigurasi layanan, lalu coba lagi.',
      );
    } finally {
      busy = false;
      _emit();
    }
  }

  static String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == '429' || message.contains('rate limit')) {
      return 'Terlalu banyak permintaan. Tunggu sebentar sebelum mencoba lagi.';
    }
    if (message.contains('email not confirmed')) {
      return 'Verifikasi email terlebih dahulu melalui tautan yang dikirim.';
    }
    if (message.contains('invalid login credentials')) {
      return 'Email atau kata sandi tidak cocok.';
    }
    if (message.contains('invalid api key') ||
        error.code == 'invalid_api_key') {
      return 'URL proyek Supabase dan publishable key tidak cocok. Periksa '
          'config/supabase.production.json.';
    }
    if (message.contains('redirect')) {
      return 'URL kembali web belum diizinkan. Jalankan aplikasi di port 8080 '
          'dan tambahkan http://localhost:8080/ ke Supabase → Authentication '
          '→ URL Configuration → Redirect URLs.';
    }
    if (message.contains('already registered') ||
        message.contains('already exists') ||
        error.code == 'user_already_exists') {
      return 'Email ini sudah terdaftar. Pilih Masuk atau gunakan Lupa kata sandi.';
    }
    if (message.contains('database error saving new user')) {
      return 'Supabase belum siap membuat akun. Pastikan migrasi database '
          'PanganPutar sudah diterapkan.';
    }
    if (message.contains('token') || message.contains('otp')) {
      return 'Kode atau tautan tidak valid atau sudah kedaluwarsa. Minta yang baru.';
    }
    if (message.contains('provider') || message.contains('disabled')) {
      return 'Metode masuk ini belum aktif. Periksa konfigurasi penyedia di Supabase.';
    }
    if (kDebugMode) {
      final details = <String>[
        if (error.statusCode != null) 'HTTP ${error.statusCode}',
        if (error.code != null) 'kode ${error.code}',
        if (error.message.isNotEmpty) error.message,
      ];
      return details.isEmpty
          ? 'Autentikasi gagal tanpa detail dari layanan.'
          : 'Autentikasi gagal: ${details.join(' · ')}';
    }
    return 'Autentikasi belum berhasil. Periksa data, koneksi, dan konfigurasi penyedia login.';
  }

  static void _validate(String? message) {
    if (message != null) throw AuthActionException(message);
  }

  static void _validateEmail(String email) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const AuthActionException('Masukkan alamat email yang valid.');
    }
  }

  void _requireSignedIn() {
    if (!isSignedIn) {
      throw const AuthActionException('Masuk kembali untuk melanjutkan.');
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profileGeneration++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
