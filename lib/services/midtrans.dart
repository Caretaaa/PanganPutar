import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/payment.dart';
import 'api_client.dart';
import 'contracts.dart';

/// Konfigurasi Midtrans.
///
/// KEAMANAN (baca sebelum produksi):
/// - SERVER KEY Midtrans TIDAK BOLEH berada di aplikasi mobile. Server key
///   hanya dipakai backend (Next.js) untuk memanggil API Snap.
/// - Aplikasi ini hanya menerima snap token + redirect URL dari backend
///   kita (`POST /api/payments/midtrans/snap`), tidak pernah menandatangani
///   transaksi sendiri.
/// - CLIENT KEY (dart-define MIDTRANS_CLIENT_KEY) hanya perlu bila memuat
///   snap.js langsung; dengan alur Snap Redirect tidak wajib.
/// - Webhook Midtrans (`order_id`, `status_code`, `gross_amount`,
///   `signature_key`) diverifikasi backend dengan SHA-512 + server key.
class MidtransConfig {
  static const String clientKey = String.fromEnvironment(
    'MIDTRANS_CLIENT_KEY',
    defaultValue: '',
  );

  static const bool isProduction = bool.fromEnvironment(
    'MIDTRANS_PRODUCTION',
    defaultValue: false,
  );

  static String get snapScriptUrl => isProduction
      ? 'https://app.midtrans.com/snap/snap.js'
      : 'https://app.sandbox.midtrans.com/snap/snap.js';

  static String get modeLabel => isProduction ? 'Produksi' : 'Sandbox';
}

/// Klien pembayaran: membuat sesi Snap lewat backend PanganPutar dan
/// mengecek status transaksi. Bila backend tidak terjangkau, otomatis
/// memakai MODE SIMULASI (jelas berlabel, tanpa uang nyata) supaya aplikasi
/// tetap bisa didemokan offline.
class MidtransPaymentService implements PaymentGateway {
  final String base;

  /// Path relatif buat sesi Snap & cek status. Default mengarah ke backend
  /// Next.js; mode produksi Supabase memakai Edge Functions
  /// ('/functions/v1/payments-snap', '/functions/v1/payments-status').
  final String snapPath;
  final String statusPrefix;

  /// Public Supabase key required by Edge Functions in addition to the user's
  /// access token. This is publishable/anon only, never service-role.
  final String apiKey;

  /// Dikembalikan saat tiap permintaan — access token Supabase (string jwt)
  /// supaya Edge Function bisa memverifikasi pemilik pesanan. Null di demo.
  final String? Function()? authToken;

  final http.Client _client;

  MidtransPaymentService({
    String? base,
    this.snapPath = '/api/payments/midtrans/snap',
    this.statusPrefix = '/api/payments/midtrans/status',
    this.apiKey = '',
    this.authToken,
    http.Client? client,
  })
    : base = (base ?? ApiConfig.defaultBase).replaceAll(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 10);

  Map<String, String> _headers(String? deviceId) {
    final token = authToken?.call();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey.isNotEmpty) 'apikey': apiKey,
      if (deviceId != null && deviceId.isNotEmpty) 'X-Device-Id': deviceId,
      // Edge Function butuh JWT Supabase milik pembeli (bukan service-role).
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Buat transaksi Snap lewat backend. Backend yang memanggil Midtrans
  /// (server key di backend) dan mengembalikan token + redirect URL.
  Future<SnapSession> createSnap({
    required String orderId,
    required int grossAmount,
    required List<PaymentItem> items,
    String? namaPembeli,
    String? deviceId,
  }) async {
    try {
      final r = await _client
          .post(
            Uri.parse('$base$snapPath'),
            headers: _headers(deviceId),
            body: jsonEncode({
              'orderId': orderId,
              'grossAmount': grossAmount,
              'items': items.map((e) => e.toJson()).toList(),
              'customer': {'nama': namaPembeli ?? 'Penerima PanganPutar'},
              // Perangkat pengunci kuota — backend menegakkan batas harian
              // berdasarkan nilai ini, bukan berdasarkan akun.
              'deviceId': deviceId,
            }),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final data = body['data'] is Map<String, Object?>
          ? body['data'] as Map<String, Object?>
          : body;
      final token = (data['token'] ?? '').toString();
      final redirect = (data['redirectUrl'] ?? data['redirect_url'] ?? '')
          .toString();
      if (token.isEmpty || redirect.isEmpty) {
        throw StateError('Respons backend tidak lengkap');
      }
      return SnapSession(
        orderId: orderId,
        token: token,
        redirectUrl: redirect,
        kedaluwarsa: DateTime.tryParse(
          (data['expiry'] ?? data['kedaluwarsa'] ?? '').toString(),
        ),
      );
    } catch (_) {
      // Fallback simulasi offline (tanpa uang nyata).
      return SnapSession(
        orderId: orderId,
        token: 'SIMULASI-${_acakSimulasi()}',
        redirectUrl: 'demo://snap/$orderId',
        kedaluwarsa: DateTime.now().add(const Duration(minutes: 30)),
        simulasi: true,
      );
    }
  }

  /// Cek status pembayaran ke backend. Null = backend tidak terjangkau
  /// (mode simulasi mengurus statusnya sendiri di layar pembayaran).
  Future<PaymentRecord?> checkStatus(
    String orderId, {
    required int grossAmount,
    String? deviceId,
  }) async {
    try {
      final r = await _client
          .get(
            Uri.parse('$base$statusPrefix/$orderId'),
            headers: _headers(deviceId),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final data = body['data'] is Map<String, Object?>
          ? body['data'] as Map<String, Object?>
          : body;
      final status = paymentStatusFromCode(
        (data['status'] ?? data['transactionStatus'] ?? '').toString(),
      );
      return PaymentRecord(
        orderId: orderId,
        grossAmount: data['grossAmount'] is num
            ? (data['grossAmount'] as num).toInt()
            : grossAmount,
        status: status,
        metode: data['metode']?.toString() ?? data['paymentType']?.toString(),
        transaksiId: data['transactionId']?.toString(),
        dibayarPada: DateTime.tryParse((data['paidAt'] ?? '').toString()),
      );
    } catch (_) {
      return null;
    }
  }

  static String _acakSimulasi() {
    final rnd = Random();
    return List.generate(
      8,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join().toUpperCase();
  }
}
