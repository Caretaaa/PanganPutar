import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_data.dart';
import '../models/models.dart' show FoodListing, ImpactSummary;
import '../models/payment.dart';
import '../services/contracts.dart';
import 'pickup_token_vault.dart';

/// Service produksi lama (Supabase). Dipertahankan sebagai jalur rollback dan
/// agar tes kontrak lama tetap berjalan; aplikasi produksi sekarang memakai
/// `FirebaseDataService`.
class SupabaseDataService extends ChangeNotifier implements PanganDataService {
  SupabaseDataService._();
  static final instance = SupabaseDataService._();

  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  // ==================== LISTINGS (food_listings) ====================

  Future<List<FoodListing>> fetchListings({
    String query = '',
    String kategori = '',
    String kota = '',
    bool gratisSaja = false,
    int limit = 48,
  }) async {
    if (_uid == null) return [];

    dynamic q = _sb
        .from('food_listings')
        .select('''
          *,
          stores!inner (
            id, name, business_type, address, city, verification_status
          )
        ''')
        .eq('stores.verification_status', 'terverifikasi')
        .eq('status', 'tersedia')
        .gt('quantity_available', 0)
        .gt('pickup_end', DateTime.now().toIso8601String())
        .order('pickup_start', ascending: true)
        .limit(limit);

    if (query.trim().isNotEmpty) {
      q = q.ilike('title', '%${query.trim()}%');
    }
    if (kategori.isNotEmpty) {
      q = q.eq('category', kategori);
    }
    if (kota.trim().isNotEmpty) {
      q = q.ilike('stores.city', '%${kota.trim()}%');
    }
    if (gratisSaja) {
      q = q.eq('price_rupiah', 0);
    }

    final res = await q;
    return (res as List)
        .whereType<Map<String, Object?>>()
        .map(_listingFromRow)
        .toList();
  }

  Future<FoodListing?> fetchDetail(String id) async {
    if (_uid == null) return null;

    final res = await _sb
        .from('food_listings')
        .select('''
          *,
          stores!inner (
            id, name, business_type, address, city, verification_status
          )
        ''')
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return _listingFromRow(res);
  }

  FoodListing _listingFromRow(Map<String, Object?> row) {
    final store = row['stores'] as Map<String, Object?>;
    return FoodListing(
      id: row['id'] as String,
      providerId: row['store_id'] as String,
      title: row['title'] as String,
      category: row['category'] as String,
      description: row['description'] as String?,
      imageUrl: row['image_path'] as String?,
      quantityTotal: row['quantity_total'] as int,
      quantityAvailable: row['quantity_available'] as int,
      unit: row['unit'] as String? ?? 'porsi',
      priceRupiah: row['price_rupiah'] as int? ?? 0,
      isFree: (row['price_rupiah'] as int? ?? 0) == 0,
      city: store['city'] as String? ?? '',
      district: '',
      pickupAddress: store['address'] as String? ?? '',
      pickupStart: DateTime.parse(row['pickup_start'] as String),
      pickupEnd: DateTime.parse(row['pickup_end'] as String),
      storageNote: row['storage_note'] as String?,
      allergenInfo: row['allergen_info'] as String?,
      status: row['status'] as String? ?? 'draft',
    );
  }

  // ==================== MY LISTINGS (penyedia) ====================

  Future<List<FoodListing>> fetchMyListings() async {
    if (_uid == null) return [];

    dynamic q = _sb
        .from('food_listings')
        .select('''
          *,
          stores!inner (id, name, business_type, address, city, verification_status)
        ''')
        .eq('stores.owner_id', _uid!)
        .order('created_at', ascending: false);

    final res = await q;
    return (res as List)
        .whereType<Map<String, Object?>>()
        .map(_listingFromRow)
        .toList();
  }

