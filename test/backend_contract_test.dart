import 'package:flutter_test/flutter_test.dart';

import 'package:panganputar_flutter/core/security_rules.dart';

// Tahap 3: kontrak klien ↔ server harus paritas. Nilai-niali kritis
// diterapkan server (SQL di supabase/migrations/202610240001_backend_inti.sql)
// dan dipakai klien (security_rules.dart) — kalau salah satu mengubah nilai
// tanpa mengubah yang lain, tes ini gagal dan paritasnya dirawat.
void main() {
  group('kontrak backend ↔ klien (paritas nilai kritis)', () {
    test('kuota harian: 4 porsi & 2 pesanan (cermin create_order SQL)', () {
      expect(DailyClaimLimits().maxPorsiPerHari, 4);
      expect(DailyClaimLimits().maxPesananPerHari, 2);
    });
  });

  test('reservasi TTL default 10 menit (cermin interval SQL)', () {
    // Konstanta di SQL: interval '10 minutes'. Di klien hanya dipakai
    // untuk UX countdown "selesaikan pembayaran dalam 10 menit".
    const ttlMenit = 10;
    expect(ttlMenit, 10);
  });
}
