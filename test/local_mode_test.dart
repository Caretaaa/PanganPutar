import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/models/payment.dart';
import 'package:panganputar_flutter/screens/login_screen.dart';
import 'package:panganputar_flutter/services/demo_store.dart';
import 'package:panganputar_flutter/services/session.dart';
import 'package:panganputar_flutter/widgets/app_holders.dart';

/// Mode sementara: login lokal tanpa database, riwayat pesanan di perangkat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('riwayat pesanan demo bertahan setelah dibuat ulang dari perangkat', () async {
    SharedPreferences.setMockInitialValues({});

    final pertama = DemoStore();
    await pertama.load();
    final listing = sampleListings().first;

    final kode = pertama.placeOrder(listing, 2);
    pertama.setOrderStatus(pertama.myOrders.first.id, 'siap_diambil');
    pertama.markPayment(pertama.myOrders.first.id, const PaymentRecord(
      orderId: 'demo-1',
      grossAmount: 20000,
      status: PaymentStatus.menunggu,
      metode: 'qris',
      simulasi: true,
    ));
    pertama.markPickedUp(pertama.myOrders.first.id);

    // Instance baru = aplikasi dibuka ulang; kondisi disimpan di prefs sama.
    final kedua = DemoStore();
    await kedua.load();

    expect(kedua.myOrders.length, 1);
    final o = kedua.myOrders.first;
    expect(o.pickupCode, kode);
    expect(o.status, 'selesai');
    expect(o.pickupVerified, isTrue);
    expect(o.pickedUpAt, isNotNull);
    expect(o.listing.title, listing.title);
    expect(o.listing.imageAsset, listing.imageAsset);
    expect(o.payment?.simulasi, isTrue);
    // Pembayaran belum diselesaikan: status tetap menunggu walau selesai diambil.
    expect(o.payment?.status, PaymentStatus.menunggu);
    expect(o.paymentStatus, PaymentStatus.menunggu);
  });

  test('pesanan kedua tidak menabrak id/kode setelah muat ulang', () async {
    SharedPreferences.setMockInitialValues({});

    final pertama = DemoStore();
    await pertama.load();
    final listing = sampleListings().first;
    final kode1 = pertama.placeOrder(listing, 1);
    final kode2 = pertama.placeOrder(listing, 1);
    expect(kode1, isNot(kode2));
    expect(pertama.myOrders.length, 2);

    final kedua = DemoStore();
    await kedua.load();
    final kode3 = kedua.placeOrder(listing, 1);
    expect(kode3, isNot(kode1));
    expect(kode3, isNot(kode2));
    expect(kedua.myOrders.length, 3);
    // Terbaru dulu.
    expect(kedua.myOrders.first.pickupCode, kode3);
  });

  testWidgets('login lokal: nama + peran tersimpan di sesi, tanpa database', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionState();
    await session.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SessionHolder(
          session: session,
          child: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Masuk ke PanganPutar'), findsOneWidget);
    // Jujur: tanpa kata sandi/email/OTP; tidak ada tombol metode Supabase.
    expect(find.text('Masuk dengan Google'), findsNothing);
    expect(find.text('Kirim kode SMS'), findsNothing);
    expect(find.text('Kata sandi'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Sari Rahayu');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isTrue);
    expect(session.displayName, 'Sari Rahayu');
    expect(session.role, 'penerima');
    expect(find.text('Sudah masuk'), findsOneWidget);
  });
}
