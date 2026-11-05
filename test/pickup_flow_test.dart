import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/core/pickup_rules.dart';
import 'package:panganputar_flutter/models/models.dart';
import 'package:panganputar_flutter/models/payment.dart';
import 'package:panganputar_flutter/services/demo_store.dart';
import 'package:panganputar_flutter/services/pickup_service.dart';

// Alur lengkap dua arah: penyedia memindai tiket pembeli → pesanan selesai
// & terverifikasi; pembeli memindai QR toko → kedatangan tercatat.

FoodListing _listing(
  String providerId, {
  int harga = 0,
  DateTime? pickupEnd,
  String id = 'L-1',
}) {
  final now = DateTime.now();
  return FoodListing(
    id: id,
    providerId: providerId,
    title: 'Nasi sisa layak',
    category: 'nasi',
    description: null,
    quantityTotal: 10,
    quantityAvailable: 10,
    unit: 'porsi',
    priceRupiah: harga,
    isFree: harga <= 0,
    city: 'Bandung',
    district: '',
    pickupAddress: 'Jl. Contoh No. 1',
    pickupNote: null,
    pickupStart: now.subtract(const Duration(hours: 1)),
    pickupEnd: pickupEnd ?? now.add(const Duration(hours: 3)),
    storageNote: 'Suhu ruang maksimal 4 jam.',
    allergenInfo: null,
    status: 'tersedia',
  );
}

