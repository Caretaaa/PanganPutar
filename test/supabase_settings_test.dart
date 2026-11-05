import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/services/supabase_settings.dart';

String _legacyKey(String role) {
  final body = base64Url.encode(utf8.encode(jsonEncode({'role': role})));
  return 'header.$body.signature';
}

void main() {
  const valid = SupabaseSettings(
    url: 'https://project.supabase.co',
    publishableKey: 'sb_publishable_example_only',
  );

  test('tanpa konfigurasi tetap unconfigured, bukan login palsu', () {
    const settings = SupabaseSettings();
    expect(settings.isConfigured, isFalse);
    expect(settings.hasAnyConfiguration, isFalse);
    expect(settings.configurationError, isNull);
  });

  test('konfigurasi parsial menjelaskan pasangan URL dan key', () {
    const settings = SupabaseSettings(url: 'https://project.supabase.co');
    expect(settings.isConfigured, isFalse);
    expect(settings.configurationError, isNotNull);
  });

  test('publishable key dan legacy anon diperbolehkan', () {
    expect(valid.configurationError, isNull);
    expect(
      SupabaseSettings(
        url: valid.url,
        publishableKey: _legacyKey('anon'),
      ).configurationError,
      isNull,
    );
  });

  test('secret, service role dan token pengguna ditolak', () {
    for (final key in [
      'sb_secret_private',
      _legacyKey('service_role'),
      _legacyKey('authenticated'),
      'invalid',
    ]) {
      expect(
        SupabaseSettings(
          url: valid.url,
          publishableKey: key,
        ).configurationError,
        isNotNull,
      );
    }
  });

  test('URL tidak aman atau berisi kredensial ditolak', () {
    for (final url in [
      'http://project.supabase.co',
      'https://user:pass@project.supabase.co',
      'https://project.supabase.co/rest/v1',
      'https://project.supabase.co?key=x',
    ]) {
      expect(
        SupabaseSettings(
          url: url,
          publishableKey: valid.publishableKey,
        ).configurationError,
        isNotNull,
      );
    }
    expect(
      SupabaseSettings(
        url: 'http://localhost:54321',
        publishableKey: valid.publishableKey,
      ).configurationError,
      isNull,
    );
  });

  test('callback web membuang query dan fragment sensitif', () {
    expect(
      valid.redirectUrl(
        isWeb: true,
        currentUri: Uri.parse(
          'https://example.com/pangan/?code=private#access_token=private',
        ),
      ),
      'https://example.com/pangan/',
    );
    expect(
      valid.redirectUrl(isWeb: false, currentUri: Uri.base),
      'id.panganputar.app://auth/callback',
    );
  });

  test('callback web eksplisit mendukung domain deploy', () {
    const settings = SupabaseSettings(webRedirect: 'https://example.com/app/');
    expect(
      settings.redirectUrl(
        isWeb: true,
        currentUri: Uri.parse('http://localhost:8080'),
      ),
      'https://example.com/app/',
    );
  });

  test('nomor telepon harus E.164 dan tidak disamakan dengan verifikasi', () {
    expect(phoneValidationError('+6281234567890'), isNull);
    for (final phone in [
      '081234567890',
      '+01234567890',
      '+62',
      'abc',
      '+628123456789012345',
    ]) {
      expect(phoneValidationError(phone), isNotNull);
    }
  });

  test('nama dan kata sandi divalidasi sebelum permintaan jaringan', () {
    expect(displayNameValidationError('  Sari  '), isNull);
    expect(displayNameValidationError('ab'), isNotNull);
    expect(passwordValidationError('1234567'), isNotNull);
    expect(passwordValidationError('test-password-123'), isNull);
  });
}