  Future<FoodListing> createListing(FoodListing listing) async {
    if (_uid == null) throw StateError('Belum masuk');

    // Verify store ownership
    final store = await _sb
        .from('stores')
        .select('id')
        .eq('owner_id', _uid!)
        .maybeSingle();

    if (store == null) {
      throw StateError('Anda belum memiliki toko terverifikasi.');
    }

    final res = await _sb
        .from('food_listings')
        .insert({
          'store_id': store['id'],
          'title': listing.title,
          'category': listing.category,
          'description': listing.description,
          'quantity_total': listing.quantityTotal,
          'quantity_available': listing.quantityAvailable,
          'unit': listing.unit,
          'price_rupiah': listing.priceRupiah,
          'pickup_start': listing.pickupStart.toIso8601String(),
          'pickup_end': listing.pickupEnd.toIso8601String(),
          'storage_note': listing.storageNote,
          'allergen_info': listing.allergenInfo,
          'image_path': listing.imageUrl,
          'status': 'tersedia',
        })
        .select()
        .single();

    return _listingFromRow(res);
  }

  Future<void> updateListing(FoodListing listing) async {
    if (_uid == null) throw StateError('Belum masuk');

    await _sb
        .from('food_listings')
        .update({
          'title': listing.title,
          'category': listing.category,
          'description': listing.description,
          'quantity_total': listing.quantityTotal,
          'quantity_available': listing.quantityAvailable,
          'unit': listing.unit,
          'price_rupiah': listing.priceRupiah,
          'pickup_start': listing.pickupStart.toIso8601String(),
          'pickup_end': listing.pickupEnd.toIso8601String(),
          'storage_note': listing.storageNote,
          'allergen_info': listing.allergenInfo,
          'image_path': listing.imageUrl,
          'status': listing.status,
        })
        .eq('id', listing.id);
  }

  Future<void> deleteListing(String id) async {
    if (_uid == null) throw StateError('Belum masuk');
    await _sb
        .from('food_listings')
        .delete()
        .eq('id', id);
  }

  // ==================== ORDERS ====================

  /// Buat pesanan lewat RPC server `create_order`
  /// (supabase/migrations/202610240001_backend_inti.sql):
  /// - stok atomik dengan `FOR UPDATE` (tanpa jalur manual stok-sisi-klien),
  /// - kuota harian dipegang server (maks 4 porsi / 2 pesanan),
  /// - token QR serah-terima acak di sisi SERVER; plaintext dikembalikan
  ///   sekali di respons, server hanya menyimpan hash.
  ///
  /// Bila RPC belum ada (migrasi tidak diterapkan), ini GAGAL dengan pesan
  /// jujur — tidak ada fallback "pura-pura sukses" sisi klien.
  Future<OrderResult> createOrder({
    required String listingId,
    required int quantity,
    String? faceToken,
  }) async {
    if (_uid == null) {
      return const OrderResult(success: false, message: 'Belum masuk.');
    }
    if (quantity < 1 || quantity > 4) {
      // Batas yang sama dengan SQL create_order (p_quantity 1..4).
      return const OrderResult(
        success: false,
        message: 'Jumlah porsi tidak wajar (1..4).',
      );
    }

    // RPC butuh store_id: ambil dari listing (satu baca kecil).
    final row = await _sb
        .from('food_listings')
        .select('store_id')
        .eq('id', listingId)
        .maybeSingle();
    if (row == null) {
      return const OrderResult(
        success: false,
        message: 'Penawaran tidak ditemukan.',
      );
    }
    final storeId = row['store_id'] as String;

    try {
      final res = await _sb.rpc('create_order', params: {
        'p_listing_id': listingId,
        'p_store_id': storeId,
        'p_quantity': quantity,
      }) as Map<String, Object?>;

      final orderId = res['order_id'] as String;
      final token = res['pickup_token'] as String;
      final expiryRaw = res['reservation_expires_at'] as String?;
      final expiry = expiryRaw == null ? null : DateTime.tryParse(expiryRaw);

      // Simpan plaintext di perangkat pembeli (server hanya punya hash).
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
    } on PostgrestException catch (e) {
      return OrderResult(
        success: false,
        message: _orderErrorMessage(e, fallback: 'Gagal membuat pesanan.'),
      );
    } catch (e) {
      return OrderResult(
        success: false,
        message: 'Gagal membuat pesanan: $e',
      );
    }
  }

