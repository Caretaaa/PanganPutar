import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/core/security_rules.dart';
import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/models/models.dart';
import 'package:panganputar_flutter/models/payment.dart';
import 'package:panganputar_flutter/screens/detail_screen.dart';
import 'package:panganputar_flutter/services/api_client.dart';
import 'package:panganputar_flutter/services/claim_ledger.dart';
import 'package:panganputar_flutter/services/demo_store.dart';
import 'package:panganputar_flutter/services/device_identity.dart';
import 'package:panganputar_flutter/services/midtrans.dart';
import 'package:panganputar_flutter/services/provider_registry.dart';
import 'package:panganputar_flutter/services/session.dart';
import 'package:panganputar_flutter/services/service_holder.dart';
import 'package:panganputar_flutter/services/supabase_auth_service.dart';
import 'package:panganputar_flutter/services/supabase_data_service.dart';
import 'package:panganputar_flutter/widgets/app_holders.dart';

// Tes integrasi fitur keamanan di layar detail:
// kuota perangkat, verifikasi toko, dan alur pembayaran Midtrans (simulasi
// offline karena backend tidak terjangkau di lingkungan tes).

class _Harness {
  final device = DeviceIdentity();
  final ledger = DailyClaimLedger();
  final providers = ProviderRegistry();

  // HTTP ditiru: tanpa jaringan sungguhan agar tes cepat & deterministik.
  final api = PanganPutarApi(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('tidak ada', 404)),
  );
  final payments = MidtransPaymentService(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('tidak ada', 500)),
  );

  final session = SessionState();
  final store = DemoStore();

  Future<void> siapkan() async {
    await initializeDateFormatting('id_ID', null);
    await device.load();
    await ledger.load(device.deviceId!);
    await providers.load();
    await session.signInDemo(role: 'penerima', name: 'Tester');
  }

  Widget bungkus(Widget child) => SessionHolder(
    session: session,
    child: DemoHolder(
      store: store,
      child: ServicesHolder(
        auth: SupabaseAuthService.instance,
        data: SupabaseDataService.instance,
        config: AppConfig.instance,
        session: session,
        device: device,
        ledger: ledger,
        providers: providers,
        payments: payments,
        child: MaterialApp(home: child),
      ),
    ),
  );
}

/// Siapkan harness di zona async nyata (panggilan plugin perangkat ditiru
/// gagal dan langsung jatuh ke UUID instalasi).
Future<void> _siapkan(WidgetTester tester, _Harness h) async {
  await tester.runAsync(h.siapkan);
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _Harness h,
  FoodListing item,
) async {
  // Layar uji tinggi supaya seluruh konten ListView terbangun (ListView malas
  // membangun anak di luar viewport).
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    h.bungkus(DetailScreen(api: h.api, listingId: item.id, fallback: item)),
  );
  await tester.pumpAndSettle();
}

ElevatedButton _tombolPesan(WidgetTester tester) {
  return tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('toko terverifikasi: lencana tampil dan tombol pesan aktif',
      (tester) async {
    final h = _Harness();
    await _siapkan(tester, h);
    final item = sampleListings()
        .firstWhere((e) => e.providerId == 'seed-penyedia-1');

    await _pumpDetail(tester, h, item);

    expect(find.text('Toko terverifikasi'), findsOneWidget);
    expect(_tombolPesan(tester).onPressed, isNotNull);
  });

  testWidgets('kuota perangkat habis: tombol pesan nonaktif dengan alasan',
      (tester) async {
    final h = _Harness();
    await _siapkan(tester, h);
    await h.ledger.record(4); // porsi harian habis
    final item = sampleListings()
        .firstWhere((e) => e.providerId == 'seed-penyedia-1');

    await _pumpDetail(tester, h, item);

    expect(
      find.textContaining('Sisa kuota harian perangkat tinggal 0 porsi'),
      findsOneWidget,
    );
    expect(_tombolPesan(tester).onPressed, isNull);
  });

  testWidgets('toko menunggu review: peringatan tampil (tidak memblokir)',
      (tester) async {
    final h = _Harness();
    await _siapkan(tester, h);
    final item = sampleListings()
        .firstWhere((e) => e.providerId == 'seed-penyedia-2');

    await _pumpDetail(tester, h, item);

    expect(
      find.textContaining('Verifikasi toko penyedia masih ditinjau admin'),
      findsOneWidget,
    );
    expect(_tombolPesan(tester).onPressed, isNotNull);
  });

  testWidgets('toko ditolak: pesanan diblokir', (tester) async {
    final h = _Harness();
    await _siapkan(tester, h);
    await h.providers.setStatus(
      'seed-penyedia-1',
      ProviderStatus.ditolak,
      catatan: const ['Alamat fiktif.'],
    );
    final item = sampleListings()
        .firstWhere((e) => e.providerId == 'seed-penyedia-1');

    await _pumpDetail(tester, h, item);

    expect(find.textContaining('ditolak verifikasinya'), findsOneWidget);
    expect(_tombolPesan(tester).onPressed, isNull);
  });

  testWidgets('pesan gratis: kuota perangkat tercatat dan pesanan dibuat',
      (tester) async {
    final h = _Harness();
    await _siapkan(tester, h);
    final item =
        sampleListings().firstWhere((e) => e.providerId == 'seed-penyedia-1' && e.isFree);

    await _pumpDetail(tester, h, item);
    final tombol = find.byType(ElevatedButton).first;
    await tester.ensureVisible(tombol);
    await tester.pumpAndSettle();
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Pesanan dibuat (gratis)'), findsOneWidget);
    expect(h.store.myOrders.length, 1);
    expect(h.ledger.porsiHariIni, 1);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('alur pembayaran berbayar: simulasi offline sampai lunas',
      (tester) async {
    final h = _Harness();
    await _siapkan(tester, h);
    final item = sampleListings()
        .firstWhere((e) => e.providerId == 'seed-penyedia-1' && !e.isFree);

    await _pumpDetail(tester, h, item);

    // Pesan → layar pembayaran (backend tidak terjangkau → sesi simulasi).
    final tombolPesan = find.byType(ElevatedButton).first;
    await tester.ensureVisible(tombolPesan);
    await tester.pumpAndSettle();
    await tester.tap(tombolPesan);
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan pesanan'), findsOneWidget);

    // Lanjut bayar → mode simulasi offline.
    final lanjut = find.byType(ElevatedButton).first;
    await tester.ensureVisible(lanjut);
    await tester.pumpAndSettle();
    await tester.tap(lanjut);
    await tester.pumpAndSettle();
    expect(find.textContaining('MODE SIMULASI'), findsOneWidget);

    // Simulasikan pembayaran berhasil (tombol bayar di kartu simulasi).
    final bayar = find.byType(ElevatedButton).first;
    await tester.ensureVisible(bayar);
    await tester.pumpAndSettle();
    await tester.tap(bayar);
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran lunas'), findsOneWidget);

    // Selesai → kembali ke detail, dialog pesanan dibayar.
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan dibayar'), findsOneWidget);

    final pesanan = h.store.myOrders.first;
    expect(pesanan.payment?.status, PaymentStatus.dibayar);
    expect(pesanan.payment?.simulasi, isTrue);
  });
}
