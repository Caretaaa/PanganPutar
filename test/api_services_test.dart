import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panganputar_flutter/models/payment.dart';
import 'package:panganputar_flutter/services/api_client.dart';
import 'package:panganputar_flutter/services/midtrans.dart';

const _listing = <String, Object?>{
  'id': 'server-food',
  'providerId': 'server-shop',
  'title': 'Nasi sayur',
  'image_url': 'https://example.com/nasi.jpg',
  'category': 'nasi',
  'quantityAvailable': 3,
  'quantityTotal': 3,
  'priceRupiah': 5000,
  'isFree': false,
  'city': 'Bandung',
  'pickupStart': '2026-10-19T10:00:00Z',
  'pickupEnd': '2026-10-19T14:00:00Z',
};

void main() {
  test('katalog mengirim filter dan membaca penawaran backend', () async {
    final api = PanganPutarApi(
      base: 'https://uji.local/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/listings');
        expect(request.url.queryParameters, {
          'limit': '48',
          'q': 'nasi',
          'kategori': 'nasi',
          'kota': 'Bandung',
          'gratisSaja': '1',
        });
        return http.Response(
          jsonEncode({
            'data': [_listing],
          }),
          200,
        );
      }),
    );
    final items = await api.fetchListings(
      const ListingFilter(
        q: ' nasi ',
        kategori: 'nasi',
        kota: ' Bandung ',
        gratisSaja: true,
      ),
    );
    expect(items.single.id, 'server-food');
    expect(items.single.imageUrl, 'https://example.com/nasi.jpg');
    expect(items.single.effectivePrice, 5000);
  });

  test(
    'katalog rusak menggunakan contoh dan tetap menerapkan filter',
    () async {
      final api = PanganPutarApi(
        client: MockClient((_) async => http.Response('bukan JSON', 200)),
      );
      final items = await api.fetchListings(
        const ListingFilter(gratisSaja: true),
      );
      expect(items, isNotEmpty);
      expect(items.every((item) => item.effectivePrice == 0), isTrue);
      expect(
        await api.fetchListings(
          const ListingFilter(q: 'tidak-ada-makanan-ini'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'katalog backend kosong tetap kosong, tidak menyamar sebagai data contoh',
    () async {
      final api = PanganPutarApi(
        client: MockClient((_) async => http.Response('{"data":[]}', 200)),
      );
      expect(await api.fetchListings(), isEmpty);
    },
  );

  test(
    'detail membaca JSON bertipe dan ID tak dikenal menghasilkan null',
    () async {
      final api = PanganPutarApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/server-food')) {
            return http.Response(jsonEncode({'data': _listing}), 200);
          }
          return http.Response('{}', 404);
        }),
      );
      expect((await api.fetchDetail('server-food'))?.title, 'Nasi sayur');
      expect(await api.fetchDetail('missing-id'), isNull);
    },
  );

  test(
    'dampak membaca angka backend dan tidak mengarang data saat gagal',
    () async {
      final api = PanganPutarApi(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': {
                'porsiTersalurkan': 10,
                'pesananSelesai': 4,
                'penyediaAktif': 2,
                'estimasiKg': 4,
                'estimasiCo2eKg': 10,
              },
            }),
            200,
          );
        }),
      );
      expect((await api.fetchImpact())?.porsiTersalurkan, 10);
      final offline = PanganPutarApi(
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      expect(await offline.fetchImpact(), isNull);
    },
  );

  test(
    'Snap mengirim identitas perangkat dan memisahkan sesi backend',
    () async {
      final service = MidtransPaymentService(
        base: 'https://uji.local',
        client: MockClient((request) async {
          expect(request.url.path, '/api/payments/midtrans/snap');
          expect(request.headers['apikey'], 'public-test-key');
          expect(request.headers['authorization'], 'Bearer user-jwt');
          expect(request.headers['X-Device-Id'], 'installation-id');
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['grossAmount'], 10000);
          expect(body['deviceId'], 'installation-id');
          return http.Response(
            jsonEncode({
              'data': {
                'token': 'backend-token',
                'redirect_url': 'https://app.sandbox.midtrans.com/snap/test',
              },
            }),
            200,
          );
        }),
        apiKey: 'public-test-key',
        authToken: () => 'user-jwt',
      );
      final snap = await service.createSnap(
        orderId: 'order-1',
        grossAmount: 10000,
        deviceId: 'installation-id',
        items: const [
          PaymentItem(id: 'food', nama: 'Nasi', harga: 5000, jumlah: 2),
        ],
      );
      expect(snap.simulasi, isFalse);
      expect(snap.token, 'backend-token');
    },
  );

  test(
    'respons Snap tidak lengkap menjadi simulasi tanpa transaksi nyata',
    () async {
      final service = MidtransPaymentService(
        client: MockClient((_) async => http.Response('{"data":{}}', 200)),
      );
      final snap = await service.createSnap(
        orderId: 'order-demo',
        grossAmount: 5000,
        items: const [],
      );
      expect(snap.simulasi, isTrue);
      expect(snap.redirectUrl, startsWith('demo://'));
      expect(snap.token, startsWith('SIMULASI-'));
    },
  );

  test(
    'status pembayaran backend mempertahankan nominal dan referensi',
    () async {
      final service = MidtransPaymentService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'transactionStatus': 'settlement',
                'grossAmount': 10000,
                'paymentType': 'qris',
                'transactionId': 'ref-backend',
                'paidAt': '2026-10-19T10:00:00Z',
              },
            }),
            200,
          ),
        ),
      );
      final payment = await service.checkStatus('order-1', grossAmount: 5000);
      expect(payment?.status, PaymentStatus.dibayar);
      expect(payment?.grossAmount, 10000);
      expect(payment?.metode, 'qris');
      expect(payment?.transaksiId, 'ref-backend');
      expect(payment?.simulasi, isFalse);
    },
  );
}