  /// Pesan raise-exception dari server sudah berbahasa Indonesia dan se-api
  /// dengan jalur demo ('stok tidak cukup', 'kuota pesanan harian habis',
  /// dst.) — cukup diteruskan. Pengecualian: bila RPC belum diterapkan
  /// (PGRST202 / 42883), tampilkan pesan jujur, bukan "stok habis".
  String _orderErrorMessage(PostgrestException e, {required String fallback}) {
    final code = e.code;
    if (code == 'PGRST202' || code == '42883' || code == '40414') {
      return 'Sisi server belum menerapkan migrasi backend inti. '
          'Jalankan supabase/migrations/202610240001_backend_inti.sql '
          'lewat SQL Editor (lihat supabase/README_BACKEND.md).';
    }
    final msg = e.message.trim();
    return msg.isEmpty ? fallback : msg;
  }

  Future<List<OrderSummary>> fetchMyOrders({bool asRecipient = true}) async {
    if (_uid == null) return [];
    // Kode pickup hanya tersimpan di perangkat pembeli (vault) — muat dulu.
    await PickupTokenVault.load();

    if (!asRecipient) {
      // Get store IDs owned by user
      final stores = await _sb
          .from('stores')
          .select('id')
          .eq('owner_id', _uid!);
      final storeIds = (stores as List).map((e) => e['id'] as String).toList();
      if (storeIds.isEmpty) return [];

      dynamic q = _sb
          .from('orders')
          .select('''
            *,
            food_listings!inner (title, category, image_path),
            stores!inner (name),
            recipient:profiles!orders_recipient_id_fkey (display_name)
          ''')
          .inFilter('store_id', storeIds)
          .order('created_at', ascending: false);

      final res = await q;
      return (res as List).map((e) => _orderSummaryFromRow(e as Map<String, Object?>)).toList();
    }

    dynamic q = _sb
        .from('orders')
        .select('''
          *,
          food_listings!inner (title, category, image_path),
          stores!inner (name),
          recipient:profiles!orders_recipient_id_fkey (display_name)
        ''')
        .eq('recipient_id', _uid!)
        .order('created_at', ascending: false);

    final res = await q;
    return (res as List).map((e) => _orderSummaryFromRow(e as Map<String, Object?>)).toList();
  }

