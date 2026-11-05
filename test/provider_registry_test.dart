import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/core/security_rules.dart';
import 'package:panganputar_flutter/services/provider_registry.dart';

ProviderApplication _aplikasiValid({bool foto = true, bool lokasi = true}) =>
    ProviderApplication(
      namaToko: 'Warung Test',
      jenisUsaha: 'Warung makan',
      nomorUsaha: '1234567890123',
      telepon: '081234567890',
      alamat: 'Jl. Merdeka No. 10, Bandung',
      kota: 'Bandung',
      adaFotoToko: foto,
      adaTitikLokasi: lokasi,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('seed demo: penyedia-1 terverifikasi, penyedia-2 menunggu review',
      () async {
    final reg = ProviderRegistry();
    await reg.load();
    expect(reg.isVerified('seed-penyedia-1'), isTrue);
    expect(reg.statusOf('seed-penyedia-2'), ProviderStatus.menungguReview);
    expect(reg.statusOf('belum-ada'), ProviderStatus.belumDiajukan);
  });

  test('pengajuan lengkap terverifikasi dan tersimpan lintas instans',
      () async {
    final reg = ProviderRegistry();
    await reg.load();
    final review = await reg.submit('demo-penyedia', _aplikasiValid());
    expect(review.status, ProviderStatus.terverifikasi);
    expect(reg.isVerified('demo-penyedia'), isTrue);

    final reg2 = ProviderRegistry();
    await reg2.load();
    expect(reg2.isVerified('demo-penyedia'), isTrue);
    expect(reg2.profileOf('demo-penyedia')!.namaToko, 'Warung Test');
  });

  test('pengajuan tanpa foto toko menunggu review (tidak lolos otomatis)',
      () async {
    final reg = ProviderRegistry();
    await reg.load();
    final review =
        await reg.submit('demo-penyedia', _aplikasiValid(foto: false));
    expect(review.status, ProviderStatus.menungguReview);
    expect(reg.isVerified('demo-penyedia'), isFalse);
    expect(review.catatan, isNotEmpty);
  });

  test('admin demo dapat menolak dan menyetujui', () async {
    final reg = ProviderRegistry();
    await reg.load();
    await reg.setStatus(
      'seed-penyedia-2',
      ProviderStatus.ditolak,
      catatan: const ['Alamat tidak ditemukan saat verifikasi lapangan.'],
    );
    expect(reg.statusOf('seed-penyedia-2'), ProviderStatus.ditolak);

    await reg.setStatus('seed-penyedia-2', ProviderStatus.terverifikasi);
    expect(reg.isVerified('seed-penyedia-2'), isTrue);
  });

  test('resetAll mengembalikan data contoh', () async {
    final reg = ProviderRegistry();
    await reg.load();
    await reg.submit('demo-penyedia', _aplikasiValid());
    await reg.resetAll();
    expect(reg.profileOf('demo-penyedia'), isNull);
    expect(reg.isVerified('seed-penyedia-1'), isTrue);
  });
}
