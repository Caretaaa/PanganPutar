import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identitas perangkat untuk mengunci kuota harian.
///
/// Kenapa bukan MAC address?
/// - Sejak Android 6, MAC Wi-Fi yang terbaca aplikasi sudah dianonimkan
///   (02:00:00:00:00:00), dan sejak Android 10 aplikasi TIDAK BOLEH membaca
///   MAC perangkat sama sekali (kebijakan privasi + pembatasan identifier).
/// - iOS sejak lama melarang akses MAC.
///
/// Penggantinya (setara secara praktik):
/// 1. ANDROID_ID / identifierForVendor — identitas stabil per perangkat
///    (bertahan walau aplikasi dihapus-pasang ulang dengan signing key sama,
///    dan tidak berubah saat pengguna mengganti akun).
/// 2. UUID instalasi yang dibuat sekali dan disimpan di perangkat.
///
/// Keduanya di-hash (SHA-256) menjadi [deviceId] — nilai mentah tidak pernah
/// dikirim/ditampilkan. Tujuannya bukan "anti-hacking mutlak" (perangkat
/// root tetap bisa dipalsukan), tetapi menaikkan biaya penyalahgunaan:
/// banyak akun di SATU perangkat tetap berbagi SATU kuota harian.
/// Produksi wajib menegakkan ulang di backend (header X-Device-Id) dan
/// menambah sinyal lain (Play Integrity, verifikasi nomor, dsb).
class DeviceIdentity extends ChangeNotifier {
  static const _keyUuid = 'pp_device_uuid_v1';

  String? _deviceId;
  String _displayId = '……';
  String _sumber = 'Belum dimuat';
  bool _loaded = false;

  String? get deviceId => _deviceId;

  /// ID pendek untuk ditampilkan ke pengguna, mis. `PP-3F9A-77C1`.
  String get displayId => _displayId;

  /// Sumber identitas (transparansi ke pengguna).
  String get sumber => _sumber;

  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    String? perangkatKeras;
    var sumber = 'UUID instalasi';

    try {
      if (!kIsWeb) {
        final info = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final android = await info.androidInfo;
          // ANDROID_ID: stabil per kombinasi pengguna + signing key.
          perangkatKeras = 'android:${android.id}';
          sumber = 'ANDROID_ID + UUID instalasi';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final ios = await info.iosInfo;
          final idfv = ios.identifierForVendor;
          if (idfv != null && idfv.isNotEmpty) {
            perangkatKeras = 'ios:$idfv';
            sumber = 'identifierForVendor + UUID instalasi';
          }
        }
      }
    } catch (_) {
      // Plugin tidak tersedia (mis. di unit test / platform tak didukung).
      // Jatuh ke UUID instalasi — aplikasi tetap berjalan.
      perangkatKeras = null;
      sumber = 'UUID instalasi (info perangkat tidak tersedia)';
    }

    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(_keyUuid);
    if (uuid == null || uuid.isEmpty) {
      uuid = _uuidV4();
      await prefs.setString(_keyUuid, uuid);
    }

    final basis = '${perangkatKeras ?? 'sw'}|$uuid';
    _deviceId = sha256.convert(utf8.encode(basis)).toString();
    _displayId = _formatDisplay(_deviceId!);
    _sumber = sumber;
    _loaded = true;
    notifyListeners();
  }

  static String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static String _formatDisplay(String hash) {
    final h = hash.toUpperCase();
    return 'PP-${h.substring(0, 4)}-${h.substring(4, 8)}';
  }
}
