import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:panganputar_flutter/services/session.dart';
import 'package:panganputar_flutter/services/supabase_auth_service.dart';
import 'package:panganputar_flutter/services/supabase_settings.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _settings = SupabaseSettings(
  url: 'https://project.supabase.co',
  publishableKey: 'sb_publishable_test_only',
);
const _user = {
  'id': _id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'sari@example.test',
  'created_at': '2026-10-19T00:00:00Z',
};

Map<String, Object?> _sessionResponse() {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': _id,
        'role': 'authenticated',
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }),
    ),
  );
  return {
    'access_token': '$header.$payload.c2lnbmF0dXJl',
    'refresh_token': 'test-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': _user,
  };
}

http.Response _json(Object body, [int status = 200]) {
  // postgrest's parser reads response.request!.headers — a bare Response
  // without `request:` crashes with "Null check operator used on a null
  // value" (only on PostgREST paths; gotrue's /token path never reads it).
  // Attach a synthetic request so mock responses look like streamed ones.
  final synthetic = http.Request('GET', Uri.parse('https://project.supabase.co/'));
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
    request: synthetic,
  );
}

Future<SupabaseAuthService> _service(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = SupabaseClient(
    _settings.url,
    _settings.publishableKey,
    httpClient: MockClient(handler),
    // HTTP contract tests do not install Flutter's PKCE storage. The shipped
    // Supabase.initialize path retains its default PKCE flow.
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  final service = SupabaseAuthService(settings: _settings, client: client);
  addTearDown(() async {
    service.dispose();
    await client.dispose();
  });
  await service.initialize();
  return service;
}

void main() {
  test(
    'tanpa konfigurasi auth dinonaktifkan dan tidak berpura-pura masuk',
    () async {
      final service = SupabaseAuthService(settings: const SupabaseSettings());
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.isReady, isFalse);
      await expectLater(
        service.signInEmail(email: 'sari@example.test', password: 'password'),
        throwsA(isA<AuthActionException>()),
      );
      expect(service.isSignedIn, isFalse);
    },
  );

  test('secret key ditolak sebelum inisialisasi jaringan', () async {
    final service = SupabaseAuthService(
      settings: const SupabaseSettings(
        url: 'https://project.supabase.co',
        publishableKey: 'sb_secret_not_for_clients',
      ),
    );
    addTearDown(service.dispose);
    await service.initialize();
    expect(service.isReady, isFalse);
    expect(service.initializationError, contains('Secret key'));
  });

  test('signup tanpa session menunggu verifikasi email', () async {
    final service = await _service((request) async {
      expect(request.url.path, '/auth/v1/signup');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect((body['data'] as Map<String, Object?>)['display_name'], 'Sari');
      expect(
        (body['data'] as Map<String, Object?>).containsKey('role'),
        isFalse,
      );
      return _json(_user);
    });
    expect(
      await service.signUpEmail(
        email: 'sari@example.test',
        password: 'password123',
        name: 'Sari',
      ),
      isFalse,
    );
    expect(service.isSignedIn, isFalse);
  });

  test('signin asli memuat profil tanpa mengubah sesi demo', () async {
    final demo = SessionState();
    final service = await _service((request) async {
      if (request.url.path.endsWith('/token')) return _json(_sessionResponse());
      return _json([
        {'id': _id, 'display_name': 'Sari', 'role': 'penerima'},
      ]);
    });
    await service.signInEmail(
      email: 'sari@example.test',
      password: 'password123',
    );
    await service.refreshProfile();
    expect(service.isSignedIn, isTrue);
    expect(service.profile?.displayName, 'Sari');
    expect(demo.isLoggedIn, isFalse);
    expect(service.busy, isFalse);
    demo.dispose();
  });

  test(
    'kredensial salah tidak membuat session dan memulihkan status busy',
    () async {
      final service = await _service(
        (_) async => _json({
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        }, 400),
      );
      await expectLater(
        service.signInEmail(email: 'sari@example.test', password: 'salah'),
        throwsA(
          isA<AuthActionException>().having(
            (e) => e.message,
            'message',
            contains('tidak cocok'),
          ),
        ),
      );
      expect(service.isSignedIn, isFalse);
      expect(service.busy, isFalse);
    },
  );

  test('SMS memakai E.164 dan membatasi pengiriman ulang lokal', () async {
    var sent = 0;
    final service = await _service((request) async {
      sent++;
      expect(request.url.path, '/auth/v1/otp');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['phone'], '+6281234567890');
      expect(body['channel'], 'sms');
      return _json({});
    });
    await service.sendPhoneOtp('+6281234567890');
    await expectLater(
      service.sendPhoneOtp('+6281234567890'),
      throwsA(isA<AuthActionException>()),
    );
    expect(sent, 1);
    expect(service.smsRetrySeconds, greaterThan(0));
    expect(service.isSignedIn, isFalse);
  });

  test('OTP gagal tidak membuat sesi palsu', () async {
    final service = await _service(
      (_) async => _json({
        'msg': 'Token has expired or is invalid',
        'error_code': 'otp_expired',
      }, 403),
    );
    await expectLater(
      service.verifyPhoneOtp(phone: '+6281234567890', code: '123456'),
      throwsA(
        isA<AuthActionException>().having(
          (e) => e.message,
          'message',
          contains('kedaluwarsa'),
        ),
      ),
    );
    expect(service.isSignedIn, isFalse);
  });

  test('reset email menggunakan callback Android yang terdaftar', () async {
    final service = await _service((request) async {
      expect(request.url.path, '/auth/v1/recover');
      expect(
        request.url.queryParameters['redirect_to'],
        _settings.mobileRedirect,
      );
      return _json({});
    });
    await service.resetPassword('sari@example.test');
    expect(service.isSignedIn, isFalse);
  });

  test('profil tak dikenal tidak menjadi admin', () {
    expect(
      AccountProfile.fromJson({'id': _id, 'role': 'admin'}).role,
      'penerima',
    );
  });
}