void main() {
  late DemoStore store;
  late PickupService service;

  setUp(() {
    store = DemoStore();
    service = PickupService(store);
  });

  group('penyedia memindai tiket pembeli', () {
    test('alur penuh: pesan → konfirmasi → pindai → selesai & terverifikasi',
        () {
      store.placeOrder(_listing('toko-a'), 2);
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'dikonfirmasi');

      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'toko-a',
      );
      final hasil = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-a',
      );

      expect(hasil.sukses, isTrue);
      expect(hasil.pesan, contains(order.pickupCode));
      expect(order.status, 'selesai');
      expect(order.pickupVerified, isTrue);
      expect(order.pickedUpAt, isNotNull);
    });

    test('QR dobel: pemindaian kedua ditolak', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'dikonfirmasi');
      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'toko-a',
      );

      expect(
        service
            .prosesScanTiketPembeli(
              raw: tiket.encode(),
              scannerProviderId: 'toko-a',
            )
            .sukses,
        isTrue,
      );
      final kedua = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-a',
      );
      expect(kedua.sukses, isFalse);
      expect(kedua.pesan, contains('sudah diambil'));
    });

    test('toko lain tidak berhak memindai (tanpa mode demo)', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'dikonfirmasi');
      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'toko-a',
      );

      final hasil = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-jahat',
      );
      expect(hasil.sukses, isFalse);
      expect(hasil.pesan, contains('toko lain'));
      expect(order.status, 'dikonfirmasi'); // tidak berubah
    });

    test('mode demo: satu perangkat memproses atas nama toko pemilik tiket',
        () {
      store.placeOrder(_listing('seed-penyedia-1'), 1);
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'dikonfirmasi');
      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'seed-penyedia-1',
      );

      final hasil = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'demo-penyedia',
        operatorDemo: true,
      );
      expect(hasil.sukses, isTrue);
      expect(hasil.peringatan, contains('Mode demo'));
      expect(order.status, 'selesai');
    });

    test('barcode berisi kode pengambilan telanjang tetap diproses', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'dikonfirmasi');

      final hasil = service.prosesScanTiketPembeli(
        raw: order.pickupCode,
        scannerProviderId: 'toko-a',
      );
      expect(hasil.sukses, isTrue);
      expect(hasil.peringatan, contains('tanpa QR'));
    });

    test('teks asing ditolak dengan pesan jelas', () {
      final hasil = service.prosesScanTiketPembeli(
        raw: 'meja-4-menu-spesial',
        scannerProviderId: 'toko-a',
      );
      expect(hasil.sukses, isFalse);
      expect(hasil.pesan, contains('Bukan QR tiket'));
    });

    test('pesanan berbayar: belum lunas diblokir, setelah lunas lolos', () {
      store.placeOrder(_listing('toko-a', harga: 15000), 1);
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'dikonfirmasi');
      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'toko-a',
      );

      final belum = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-a',
      );
      expect(belum.sukses, isFalse);
      expect(belum.pesan, contains('belum lunas'));

      store.markPayment(
        order.id,
        PaymentRecord(
          orderId: order.id,
          grossAmount: order.total,
          status: PaymentStatus.dibayar,
          dibayarPada: DateTime.now(),
        ),
      );
      final lunas = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-a',
      );
      expect(lunas.sukses, isTrue);
    });

    test('pesanan dibatalkan tidak bisa diserahkan', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      store.cancelOrder(order.id);
      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'toko-a',
      );

      final hasil = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-a',
      );
      expect(hasil.sukses, isFalse);
      expect(hasil.pesan, contains('dibatalkan'));
    });

    test('jendela ambil lewat: tetap diproses dengan peringatan', () {
      store.placeOrder(
        _listing(
          'toko-a',
          pickupEnd: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        1,
      );
      final order = store.myOrders.first;
      store.setOrderStatus(order.id, 'siap_diambil');
      final tiket = PickupTicket(
        orderId: order.id,
        kode: order.pickupCode,
        providerId: 'toko-a',
      );

      final hasil = service.prosesScanTiketPembeli(
        raw: tiket.encode(),
        scannerProviderId: 'toko-a',
      );
      expect(hasil.sukses, isTrue);
      expect(hasil.peringatan, contains('berakhir'));
    });
  });

  group('pembeli memindai QR toko', () {
    test('toko benar: kedatangan tercatat', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      final qr = const StoreQr(
        providerId: 'toko-a',
        namaToko: 'Warung Bu Sari',
      ).encode();

      final hasil = service.prosesScanQrToko(
        raw: qr,
        order: order,
        tokoTerverifikasi: true,
      );
      expect(hasil.sukses, isTrue);
      expect(order.arrivalVerifiedAt, isNotNull);
    });

    test('toko berbeda: ditolak, lokasi tidak tercatat', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      final qr = const StoreQr(
        providerId: 'toko-b',
        namaToko: 'Kebun Lain',
      ).encode();

      final hasil = service.prosesScanQrToko(
        raw: qr,
        order: order,
        tokoTerverifikasi: true,
      );
      expect(hasil.sukses, isFalse);
      expect(hasil.pesan, contains('bukan toko pesananmu'));
      expect(order.arrivalVerifiedAt, isNull);
    });

    test('toko belum terverifikasi: lolos dengan peringatan', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;
      final qr = const StoreQr(
        providerId: 'toko-a',
        namaToko: 'Warung Baru',
      ).encode();

      final hasil = service.prosesScanQrToko(
        raw: qr,
        order: order,
        tokoTerverifikasi: false,
      );
      expect(hasil.sukses, isTrue);
      expect(hasil.peringatan, contains('ditinjau'));
    });

    test('QR asing / pesanan selesai ditolak', () {
      store.placeOrder(_listing('toko-a'), 1);
      final order = store.myOrders.first;

      expect(
        service
            .prosesScanQrToko(
              raw: 'https://bukan-panganputar.id',
              order: order,
              tokoTerverifikasi: true,
            )
            .sukses,
        isFalse,
      );

      store.markPickedUp(order.id);
      final qr = const StoreQr(
        providerId: 'toko-a',
        namaToko: 'Warung',
      ).encode();
      final hasil = service.prosesScanQrToko(
        raw: qr,
        order: order,
        tokoTerverifikasi: true,
      );
      expect(hasil.sukses, isFalse);
      expect(hasil.pesan, contains('sudah selesai'));
    });
  });
}
