import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security_rules.dart';

/// Buku besar kuota harian yang DIKUNCI KE PERANGKAT.
///
/// Kunci penyimpanan memakai ID perangkat (hash dari DeviceIdentity), bukan
/// akun. Artinya: berapa pun akun yang dibuat/dipakai di satu HP, kuota
/// hariannya tetap satu dan sama. Ini yang mencegah oknum bikin banyak akun
/// untuk mengambil makanan berkali-kali.
///
/// Catatan produksi:
/// - Nilai di sini bisa dimodifikasi pengguna (perangkat root / hapus data).
///   Backend WAJIB menegakkan ulang kuota dengan header X-Device-Id.
/// - Kuota dipakai saat pesanan dibuat. Pesanan yang dibatalkan TIDAK
///   mengembalikan kuota (anti-penyalahgunaan: cegah pesan-batalkan berulang).
class DailyClaimLedger extends ChangeNotifier {
  static const _keyPrefix = 'pp_claim_usage_';

  final DailyClaimLimits limits;

  String? _deviceKey;
  String _day = '';
  int _pesanan = 0;
  int _porsi = 0;
  bool _loaded = false;

  DailyClaimLedger({this.limits = const DailyClaimLimits()});

  bool get loaded => _loaded;

  int get pesananHariIni => _pesanan;
  int get porsiHariIni => _porsi;

  DailyUsage get usage =>
      DailyUsage(day: _day, pesanan: _pesanan, porsi: _porsi);

  int get sisaPorsi {
    final sisa = limits.maxPorsiPerHari - _porsi;
    return sisa < 0 ? 0 : sisa;
  }

  int get sisaPesanan {
    final sisa = limits.maxPesananPerHari - _pesanan;
    return sisa < 0 ? 0 : sisa;
  }

  /// Muat kuota untuk [deviceId]. Dipanggil sekali setelah identitas siap.
  Future<void> load(String deviceId) async {
    _deviceKey = deviceId;
    final prefs = await SharedPreferences.getInstance();
    _day = dayKey(DateTime.now());
    _pesanan = 0;
    _porsi = 0;

    final raw = prefs.getString('$_keyPrefix$deviceId');
    if (raw != null) {
      final parts = raw.split('|');
      if (parts.length == 3 && parts[0] == _day) {
        _pesanan = int.tryParse(parts[1]) ?? 0;
        _porsi = int.tryParse(parts[2]) ?? 0;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  ClaimDecision check(int porsi, {int pesananDiminta = 1, DateTime? now}) {
    return canClaimDaily(
      usage: usage,
      porsi: porsi,
      pesananDiminta: pesananDiminta,
      limits: limits,
      now: now ?? DateTime.now(),
    );
  }

  /// Catat pemakaian setelah pesanan berhasil dibuat.
  Future<void> record(int porsi, {int pesanan = 1}) async {
    _rolloverIfNeeded();
    _porsi += porsi;
    _pesanan += pesanan;
    await _persist();
    notifyListeners();
  }

  /// Reset manual (hanya untuk demo/pengujian, bukan untuk pengguna umum).
  Future<void> resetForDemo() async {
    _rolloverIfNeeded();
    _porsi = 0;
    _pesanan = 0;
    await _persist();
    notifyListeners();
  }

  void _rolloverIfNeeded() {
    final today = dayKey(DateTime.now());
    if (_day != today) {
      _day = today;
      _pesanan = 0;
      _porsi = 0;
    }
  }

  Future<void> _persist() async {
    final key = _deviceKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$key', '$_day|$_pesanan|$_porsi');
  }
}
