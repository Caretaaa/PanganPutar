import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/core/security_rules.dart';
import 'package:panganputar_flutter/models/models.dart';

FoodListing _listing({
  String status = 'tersedia',
  int stok = 5,
  DateTime? pickupEnd,
  String alamat = 'Jl. Contoh No. 12, Bandung',
  String? storageNote = 'Simpan suhu ruang.',
  String? allergenInfo = 'Mengandung telur.',
  int durasiJam = 4,
}) {
  final now = DateTime.now().toUtc();
  return FoodListing(
    id: 'x-1',
    providerId: 'p-1',
    title: 'Nasi kotak',
    category: 'nasi',
    quantityTotal: 10,
    quantityAvailable: stok,
    unit: 'porsi',
    priceRupiah: 0,
    isFree: true,
    city: 'Bandung',
    district: '',
    pickupAddress: alamat,
    pickupStart: now.add(const Duration(hours: 1)),
    pickupEnd: (pickupEnd ?? now.add(Duration(hours: durasiJam))).toUtc(),
    storageNote: storageNote,
    allergenInfo: allergenInfo,
    status: status,
  );
}

void main() {
  group('kuota harian per perangkat', () {
    test('hari key format lokal yyyy-mm-dd', () {
      expect(dayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(dayKey(DateTime(2026, 12, 9)), '2026-12-09');
    });

    test('menerima pesanan selama kuota tersedia', () {
      const limits = DailyClaimLimits();
      final usage = DailyUsage(day: dayKey(DateTime.now()), porsi: 2, pesanan: 1);
      final r = canClaimDaily(usage: usage, porsi: 2, limits: limits);
      expect(r.ok, isTrue);
      expect(r.sisaPorsi, 2);
      expect(r.sisaPesanan, 1);
    });

    test('menolak bila porsi melebihi sisa kuota', () {
      final usage = DailyUsage(day: dayKey(DateTime.now()), porsi: 3, pesanan: 1);
      final r = canClaimDaily(usage: usage, porsi: 2);
      expect(r.ok, isFalse);
      expect(r.reason, contains('Sisa kuota harian perangkat tinggal 1 porsi'));
    });

    test('menolak bila batas jumlah pesanan harian tercapai', () {
      final usage = DailyUsage(day: dayKey(DateTime.now()), porsi: 1, pesanan: 2);
      final r = canClaimDaily(usage: usage, porsi: 1);
      expect(r.ok, isFalse);
      expect(r.reason, contains('Batas pesanan harian perangkat tercapai'));
    });

    test('kuota hari lama dianggap kosong (reset ganti hari)', () {
      final usage = DailyUsage(day: '2000-01-01', porsi: 4, pesanan: 2);
      final r = canClaimDaily(usage: usage, porsi: 4);
      expect(r.ok, isTrue);
      expect(r.sisaPorsi, 4);
    });

    test('menolak jumlah nol atau negatif', () {
      final usage = DailyUsage(day: dayKey(DateTime.now()));
      expect(canClaimDaily(usage: usage, porsi: 0).ok, isFalse);
      expect(canClaimDaily(usage: usage, porsi: -1).ok, isFalse);
    });
  });

  group('validasi toko penyedia', () {
    ProviderApplication app({
      String nama = 'Warung Bu Sari',
      String nomor = '1234567890123',
      String telepon = '081234567890',
      String alamat = 'Jl. Merdeka No. 10, RT 2, Bandung',
      String kota = 'Bandung',
      bool foto = true,
      bool lokasi = true,
    }) => ProviderApplication(
      namaToko: nama,
      jenisUsaha: 'Warung makan',
      nomorUsaha: nomor,
      telepon: telepon,
      alamat: alamat,
      kota: kota,
      adaFotoToko: foto,
      adaTitikLokasi: lokasi,
    );

    test('data lengkap valid dengan skor bukti penuh', () {
      final a = app();
      expect(validateProviderApplication(a).valid, isTrue);
      expect(skorBuktiToko(a), 100);
    });

    test('tanpa foto toko ditolak validasi', () {
      final v = validateProviderApplication(app(foto: false));
      expect(v.valid, isFalse);
      expect(v['fotoToko'], isNotNull);
    });

    test('tanpa titik lokasi ditolak validasi', () {
      final v = validateProviderApplication(app(lokasi: false));
      expect(v.valid, isFalse);
      expect(v['titikLokasi'], isNotNull);
    });

    test('NIB bukan 13 digit ditolak', () {
      final v = validateProviderApplication(app(nomor: '12345678901'));
      expect(v.valid, isFalse);
      expect(v['nomorUsaha'], contains('13–20 digit'));
    });

    test('alamat terlalu pendek ditolak (bukti toko fisik)', () {
      final v = validateProviderApplication(app(alamat: 'Jl. A'));
      expect(v.valid, isFalse);
      expect(v['alamat'], isNotNull);
    });

    test('review data lengkap auto-terverifikasi di demo', () {
      final review = reviewProvider(app());
      expect(review.status, ProviderStatus.terverifikasi);
      expect(review.skor, 100);
    });

    test('review data tidak lengkap menunggu tinjauan manual', () {
      final review = reviewProvider(app(foto: false));
      expect(review.status, ProviderStatus.menungguReview);
      expect(review.catatan, isNotEmpty);
    });

    test('kode status bolak-balik stabil', () {
      for (final s in ProviderStatus.values) {
        expect(providerStatusFromCode(providerStatusToCode(s)), s);
      }
      expect(providerStatusFromCode(null), ProviderStatus.belumDiajukan);
      expect(providerStatusFromCode('ngawur'), ProviderStatus.belumDiajukan);
    });
  });

  group('daftar periksa keamanan penawaran', () {
    test('penawaran lengkap + toko terverifikasi lulus semua', () {
      final report = evaluateListingSafety(
        listing: _listing(),
        providerStatus: ProviderStatus.terverifikasi,
      );
      expect(report.wajibLulus, isTrue);
      expect(report.jumlahLulus, report.jumlah);
    });

    test('toko belum terverifikasi tidak menggagalkan syarat wajib', () {
      final report = evaluateListingSafety(
        listing: _listing(),
        providerStatus: ProviderStatus.belumDiajukan,
      );
      expect(report.wajibLulus, isTrue);
      expect(report.jumlahLulus, lessThan(report.jumlah));
    });

    test('penawaran kedaluwarsa menggagalkan syarat wajib', () {
      final report = evaluateListingSafety(
        listing: _listing(
          pickupEnd: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        ),
        providerStatus: ProviderStatus.terverifikasi,
      );
      expect(report.wajibLulus, isFalse);
    });
  });

  group('gerbang pesanan gabungan', () {
    test('diizinkan saat stok ada, kuota tersedia, toko terverifikasi', () {
      final g = guardOrder(
        listing: _listing(),
        quantity: 2,
        providerStatus: ProviderStatus.terverifikasi,
        usage: DailyUsage(day: dayKey(DateTime.now())),
      );
      expect(g.allowed, isTrue);
      expect(g.blockers, isEmpty);
      expect(g.warnings, isEmpty);
    });

    test('diblokir saat kuota harian perangkat habis', () {
      final g = guardOrder(
        listing: _listing(),
        quantity: 1,
        providerStatus: ProviderStatus.terverifikasi,
        usage: DailyUsage(day: dayKey(DateTime.now()), porsi: 4, pesanan: 2),
      );
      expect(g.allowed, isFalse);
      expect(g.blockers.join(' '), contains('Batas pesanan harian'));
    });

    test('diblokir saat penyedia ditolak verifikasinya', () {
      final g = guardOrder(
        listing: _listing(),
        quantity: 1,
        providerStatus: ProviderStatus.ditolak,
        usage: DailyUsage(day: dayKey(DateTime.now())),
      );
      expect(g.allowed, isFalse);
      expect(g.blockers.join(' '), contains('ditolak verifikasinya'));
    });

    test('peringatan (bukan blokir) saat toko belum diverifikasi', () {
      final g = guardOrder(
        listing: _listing(),
        quantity: 1,
        providerStatus: ProviderStatus.belumDiajukan,
        usage: DailyUsage(day: dayKey(DateTime.now())),
      );
      expect(g.allowed, isTrue);
      expect(g.warnings.join(' '), contains('belum mengajukan verifikasi'));
    });

    test('diblokir saat stok kurang (aturan stok tetap berlaku)', () {
      final g = guardOrder(
        listing: _listing(stok: 1),
        quantity: 2,
        providerStatus: ProviderStatus.terverifikasi,
        usage: DailyUsage(day: dayKey(DateTime.now())),
      );
      expect(g.allowed, isFalse);
      expect(g.blockers.join(' '), contains('melebihi stok'));
    });
  });
}
