import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simpan plaintext token QR serah-terima HANYA di perangkat pembeli.
///
/// Ini bukan cadangan keamanan: server sudah menyimpan hash (SHA-256) di
/// `orders.pickup_token_hash` dan menolak QR yang sudah dipakai/dibatalkan.
/// Plaintext dikirim server sekali di respons RPC `create_order` — setelah
/// itu tidak bisa diambil ulang dari server (dengan sengaja). Kalau
/// perangkat menghapus data aplikasi, kode hilang: minta penyedia merilis
/// pesanan secara manual (tahap 6: alur dukungan).
///
/// Jalur demo tidak menyentuh vault ini — DemoStore punya simpanannya sendiri
/// (`pp_demo_orders_v1`). vault hanya untuk mode produksi.
class PickupTokenVault {
  PickupTokenVault._();

  static const _key = 'pp_pickup_tokens_v1';
  static Map<String, Map<String, String>> _cache = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cache = {
          for (final e in decoded.entries)
            if (e.value is Map<String, dynamic>)
              e.key: {
                'token': (e.value['token'] ?? '').toString(),
                'expiresAt': (e.value['expiresAt'] ?? '').toString(),
              },
        };
      }
    } catch (_) {
      // Data rusak: mulai kosong. Token ganda tidak berbahaya (ditolak
      // server) — lebih baik daripada mengarang kode.
      _cache = {};
    }
  }

  /// Dipakai tes untuk memulai vault kosong.
  static void resetForTest() {
    _cache = {};
    _loaded = false;
  }

  static String? tokenFor(String orderId) {
    final t = _cache[orderId];
    if (t == null) return null;
    final token = t['token'];
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<void> save({
    required String orderId,
    required String token,
    DateTime? reservationExpiresAt,
  }) async {
    _cache[orderId] = {
      'token': token,
      'expiresAt': reservationExpiresAt?.toIso8601String() ?? '',
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_cache));
    } catch (_) {
      // Gagal persist: token tetap hidup di memori sesi ini.
    }
  }
}