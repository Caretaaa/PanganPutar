import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/core/pickup_rules.dart';

void main() {
  group('generatePickupCode (kode acak per pengambilan)', () {
    test('format PP- + 8 karakter tanpa karakter membingungkan', () {
      final re = RegExp(r'^PP-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$');
      for (var i = 0; i < 50; i++) {
        expect(generatePickupCode(), matches(re));
      }
    });

    test('acak: tidak seperti kode berbasis waktu/urutan lama', () {
      final a = generatePickupCode();
      final b = generatePickupCode();
      expect(a.length, b.length);
      // Dengan seed yang sama hasilnya deterministik (ujung kejutan).
      expect(generatePickupCode(Random(7)), generatePickupCode(Random(7)));
      // Tanpa seed: dua panggilan jarang identik (32^8 kemungkinan).
      var beda = false;
      for (var i = 0; i < 8; i++) {
        if (generatePickupCode() != generatePickupCode()) {
          beda = true;
          break;
        }
      }
      expect(beda, isTrue);
    });
  });

  group('PickupTicket (QR tiket pembeli)', () {
    test('encode → parse bolak-balik utuh', () {
      const tiket = PickupTicket(
        orderId: 'demo-7',
        kode: 'PP-12345678',
        providerId: 'toko-a',
      );
      final raw = tiket.encode();
      expect(raw, startsWith('panganputar://ambil?'));

      final lagi = PickupTicket.parse(raw);
      expect(lagi, isNotNull);
      expect(lagi!.orderId, 'demo-7');
      expect(lagi.kode, 'PP-12345678');
      expect(lagi.providerId, 'toko-a');
    });

    test('tolak tautan asing, host salah, kurang parameter, versi beda', () {
      expect(PickupTicket.parse('https://contoh.id/qr'), isNull);
      expect(PickupTicket.parse('panganputar://toko?t=a'), isNull);
      expect(PickupTicket.parse('panganputar://ambil?o=1'), isNull);
      expect(PickupTicket.parse('panganputar://ambil?o=1&k=2'), isNull);
      expect(PickupTicket.parse('panganputar://ambil?k=2&t=3'), isNull);
      expect(
        PickupTicket.parse('panganputar://ambil?o=1&k=2&t=3&v=99'),
        isNull,
      );
      expect(PickupTicket.parse('   '), isNull);
    });

    test('parameter kosong / kepanjangan ditolak', () {
      expect(PickupTicket.parse('panganputar://ambil?o=&k=2&t=3'), isNull);
      final panjang = 'x' * 129;
      expect(
        PickupTicket.parse('panganputar://ambil?o=$panjang&k=2&t=3'),
        isNull,
      );
    });
  });

  group('StoreQr (QR toko)', () {
    test('encode → parse bolak-balik', () {
      const qr = StoreQr(providerId: 'toko-b', namaToko: 'Warung Bu Sari');
      final raw = qr.encode();
      expect(raw, startsWith('panganputar://toko?'));

      final lagi = StoreQr.parse(raw);
      expect(lagi, isNotNull);
      expect(lagi!.providerId, 'toko-b');
      expect(lagi.namaToko, 'Warung Bu Sari');
    });

    test('nama opsional; providerId wajib', () {
      final tanpaNama = StoreQr.parse('panganputar://toko?t=toko-c');
      expect(tanpaNama, isNotNull);
      expect(tanpaNama!.namaToko, '');
      expect(StoreQr.parse('panganputar://toko?n=hanya-nama'), isNull);
      expect(StoreQr.parse('panganputar://ambil?o=1&k=2&t=3'), isNull);
    });
  });

  group('checkPickupTicket (penyedia memindai tiket pembeli)', () {
    const tiket = PickupTicket(
      orderId: 'demo-1',
      kode: 'PP-777',
      providerId: 'toko-a',
    );

    ScanCheck cek({
      String? status = 'dikonfirmasi',
      String? kode = 'PP-777',
      String pemindai = 'toko-a',
      String? providerPesanan = 'toko-a',
      bool perluBayar = false,
      bool lunas = false,
      DateTime? end,
    }) => checkPickupTicket(
      tiket: tiket,
      scannerProviderId: pemindai,
      orderStatus: status,
      kodePesanan: kode,
      orderProviderId: providerPesanan,
      perluBayar: perluBayar,
      pembayaranLunas: lunas,
      pickupEnd: end,
      now: DateTime(2026, 1, 1, 12),
    );

    test('lolos: dikonfirmasi, kode & toko cocok, gratis', () {
      final c = cek();
      expect(c.ok, isTrue);
      expect(c.alasan, isNull);
      expect(c.peringatan, isNull);
    });

    test('lolos: siap_diambil', () {
      expect(cek(status: 'siap_diambil').ok, isTrue);
    });

    test('gagal: pesanan tidak ditemukan', () {
      final c = cek(status: null);
      expect(c.ok, isFalse);
      expect(c.alasan, contains('tidak ditemukan'));
    });

    test('gagal: kode QR tidak cocok dengan pesanan', () {
      final c = cek(kode: 'PP-999');
      expect(c.ok, isFalse);
      expect(c.alasan, contains('Kode pengambilan'));
    });

    test('gagal: tiket tidak konsisten (provider beda) — kemungkinan palsu',
        () {
      final c = cek(providerPesanan: 'toko-b');
      expect(c.ok, isFalse);
      expect(c.alasan, contains('tidak konsisten'));
    });

    test('gagal: pemindai bukan toko penerima — hak pindai diatur', () {
      final c = cek(pemindai: 'toko-lain');
      expect(c.ok, isFalse);
      expect(c.alasan, contains('hak'));
    });

    test('gagal: sudah dibatalkan / sudah diambil (anti QR dobel)', () {
      expect(cek(status: 'dibatalkan').alasan, contains('dibatalkan'));
      expect(cek(status: 'selesai').alasan, contains('sudah diambil'));
    });

    test('gagal: berbayar tapi belum lunas', () {
      final c = cek(perluBayar: true, lunas: false);
      expect(c.ok, isFalse);
      expect(c.alasan, contains('belum lunas'));

      expect(cek(perluBayar: true, lunas: true).ok, isTrue);
    });

    test('gagal: belum dikonfirmasi toko', () {
      final c = cek(status: 'menunggu');
      expect(c.ok, isFalse);
      expect(c.alasan, contains('belum dikonfirmasi'));
    });

    test('lolos dengan peringatan bila jendela ambil sudah berakhir', () {
      final c = cek(end: DateTime(2026, 1, 1, 10)); // now = 12:00
      expect(c.ok, isTrue);
      expect(c.peringatan, contains('berakhir'));
    });
  });

  group('checkStoreQr (pembeli memindai QR toko)', () {
    const qr = StoreQr(providerId: 'toko-a', namaToko: 'Warung Bu Sari');

    test('lolos: toko cocok & terverifikasi', () {
      final c = checkStoreQr(
        toko: qr,
        orderProviderId: 'toko-a',
        tokoTerverifikasi: true,
      );
      expect(c.ok, isTrue);
      expect(c.peringatan, isNull);
    });

    test('lolos dengan peringatan: toko cocok tetapi belum terverifikasi', () {
      final c = checkStoreQr(
        toko: qr,
        orderProviderId: 'toko-a',
        tokoTerverifikasi: false,
      );
      expect(c.ok, isTrue);
      expect(c.peringatan, contains('ditinjau'));
    });

    test('gagal: QR toko lain — lokasi salah', () {
      final c = checkStoreQr(
        toko: qr,
        orderProviderId: 'toko-lain',
        tokoTerverifikasi: true,
      );
      expect(c.ok, isFalse);
      expect(c.alasan, contains('bukan toko pesananmu'));
    });
  });
}