  OrderSummary _orderSummaryFromRow(Map<String, Object?> row) {
    final listing = row['food_listings'] as Map<String, Object?>;
    final store = row['stores'] as Map<String, Object?>;
    final recipient = row['recipient'] as Map<String, Object?>?;

    return OrderSummary(
      id: row['id'] as String,
      listingTitle: listing['title'] as String,
      listingCategory: listing['category'] as String,
      listingImage: listing['image_path'] as String?,
      storeName: store['name'] as String,
      recipientName: recipient?['display_name'] as String?,
      quantity: row['quantity'] as int,
      unitPrice: row['unit_price_rupiah'] as int,
      totalPrice: row['total_rupiah'] as int? ?? (row['quantity'] as int) * (row['unit_price_rupiah'] as int),
      status: row['status'] as String,
      paymentStatus: row['payment_status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      // Jujur: server TIDAK menyimpan plaintext token (hanya hash). Kode
      // hanya tampil bila perangkat ini yang membuat pesanan. '' berarti
      // UI wajib menampilkan pesan "kode tidak tersedia di perangkat ini",
      // bukan mengarang kode.
      pickupCode: PickupTokenVault.tokenFor(row['id'] as String) ?? '',
    );
  }

  // ==================== SERAH-TERIMA (PRODUKSI) ====================

  /// Penyedia menukar kode QR pembeli dengan keputusan server:
  /// RPC `claim_pickup` membandingkan hash SHA-256 token dan menuntaskan
  /// pesanan. QR bekas / pesanan tertutup ditolak di server, bukan di klien.
  Future<({bool ok, String message, String? orderId})> claimPickup({
    required String storeId,
    required String token,
  }) async {
    if (_uid == null) {
      return (ok: false, message: 'Belum masuk sebagai penyedia.', orderId: null);
    }
    final t = token.trim().toUpperCase();
    try {
      final res = await _sb.rpc('claim_pickup', params: {
        'p_store_id': storeId,
        'p_token': t,
      });
      return (
        ok: true,
        message: 'Pengambilan terverifikasi di server.',
        orderId: res?.toString(),
      );
    } on PostgrestException catch (e) {
      final code = e.code;
      if (code == 'PGRST202' || code == '42883' || code == '40414') {
        return (
          ok: false,
          message: 'Sisi server belum menerapkan migrasi backend inti '
              '(claim_pickup). Lihat supabase/README_BACKEND.md.',
          orderId: null,
        );
      }
      return (ok: false, message: e.message, orderId: null);
    } catch (e) {
      return (
        ok: false,
        message: 'Gagal memproses pengambilan: $e',
        orderId: null,
      );
    }
  }

  // ==================== FEED TERDEKAT (POSTGIS) ====================

  /// Feed "Dekat saya" produksi via RPC `nearby_listings` (PostGIS):
  /// hanya toko terverifikasi berlokasi, urut jarak ↑ lalu pickup_end ↑.
  /// Jarak dihitung SERVER — klien tidak mengarang angka. Bila kandidat
  /// membutuhkan nama toko, diambil lewat bacaan terpisah (RLS mengizinkan).
  Future<List<({FoodListing listing, double jarakM})>> fetchNearbyListings(
    double lat,
    double lng, {
    int radiusM = 8000,
    int limit = 50,
  }) async {
    final res = await _sb.rpc('nearby_listings', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_m': radiusM,
      'p_limit': limit,
    });
    final rows = (res as List)
        .whereType<Map<String, Object?>>()
        .toList();

    final storeIds = rows
        .map((r) => r['store_id'])
        .whereType<String>()
        .toSet()
        .toList();
    final stores = <String, Map<String, Object?>>{};
    if (storeIds.isNotEmpty) {
      final sr = await _sb
          .from('stores')
          .select('id,name,address,city')
          .inFilter('id', storeIds);
      for (final s in (sr as List).whereType<Map<String, Object?>>()) {
        stores[s['id'] as String] = s;
      }
    }

    return [
      for (final r in rows)
        (
          listing: _nearbyListingFromRow(r, stores[r['store_id'] as String?]),
          jarakM: (r['distance_m'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }

  FoodListing _nearbyListingFromRow(
    Map<String, Object?> row,
    Map<String, Object?>? store,
  ) {
    final sisa = row['quantity_available'] as int? ?? 0;
    return FoodListing(
      id: row['listing_id'] as String,
      providerId: row['store_id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      category: row['category'] as String? ?? 'lainnya',
      quantityTotal: sisa, // RPC tidak memberi total awal; jangan dikarang.
      quantityAvailable: sisa,
      unit: row['unit'] as String? ?? 'porsi',
      priceRupiah: row['price_rupiah'] as int? ?? 0,
      isFree: (row['price_rupiah'] as int? ?? 0) == 0,
      city: store?['city'] as String? ?? '',
      district: '',
      pickupAddress: store?['address'] as String? ?? '',
      pickupStart: DateTime.parse(row['pickup_start'] as String),
      pickupEnd: DateTime.parse(row['pickup_end'] as String),
      storageNote: row['storage_note'] as String?,
      allergenInfo: row['allergen_info'] as String?,
      status: 'tersedia',
    );
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    if (_uid == null) throw StateError('Belum masuk');
    await _sb
        .from('orders')
        .update({'status': status})
        .eq('id', orderId);
  }

  Future<void> markPickedUp(String orderId) async {
    if (_uid == null) throw StateError('Belum masuk');
    await _sb
        .from('orders')
        .update({
          'status': 'selesai',
          'picked_up_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  // ==================== STORES & VERIFICATION ====================

  Future<StoreProfile?> getMyStore() async {
    if (_uid == null) return null;

    dynamic q = _sb
        .from('stores')
        .select('*, store_applications(*)')
        .eq('owner_id', _uid!);

    final res = await q.maybeSingle();

    if (res == null) return null;
    return _storeFromRow(res);
  }

  Future<StoreProfile> createStore(StoreApplication app) async {
    if (_uid == null) throw StateError('Belum masuk');

    // Check profile role
    final profile = await _sb
        .from('profiles')
        .select('role')
        .eq('id', _uid!)
        .maybeSingle();

    if (profile == null || profile['role'] != 'penyedia') {
      throw StateError('Hanya akun dengan peran penyedia yang bisa membuat toko.');
    }

    // Create store
    final storeRes = await _sb
        .from('stores')
        .insert({
          'owner_id': _uid!,
          'name': app.namaToko,
          'business_type': app.jenisUsaha,
          'address': app.alamat,
          'city': app.kota,
          'verification_status': 'menunggu_review',
        })
        .select()
        .single();

    // Create application
    await _sb
        .from('store_applications')
        .insert({
          'store_id': storeRes['id'],
          'business_number': app.nomorUsaha,
          'phone': app.telepon,
          'photo_prepared': app.fotoSiap,
          'location_prepared': app.lokasiSiap,
        });

    return _storeFromRow(storeRes);
  }

  StoreProfile _storeFromRow(Map<String, Object?> row) {
    final app = row['store_applications'];
    StoreApplication? application;
    if (app is Map) {
      application = StoreApplication(
        namaToko: row['name'] as String,
        jenisUsaha: row['business_type'] as String,
        nomorUsaha: app['business_number'] as String,
        telepon: app['phone'] as String,
        alamat: row['address'] as String,
        kota: row['city'] as String,
        fotoSiap: app['photo_prepared'] as bool? ?? false,
        lokasiSiap: app['location_prepared'] as bool? ?? false,
      );
    }

    return StoreProfile(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      namaToko: row['name'] as String,
      jenisUsaha: row['business_type'] as String,
      alamat: row['address'] as String,
      kota: row['city'] as String,
      verificationStatus: row['verification_status'] as String,
      application: application,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ==================== PAYMENTS ====================

  Future<PaymentRecord?> createPayment({
    required String orderId,
    required int amount,
    required String method,
    required String gatewayRef,
  }) async {
    if (_uid == null) throw StateError('Belum masuk');

    final res = await _sb
        .from('payments')
        .insert({
          'order_id': orderId,
          'amount_rupiah': amount,
          'status': 'menunggu',
          'method': method,
          'gateway_reference': gatewayRef,
        })
        .select()
        .single();

    return PaymentRecord(
      orderId: res['order_id'] as String,
      grossAmount: res['amount_rupiah'] as int,
      status: paymentStatusFromCode(res['status'] as String),
      metode: res['method'] as String?,
      transaksiId: res['gateway_reference'] as String,
      simulasi: false,
    );
  }

  Future<void> updatePaymentStatus(String paymentId, String status) async {
    await _sb
        .from('payments')
        .update({'status': status})
        .eq('id', paymentId);
  }

  // ==================== IMPACT ====================

  Future<ImpactSummary?> fetchImpact() async {
    if (_uid == null) return null;

    // Aggregate from orders
    final orders = await _sb
        .from('orders')
        .select('quantity, unit_price_rupiah, total_rupiah, status, food_listings(category)')
        .eq('recipient_id', _uid!)
        .eq('status', 'selesai');

    int totalPorsi = 0;
    int totalKg = 0;
    double co2e = 0;

    for (final o in (orders as List)) {
      final qty = o['quantity'] as int;
      totalPorsi += qty;
      // Estimasi kasar: 1 porsi = 0.3kg, 1kg makanan = 2.5kg CO2e
      totalKg += (qty * 0.3).round();
      co2e += qty * 0.3 * 2.5;
    }

    return ImpactSummary(
      porsiTersalurkan: totalPorsi,
      pesananSelesai: orders.length,
      penyediaAktif: 0,
      estimasiKg: totalKg.toDouble(),
      estimasiCo2eKg: co2e,
    );
  }
}