import 'dart:convert';

/// Public client configuration only. Secrets never belong in a Flutter build.
class SupabaseSettings {
  final String url;
  final String publishableKey;
  final String mobileRedirect;
  final String webRedirect;

  const SupabaseSettings({
    this.url = '',
    this.publishableKey = '',
    this.mobileRedirect = 'id.panganputar.app://auth/callback',
    this.webRedirect = '',
  });

  factory SupabaseSettings.fromEnvironment() => const SupabaseSettings(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    ),
    mobileRedirect: String.fromEnvironment(
      'SUPABASE_AUTH_REDIRECT_URL',
      defaultValue: 'id.panganputar.app://auth/callback',
    ),
    webRedirect: String.fromEnvironment('SUPABASE_WEB_REDIRECT_URL'),
  );

  bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;
  bool get hasAnyConfiguration =>
      url.trim().isNotEmpty || publishableKey.trim().isNotEmpty;

  String? get configurationError {
    if (!hasAnyConfiguration) return null;
    if (!isConfigured) {
      return 'SUPABASE_URL dan publishable key harus diisi bersama.';
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_validServer(uri)) {
      return 'Gunakan URL proyek Supabase HTTPS yang valid.';
    }
    final key = publishableKey.trim();
    if (key.startsWith('sb_secret_')) {
      return 'Secret key tidak boleh dipakai di aplikasi. Gunakan publishable key.';
    }
    if (!key.startsWith('sb_publishable_') && !_isLegacyAnonKey(key)) {
      return 'Gunakan publishable key atau legacy anon key, bukan service_role atau token pengguna.';
    }
    final callback = Uri.tryParse(mobileRedirect);
    if (callback == null || callback.scheme.isEmpty || callback.host.isEmpty) {
      return 'URL callback Android tidak valid.';
    }
    if (webRedirect.isNotEmpty) {
      final web = Uri.tryParse(webRedirect);
      if (web == null || !_validWebRedirect(web)) {
        return 'URL callback web harus HTTPS (atau localhost untuk pengembangan).';
      }
    }
    return null;
  }

  String redirectUrl({required bool isWeb, required Uri currentUri}) {
    if (!isWeb) return mobileRedirect;
    if (webRedirect.isNotEmpty) return webRedirect;
    // Drop OAuth query/fragment data rather than returning tokens in redirects.
    return Uri(
      scheme: currentUri.scheme,
      host: currentUri.host,
      port: currentUri.hasPort ? currentUri.port : null,
      path: currentUri.path.isEmpty ? '/' : currentUri.path,
    ).toString();
  }

  static bool _validServer(Uri uri) =>
      _validWebRedirect(uri) &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;

  static bool _validWebRedirect(Uri uri) =>
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.scheme == 'https' ||
          (uri.scheme == 'http' &&
              const [
                'localhost',
                '127.0.0.1',
                '10.0.2.2',
                '::1',
              ].contains(uri.host)));

  static bool _isLegacyAnonKey(String key) {
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, Object?> && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}

/// Validation only; a matching format does not prove ownership of a number.
String? phoneValidationError(String phone) {
  if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone.trim())) {
    return 'Gunakan format internasional, misalnya +6281234567890.';
  }
  return null;
}

String? displayNameValidationError(String name) {
  final length = name.trim().length;
  return length < 3 || length > 40 ? 'Nama harus berisi 3–40 karakter.' : null;
}

String? passwordValidationError(String password) =>
    password.length < 8 ? 'Kata sandi minimal 8 karakter.' : null;
