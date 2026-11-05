import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/models/models.dart';
import 'package:panganputar_flutter/services/api_client.dart';
import 'package:panganputar_flutter/widgets/listing_tile.dart';
import 'package:panganputar_flutter/widgets/demo_banner.dart';

// Tahap 2 redesign: kartu listing (ListingTile) + banner demo tipis.
// Fokus: kartu punya nama toko, countdown, sisa/hampir habis, harga dicoret,
// badge GRATIS beda visual, tombol Pesan + ikon simpan, placeholder halus
// TANPA kata "ilustrasi".

FoodListing contoh({String id = 'uji-1'}) => FoodListing(
      id: id,
      providerId: 'seed-penyedia-1',
      title: 'Nasi kotak uji',
      category: 'nasi',
      quantityTotal: 10,
      quantityAvailable: 12,
      unit: 'porsi',
      priceRupiah: 5000,
      originalPriceRupiah: 18000,
      isFree: false,
      city: 'Bandung',
      district: 'Coblong',
      pickupAddress: 'Jl. Contoh',
      pickupStart: DateTime.now().add(const Duration(hours: 1)),
      pickupEnd: DateTime.now().add(const Duration(hours: 4)),
      status: 'tersedia',
    );

FoodListing contohGratis() => FoodListing(
      id: 'uji-gratis',
      providerId: 'seed-penyedia-1',
      title: 'Roti sisa gratis',
      category: 'roti',
      quantityTotal: 5,
      quantityAvailable: 2,
      unit: 'pcs',
      priceRupiah: 0,
      isFree: true,
      city: 'Bandung',
      district: 'Dago',
      pickupAddress: 'Jl. Contoh',
      pickupStart: DateTime.now(),
      pickupEnd: DateTime.now().add(const Duration(hours: 2)),
      status: 'tersedia',
    );

Widget bungkus(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('kartu berbayar: harga pine + harga normal dicoret + countdown',
      (tester) async {
    await tester.pumpWidget(bungkus(
      ListingTile(
        item: contoh(),
        storeName: 'Warung Bu Sari (contoh)',
        distanceKm: 1.24,
      ),
    ));
    await tester.pumpAndSettle();

    // Nama toko tampil (digabung dengan jarak dalam satu Text widget).
    expect(find.textContaining('Warung Bu Sari'), findsOneWidget);
    // Harga sekarang pine; jangan tampil "Gratis" untuk berbayar.
    expect(find.text('GRATIS'), findsNothing);
    // Harga awal (dicoret) memuat ribuan 18.000 — sumber format id_ID.
    expect(find.textContaining('18.000'), findsOneWidget);
    // Jarak digabung dalam Text yang sama dengan nama toko.
    expect(find.textContaining('±1,2 km'), findsOneWidget);
  });

  testWidgets('kartu gratis: badge GRATIS berbeda visual, tanda hampir habis',
      (tester) async {
    await tester.pumpWidget(bungkus(ListingTile(
      item: contohGratis(),
      storeName: 'Warung Bu Sari (contoh)',
      verified: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('GRATIS'), findsOneWidget);
    expect(find.textContaining('Hampir habis'), findsOneWidget);
    // Tanpa foto: placeholder halus TANPA kata "ilustrasi".
    expect(find.textContaining('ilustra'), findsNothing);
  });

  testWidgets('kartu: tombol Pesan + ikon simpan berfungsi (toggles)',
      (tester) async {
    var tekPesan = 0;
    var tekSimpan = 0;
    var saved = false;

    await tester.pumpWidget(
      StatefulBuilder(builder: (context, setState) {
        return bungkus(ListingTile(
          item: contoh(),
          isSaved: saved,
          onPesan: () => tekPesan++,
          onToggleSave: () => setState(() {
            tekSimpan++;
            saved = !saved;
          }),
        ));
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pesan'));
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();
    expect(tekPesan, 1, reason: 'tombol Pesan harus memanggil aksi detail');
    expect(tekSimpan, 1);
    expect(find.byIcon(Icons.bookmark), findsOneWidget); // ikon berubah

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget); // balik
  });

  testWidgets('banner demo: muncul, bisa ditutup, dan tidak kembali', (
    tester,
  ) async {
    await tester.pumpWidget(bungkus(const DemoBanner(active: true)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mode demo'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode demo'), findsNothing);

    // Banner dipasang ulang di build berikutan (persist tutup).
    final bannerLagi = DemoBanner(active: true);
    await tester.pumpWidget(bungkus(bannerLagi));
    await tester.pumpAndSettle();
    // Masih tersembunyi karena tutup tersimpan di perangkat.
    expect(find.textContaining('Mode demo'), findsNothing);

    // Produksi: selalu tak tampil.
    await tester.pumpWidget(bungkus(const DemoBanner(active: false)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode demo'), findsNothing);
  });

  test('data contoh: memenuhi ruang filter tahap 2', () {
    final data = sampleListings();
    expect(data.length >= 6, isTrue, reason: 'perlu variasi filter');
    expect(data.any((l) => l.isFree), isTrue);
    expect(data.any((l) => !l.isFree), isTrue);
    expect(data.any((l) => l.originalPriceRupiah != null), isTrue,
        reason: 'ada contoh harga dicoret');
    expect(data.any((l) => l.quantityAvailable <= 2), isTrue,
        reason: 'ada contoh hampir habis');
    expect(data.any((l) => l.pickupEnd.isBefore(
          DateTime.now().add(const Duration(hours: 3)),
        )), isTrue, reason: 'ada contoh segera berakhir utk countdown');
    // Geo contoh lengkap untuk filter terdekat.
    for (final l in data) {
      expect(sampleGeo[l.id]?.lat, isNotNull, reason: '${l.id} butuh koordinat');
    }
  });

  test('api offline tetap memakai data contoh (harness berfungsi)', () async {
    final api = PanganPutarApi(
      base: 'http://uji.local',
      client: MockClient((_) async => http.Response('tidak ada', 404)),
    );
    final hasil = await api.fetchListings();
    expect(hasil.length, equals(sampleListings().length));
  });
}
