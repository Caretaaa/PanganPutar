import 'package:flutter_test/flutter_test.dart';

import 'package:panganputar_flutter/core/pickup_rules.dart';

// Tahap 5: pembaca token dari hasil pindai penyedia (produksi).
// Keputusan akhir selalu di server (hash) — ini hanya pemformat masukan.
void main() {
  group('tokenDariPindai', () {
    test('terima token telanjang PP-… (dinormalkan huruf besar)', () {
      expect(tokenDariPindai('PP-A1B2C3D4E5F6'), 'PP-A1B2C3D4E5F6');
      expect(tokenDariPindai('  pp-aabbccddeeff '), 'PP-AABBCCDDEEFF');
    });

    test('terima QR tiket panganputar://ambil (k=…)', () {
      final qr = PickupTicket(
        orderId: 'ord-1',
        kode: 'PP-A1B2C3D4E5F6',
        providerId: 'toko-1',
      ).encode();
      expect(tokenDariPindai(qr), 'PP-A1B2C3D4E5F6');
    });

    test('tolak QR toko dan teks asing (bukan token, jangan dikarang)', () {
      final qrToko = StoreQr(providerId: 'toko-1', namaToko: 'Bu Sari')
          .encode();
      expect(tokenDariPindai(qrToko), '');
      expect(tokenDariPindai('PanganPutar tiket 123'), '');
      expect(tokenDariPindai('https://example.com/x'), '');
      expect(tokenDariPindai(''), '');
    });

    test('dua-duanya menghasilkan token yang dinormalisasi sama', () {
      // Bentuk QR lengkap vs telanjang harus sama persis isinya.
      final qr = PickupTicket(
        orderId: 'ord-2',
        kode: 'PP-ABCDEF123456',
        providerId: 'toko-2',
      ).encode();
      expect(tokenDariPindai(qr), tokenDariPindai('PP-ABCDEF123456'));
    });
  });
}
