import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_data.dart';
import '../models/models.dart';
import '../models/payment.dart';
import 'contracts.dart';
import 'firebase_settings.dart';
import 'pickup_token_vault.dart';

/// Firestore + Cloud Functions implementation of the production data path.
///
/// Trust boundaries:
/// - Orders are created only by the `createOrder` callable (stock + weekly
///   face quota transaction).
/// - Payment state is written only by the Midtrans webhook.
/// - Pickup completion is written only by the `claimPickup` callable.
/// - Direct client writes are limited by `firestore.rules`.
class FirebaseDataService implements PanganDataService {
  FirebaseDataService._();
  static final instance = FirebaseDataService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(
        region: FirebaseBootstrap.settings.functionsRegion,
      );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ==================== LISTINGS ====================

  @override
  Future<List<FoodListing>> fetchListings({
    String query = '',
    String kategori = '',
    String kota = '',
    bool gratisSaja = false,
    int limit = 48,
  }) async {
    try {
      final snap = await _db
          .collection('food_listings')
          .where('status', isEqualTo: 'tersedia')
          .where('pickup_end', isGreaterThan: Timestamp.now())
          .orderBy('pickup_end')
          .limit(limit * 2)
          .get()
          .timeout(const Duration(seconds: 12));

      final now = DateTime.now();
      final rows = <FoodListing>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (((data['quantity_available'] as num?)?.toInt() ?? 0) <= 0) continue;
        if (data['store_verified'] == false) continue;
        final end = _date(data['pickup_end']);
        if (end == null || !end.isAfter(now)) continue;

        final item = _listingFromDoc(doc.id, data);
        if (query.trim().isNotEmpty &&
            !item.title.toLowerCase().contains(query.trim().toLowerCase())) {
          continue;
        }
        if (kategori.isNotEmpty && item.category != kategori) continue;
        if (kota.trim().isNotEmpty &&
            !item.city.toLowerCase().contains(kota.trim().toLowerCase())) {
          continue;
        }
        if (gratisSaja && !item.isFree) continue;
        rows.add(item);
      }
      rows.sort((a, b) => a.pickupEnd.compareTo(b.pickupEnd));
      if (rows.length > limit) return rows.sublist(0, limit);
      return rows;
    } catch (error) {
      throw _dataError(error, 'Katalog belum dapat dimuat.');
    }
  }

  @override
  Future<FoodListing?> fetchDetail(String id) async {
    try {
      final doc = await _db
          .collection('food_listings')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) return null;
      return _listingFromDoc(doc.id, doc.data() ?? const {});
    } catch (error) {
      throw _dataError(error, 'Detail penawaran belum dapat dimuat.');
    }
  }

  FoodListing _listingFromDoc(String id, Map<String, dynamic> row) {
    final price = (row['price_rupiah'] as num?)?.toInt() ?? 0;
    final start = _date(row['pickup_start']) ?? DateTime.now();
    final end = _date(row['pickup_end']) ?? DateTime.now();
    final imageUrl =
        (row['image_url'] as String?) ?? (row['image_path'] as String?);
    return FoodListing(
      id: id,
      providerId: (row['store_id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      category: (row['category'] as String?) ?? 'lainnya',
      description: row['description'] as String?,
      imageUrl: imageUrl,
      quantityTotal: (row['quantity_total'] as num?)?.toInt() ?? 0,
      quantityAvailable: (row['quantity_available'] as num?)?.toInt() ?? 0,
      unit: (row['unit'] as String?) ?? 'porsi',
      priceRupiah: price,
      originalPriceRupiah: (row['original_price_rupiah'] as num?)?.toInt(),
      isFree: price == 0,
      city: (row['store_city'] as String?) ?? '',
      district: (row['store_district'] as String?) ?? '',
      pickupAddress: (row['store_address'] as String?) ?? '',
      pickupNote: row['pickup_note'] as String?,
      pickupStart: start,
      pickupEnd: end,
      storageNote: row['storage_note'] as String?,
      allergenInfo: row['allergen_info'] as String?,
      status: (row['status'] as String?) ?? 'draft',
    );
  }

  @override
  Future<List<FoodListing>> fetchMyListings() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _db
          .collection('food_listings')
          .where('owner_id', isEqualTo: uid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      return [for (final doc in snap.docs) _listingFromDoc(doc.id, doc.data())];
    } catch (error) {
      throw _dataError(error, 'Penawaran Anda belum dapat dimuat.');
    }
  }

  @override
  Future<FoodListing> createListing(FoodListing listing) async {
    final uid = _uid;
    if (uid == null) throw const DataActionException('Belum masuk.');
    try {
      final storeSnap = await _db
          .collection('stores')
          .where('owner_id', isEqualTo: uid)
          .limit(1)
          .get();
      if (storeSnap.docs.isEmpty) {
        throw const DataActionException(
          'Anda belum memiliki toko. Ajukan verifikasi toko dulu.',
        );
      }
      final store = storeSnap.docs.first;
      final storeData = store.data();
      if (storeData['verification_status'] != 'terverifikasi') {
        throw const DataActionException(
          'Toko belum terverifikasi. Terbitkan penawaran setelah disetujui.',
        );
      }
      final ref = _db.collection('food_listings').doc();
      final data = <String, dynamic>{
        'store_id': store.id,
        'owner_id': uid,
        'store_name': storeData['name'],
        'store_city': storeData['city'],
        'store_address': storeData['address'],
        'store_verified': true,
        'title': listing.title,
        'category': listing.category,
        'description': listing.description,
        'image_url': listing.imageUrl,
        'quantity_total': listing.quantityTotal,
        'quantity_available': listing.quantityAvailable,
        'unit': listing.unit,
        'price_rupiah': listing.priceRupiah,
        'original_price_rupiah': listing.originalPriceRupiah,
        'pickup_start': Timestamp.fromDate(listing.pickupStart),
        'pickup_end': Timestamp.fromDate(listing.pickupEnd),
        'storage_note': listing.storageNote,
        'allergen_info': listing.allergenInfo,
        'status': 'tersedia',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      await ref.set(data);
      return _listingFromDoc(ref.id, {
        ...data,
        'pickup_start': listing.pickupStart,
        'pickup_end': listing.pickupEnd,
        'created_at': DateTime.now(),
      });
    } catch (error) {
      throw _dataError(error, 'Penawaran belum dapat diterbitkan.');
    }
  }

  @override
  Future<void> updateListing(FoodListing listing) async {
    final uid = _uid;
    if (uid == null) throw const DataActionException('Belum masuk.');
    try {
      await _db.collection('food_listings').doc(listing.id).update({
        'title': listing.title,
        'category': listing.category,
        'description': listing.description,
        'image_url': listing.imageUrl,
        'quantity_available': listing.quantityAvailable,
        'unit': listing.unit,
        'price_rupiah': listing.priceRupiah,
        'original_price_rupiah': listing.originalPriceRupiah,
        'pickup_start': Timestamp.fromDate(listing.pickupStart),
        'pickup_end': Timestamp.fromDate(listing.pickupEnd),
        'storage_note': listing.storageNote,
        'allergen_info': listing.allergenInfo,
        'status': listing.status,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw _dataError(error, 'Penawaran belum dapat diperbarui.');
    }
  }

  @override
  Future<void> deleteListing(String id) async {
    try {
      await _db.collection('food_listings').doc(id).delete();
    } catch (error) {
      throw _dataError(error, 'Penawaran belum dapat dihapus.');
    }
  }

  // ==================== ORDERS ====================

  @override
  Future<OrderResult> createOrder({
    required String listingId,
    required int quantity,
    String? faceToken,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const OrderResult(success: false, message: 'Belum masuk.');
    }
    if (quantity < 1 || quantity > 4) {
      return const OrderResult(
        success: false,
        message: 'Jumlah porsi tidak wajar (1..4).',
      );
    }
    try {
      final callable = _functions.httpsCallable('createOrder');
      final res = await callable.call(<String, dynamic>{
        'listingId': listingId,
        'quantity': quantity,
        if (faceToken != null) 'faceToken': faceToken,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final orderId = (data['orderId'] as String?) ?? '';
      final token = (data['pickupToken'] as String?) ?? '';
      final expiryRaw = data['reservationExpiresAt'];
      final expiry = expiryRaw is String
          ? DateTime.tryParse(expiryRaw)
          : _date(expiryRaw);
      if (orderId.isEmpty || token.isEmpty) {
        return const OrderResult(
          success: false,
          message: 'Server tidak mengembalikan kode pengambilan.',
        );
      }
      await PickupTokenVault.save(
        orderId: orderId,
        token: token,
        reservationExpiresAt: expiry,
      );
      return OrderResult(
        success: true,
        message: 'Pesanan dibuat.',
        orderId: orderId,
        pickupCode: token,
        reservationExpiresAt: expiry,
      );
    } on FirebaseFunctionsException catch (error) {
      return OrderResult(
        success: false,
        message: _functionMessage(error, 'Pesanan belum dapat dibuat.'),
      );
    } catch (error) {
      return OrderResult(
        success: false,
        message: _dataError(error, 'Pesanan belum dapat dibuat.').message,
      );
    }
  }

  @override
  Future<List<OrderSummary>> fetchMyOrders({bool asRecipient = true}) async {
    final uid = _uid;
    if (uid == null) return [];
    await PickupTokenVault.load();
    try {
      final query = asRecipient
          ? _db
                .collection('orders')
                .where('recipient_id', isEqualTo: uid)
                .orderBy('created_at', descending: true)
                .limit(100)
          : _db
                .collection('orders')
                .where('store_owner_id', isEqualTo: uid)
                .orderBy('created_at', descending: true)
                .limit(100);
      final snap = await query.get();
      return [for (final doc in snap.docs) _orderFromDoc(doc.id, doc.data())];
    } catch (error) {
      throw _dataError(error, 'Pesanan belum dapat dimuat.');
    }
  }

  OrderSummary _orderFromDoc(String id, Map<String, dynamic> row) {
    final created = _date(row['created_at']) ?? DateTime.now();
    final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
    final unitPrice = (row['unit_price'] as num?)?.toInt() ?? 0;
    return OrderSummary(
      id: id,
      listingTitle: (row['listing_title'] as String?) ?? '',
      listingCategory: (row['listing_category'] as String?) ?? 'lainnya',
      listingImage: row['listing_image'] as String?,
      storeName: (row['store_name'] as String?) ?? '',
      recipientName: row['recipient_name'] as String?,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice:
          (row['total_price'] as num?)?.toInt() ?? quantity * unitPrice,
      status: (row['status'] as String?) ?? 'menunggu',
      paymentStatus: (row['payment_status'] as String?) ?? 'belum_dibayar',
      createdAt: created,
      pickupCode: PickupTokenVault.tokenFor(id) ?? '',
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw _dataError(error, 'Status pesanan belum dapat diubah.');
    }
  }

  @override
  Future<void> markPickedUp(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'selesai',
        'picked_up_at': FieldValue.serverTimestamp(),
        'pickup_verified': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw _dataError(error, 'Pesanan belum dapat diselesaikan.');
    }
  }

  @override
  Future<({bool ok, String message, String? orderId})> claimPickup({
    required String storeId,
    required String token,
  }) async {
    if (_uid == null) {
      return (
        ok: false,
        message: 'Belum masuk sebagai penyedia.',
        orderId: null,
      );
    }
    try {
      final callable = _functions.httpsCallable('claimPickup');
      final res = await callable.call(<String, dynamic>{
        'storeId': storeId,
        'token': token.trim().toUpperCase(),
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return (
        ok: true,
        message: (data['message'] as String?) ??
            'Pengambilan terverifikasi di server.',
        orderId: data['orderId'] as String?,
      );
    } on FirebaseFunctionsException catch (error) {
      return (
        ok: false,
        message: _functionMessage(error, 'Pengambilan belum dapat diproses.'),
        orderId: null,
      );
    } catch (error) {
      return (
        ok: false,
        message: _dataError(error, 'Pengambilan belum dapat diproses.').message,
        orderId: null,
      );
    }
  }

  @override
  Future<List<({FoodListing listing, double jarakM})>> fetchNearbyListings(
    double lat,
    double lng, {
    int radiusM = 8000,
    int limit = 50,
  }) async {
    try {
      final callable = _functions.httpsCallable('nearbyListings');
      final res = await callable.call(<String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'limit': limit,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final rows = (data['listings'] as List?) ?? const [];
      return [
        for (final item in rows.whereType<Map>())
          (
            listing: _listingFromDoc(
              (item['id'] as String?) ?? '',
              Map<String, dynamic>.from(item),
            ),
            jarakM: (item['distanceM'] as num?)?.toDouble() ?? 0,
          ),
      ];
    } on FirebaseFunctionsException catch (error) {
      throw DataActionException(
        _functionMessage(error, 'Feed terdekat belum tersedia.'),
      );
    } catch (error) {
      throw _dataError(error, 'Feed terdekat belum tersedia.');
    }
  }

  // ==================== STORES ====================

  @override
  Future<StoreProfile?> getMyStore() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _db
          .collection('stores')
          .where('owner_id', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return _storeFromDoc(doc.id, doc.data());
    } catch (error) {
      throw _dataError(error, 'Toko belum dapat dimuat.');
    }
  }

  StoreProfile _storeFromDoc(String id, Map<String, dynamic> row) {
    final app = row['application'];
    return StoreProfile(
      id: id,
      ownerId: (row['owner_id'] as String?) ?? '',
      namaToko: (row['name'] as String?) ?? '',
      jenisUsaha: (row['business_type'] as String?) ?? 'lainnya',
      alamat: (row['address'] as String?) ?? '',
      kota: (row['city'] as String?) ?? '',
      verificationStatus:
          (row['verification_status'] as String?) ?? 'belum_diajukan',
      application: app is Map
          ? StoreApplication(
              namaToko: (row['name'] as String?) ?? '',
              jenisUsaha: (row['business_type'] as String?) ?? 'lainnya',
              nomorUsaha: (app['business_number'] as String?) ?? '',
              telepon: (app['phone'] as String?) ?? '',
              alamat: (row['address'] as String?) ?? '',
              kota: (row['city'] as String?) ?? '',
              fotoSiap: app['photo_prepared'] == true,
              lokasiSiap: app['location_prepared'] == true,
            )
          : null,
      createdAt: _date(row['created_at']) ?? DateTime.now(),
    );
  }

  @override
  Future<StoreProfile> createStore(StoreApplication app) async {
    if (_uid == null) throw const DataActionException('Belum masuk.');
    try {
      final callable = _functions.httpsCallable('createStore');
      final res = await callable.call(<String, dynamic>{
        'name': app.namaToko,
        'businessType': app.jenisUsaha,
        'businessNumber': app.nomorUsaha,
        'phone': app.telepon,
        'address': app.alamat,
        'city': app.kota,
        'photoPrepared': app.fotoSiap,
        'locationPrepared': app.lokasiSiap,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final row = Map<String, dynamic>.from(data['store'] as Map);
      return _storeFromDoc(
        (data['storeId'] as String?) ?? '',
        row,
      );
    } on FirebaseFunctionsException catch (error) {
      throw DataActionException(
        _functionMessage(error, 'Pengajuan toko belum dapat dikirim.'),
      );
    } catch (error) {
      throw _dataError(error, 'Pengajuan toko belum dapat dikirim.');
    }
  }

  // ==================== IMPACT ====================

  @override
  Future<ImpactSummary?> fetchImpact() async {
    try {
      final doc = await _db.collection('impact_stats').doc('global').get();
      if (!doc.exists) return null;
      final data = doc.data() ?? const <String, dynamic>{};
      return ImpactSummary(
        porsiTersalurkan: (data['porsi_tersalurkan'] as num?)?.toInt() ?? 0,
        pesananSelesai: (data['pesanan_selesai'] as num?)?.toInt() ?? 0,
        penyediaAktif: (data['penyedia_aktif'] as num?)?.toInt() ?? 0,
        estimasiKg: (data['estimasi_kg'] as num?)?.toDouble() ?? 0,
        estimasiCo2eKg:
            (data['estimasi_co2e_kg'] as num?)?.toDouble() ?? 0,
      );
    } catch (error) {
      throw _dataError(error, 'Dampak belum dapat dimuat.');
    }
  }

  // ==================== LEGACY PAYMENT METHODS ====================

  @override
  Future<PaymentRecord?> createPayment({
    required String orderId,
    required int amount,
    required String method,
    required String gatewayRef,
  }) async => null;

  @override
  Future<void> updatePaymentStatus(String paymentId, String status) async {}

  // ==================== HELPERS ====================

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  DataActionException _dataError(Object error, String fallback) {
    if (error is DataActionException) return error;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return DataActionException(
          '$fallback Akses ditolak — periksa aturan Firestore.',
        );
      }
      if (error.code == 'unavailable') {
        return DataActionException('$fallback Layanan tidak terjangkau.');
      }
      if (error.code == 'failed-precondition') {
        return DataActionException(
          '$fallback Indeks Firestore mungkin belum dibuat.',
        );
      }
    }
    if (kDebugMode) debugPrint('Firestore data error: $error');
    return DataActionException(fallback);
  }

  String _functionMessage(
    FirebaseFunctionsException error,
    String fallback,
  ) {
    final detail = error.details;
    if (detail is Map && detail['message'] is String) {
      return detail['message'] as String;
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!;
    }
    switch (error.code) {
      case 'unauthenticated':
        return 'Masuk dengan Google dulu.';
      case 'permission-denied':
        return 'Akses ditolak.';
      case 'failed-precondition':
        return 'Verifikasi wajah atau data pesanan belum memenuhi syarat.';
      case 'unavailable':
        return 'Layanan server tidak terjangkau.';
      default:
        return fallback;
    }
  }
}

class DataActionException implements Exception {
  final String message;
  const DataActionException(this.message);
  @override
  String toString() => message;
}
