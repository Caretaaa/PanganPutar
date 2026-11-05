import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/core/pickup_rules.dart';
import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/screens/orders_screen.dart';
import 'package:panganputar_flutter/screens/pickup_ticket_screen.dart';
import 'package:panganputar_flutter/screens/provider_screen.dart';
import 'package:panganputar_flutter/screens/scan_screen.dart';
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

// Tes alur QR pengambilan di UI:
// - pembeli: Tampilkan QR, tiket tampil, pindai QR toko (stubbed manual)
// - penyedia: QR toko tampil, pindai tiket pembeli → pesanan selesai.

class _Harness {
  final device = DeviceIdentity();
  final ledger = DailyClaimLedger();
  final providers = ProviderRegistry();

  final payments = MidtransPaymentService(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('tidak ada', 500)),
  );

  final session = SessionState();
  final store = DemoStore();

  Future<void> siapkan({String role = 'penerima'}) async {
    await initializeDateFormatting('id_ID', null);
    await device.load();
    await ledger.load(device.deviceId!);
    await providers.load();
    await session.signInDemo(role: role, name: 'Tester');
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

Future<void> _siapkan(WidgetTester tester, _Harness h, {String? role}) async {
  await tester.runAsync(() => h.siapkan(role: role ?? 'penerima'));
}

/// Jalankan badan tes dengan platform desktop dipaksa, agar kamera tidak
/// dibangun (jalur kode manual yang diuji — setara emulator tanpa kamera).
/// Wajib try/finally: framework memeriksa variabel debug sebelum tearDown.
Future<void> _tanpaKamera(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('form verifikasi 320 px: penjelasan NIB tidak dipotong', (
    tester,
  ) async {
    final h = _Harness();
    await _siapkan(tester, h, role: 'penyedia');
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.bungkus(const ProviderHubScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajukan verifikasi toko'));
    await tester.pumpAndSettle();

    expect(
      find.text('13–20 digit. Konfirmasi demo, bukan pemeriksaan resmi.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pembeli: Tampilkan QR membuka tiket berisi QR + kode', (
    tester,
  ) async {
    final h = _Harness();
    await _siapkan(tester, h);
    h.store.placeOrder(sampleListings().firstWhere((e) => e.isFree), 1);
    final order = h.store.myOrders.first;

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      h.bungkus(
        OrdersScreen(
          isProduction: false,
          data: SupabaseDataService.instance,
          session: h.session,
          auth: SupabaseAuthService.instance,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tampilkan QR'), findsOneWidget);
    await tester.tap(find.text('Tampilkan QR'));
    await tester.pumpAndSettle();

    expect(find.text('Tiket pengambilan'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(order.pickupCode), findsOneWidget);
    // Pesanan masih menunggu konfirmasi: tiket jujur melarang datang dulu.
    expect(find.textContaining('Simpan kode ini'), findsOneWidget);
    expect(find.textContaining('Tunjukkan QR ini ke penyedia'), findsNothing);
    expect(
      find.textContaining('tidak berarti pesanan sudah lunas'),
      findsOneWidget,
    );
    expect(find.text('Cocokkan QR toko'), findsOneWidget);

    h.store.setOrderStatus(order.id, 'dikonfirmasi');
    await tester.pumpAndSettle();
    expect(find.textContaining('Tunjukkan QR ini ke penyedia'), findsOneWidget);
  });

  testWidgets('pembeli: kedatangan terverifikasi tampil setelah pindai toko', (
    tester,
  ) async {
    final h = _Harness();
    await _siapkan(tester, h);
    h.store.placeOrder(sampleListings().first, 1);
    final order = h.store.myOrders.first;
    h.store.markArrivalVerified(order.id);

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.bungkus(PickupTicketScreen(order: order)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('QR toko cocok dengan pesananmu'),
      findsOneWidget,
    );
    expect(find.textContaining('bukan bukti posisi fisik'), findsOneWidget);
    expect(find.text('Toko sesuai pesanan'), findsOneWidget);
  });

  testWidgets('pembeli: pindai QR toko yang benar mencatat kedatangan', (
    tester,
  ) async {
    await _tanpaKamera(() async {
      final h = _Harness();
      await _siapkan(tester, h);
      final item = sampleListings().firstWhere(
        (e) => e.providerId == 'seed-penyedia-1',
      );
      h.store.placeOrder(item, 1);
      final order = h.store.myOrders.first;

      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(h.bungkus(PickupTicketScreen(order: order)));
      await tester.pumpAndSettle();

      final tombol = find.text('Pindai QR toko');
      await tester.ensureVisible(tombol);
      await tester.pumpAndSettle();
      await tester.tap(tombol);
      await tester.pumpAndSettle();

      expect(find.text('Pindai QR toko'), findsWidgets);
      final qrToko = const StoreQr(
        providerId: 'seed-penyedia-1',
        namaToko: 'Warung Bu Sari (contoh)',
      ).encode();
      await tester.enterText(find.byType(TextField), qrToko);
      await tester.tap(find.text('Proses kode'));
      await tester.pumpAndSettle();

      expect(find.text('QR toko cocok'), findsOneWidget);
      expect(order.arrivalVerifiedAt, isNotNull);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('pembeli: QR toko lain ditolak dengan alasan', (tester) async {
    await _tanpaKamera(() async {
      final h = _Harness();
      await _siapkan(tester, h);
      final item = sampleListings().firstWhere(
        (e) => e.providerId == 'seed-penyedia-1',
      );
      h.store.placeOrder(item, 1);
      final order = h.store.myOrders.first;

      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(h.bungkus(PickupTicketScreen(order: order)));
      await tester.pumpAndSettle();

      final tombol = find.text('Pindai QR toko');
      await tester.ensureVisible(tombol);
      await tester.pumpAndSettle();
      await tester.tap(tombol);
      await tester.pumpAndSettle();

      final qrSalah = const StoreQr(
        providerId: 'seed-penyedia-2',
        namaToko: 'Kebun Lembang (contoh)',
      ).encode();
      await tester.enterText(find.byType(TextField), qrSalah);
      await tester.tap(find.text('Proses kode'));
      await tester.pumpAndSettle();

      expect(find.text('QR tidak cocok'), findsOneWidget);
      expect(find.textContaining('bukan toko pesananmu'), findsOneWidget);
      expect(order.arrivalVerifiedAt, isNull);
    });
  });

  testWidgets('penyedia: QR toko tampil + pindai tiket pembeli menuntaskan '
      'pesanan', (tester) async {
    await _tanpaKamera(() async {
      final h = _Harness();
      await _siapkan(tester, h, role: 'penyedia');
      h.store.placeOrder(sampleListings().firstWhere((e) => e.isFree), 1);
      final order = h.store.myOrders.first;
      h.store.setOrderStatus(order.id, 'dikonfirmasi');

      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        h.bungkus(const Scaffold(body: ProviderScreen())),
      );
      await tester.pumpAndSettle();

      // Kartu QR toko tampil dengan QR siap pajang.
      expect(find.text('QR toko'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);

      // Pemilik toko memindai tiket pembeli (via kode manual di tes).
      final tombol = find.text('Pindai QR pembeli');
      await tester.ensureVisible(tombol);
      await tester.pumpAndSettle();
      await tester.tap(tombol);
      await tester.pumpAndSettle();

      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: order.listing.providerId,
      );
      await tester.enterText(find.byType(TextField), tiket.encode());
      await tester.tap(find.text('Proses kode'));
      await tester.pumpAndSettle();

      expect(find.text('Pengambilan terverifikasi'), findsOneWidget);
      expect(find.textContaining('Mode demo'), findsOneWidget);
      expect(order.status, 'selesai');
      expect(order.pickupVerified, isTrue);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Daftar pesanan menyegarkan status terverifikasi.
      expect(find.textContaining('terverifikasi QR'), findsWidgets);
    });
  });

  testWidgets('penyedia: tiket tidak valid ditolak tanpa mengubah pesanan', (
    tester,
  ) async {
    await _tanpaKamera(() async {
      final h = _Harness();
      await _siapkan(tester, h, role: 'penyedia');
      h.store.placeOrder(sampleListings().first, 1);
      final order = h.store.myOrders.first;
      h.store.setOrderStatus(order.id, 'dikonfirmasi');

      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        h.bungkus(const Scaffold(body: ProviderScreen())),
      );
      await tester.pumpAndSettle();

      final tombol = find.text('Pindai QR pembeli');
      await tester.ensureVisible(tombol);
      await tester.pumpAndSettle();
      await tester.tap(tombol);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'url-palsu-atau-qr-asing');
      await tester.tap(find.text('Proses kode'));
      await tester.pumpAndSettle();

      expect(find.text('QR tidak bisa diproses'), findsOneWidget);
      expect(order.status, 'dikonfirmasi');
      expect(order.pickupVerified, isFalse);
    });
  });

  testWidgets('layar pindai: input manual mengembalikan nilai', (tester) async {
    String? hasil;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                hasil = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(
                      judul: 'Uji',
                      petunjuk: 'Uji manual.',
                      gunakanKamera: false,
                    ),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kamera tidak dipakai'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  kode-uji-123  ');
    await tester.tap(find.text('Proses kode'));
    await tester.pumpAndSettle();

    expect(hasil, 'kode-uji-123');
  });
}
