import 'package:flutter/widgets.dart';

import '../models/app_data.dart';
import '../models/models.dart';
import '../models/payment.dart';
import '../services/claim_ledger.dart';
import '../services/contracts.dart';
import '../services/demo_store.dart';
import '../services/device_identity.dart';
import '../services/midtrans.dart';
import '../services/provider_registry.dart';
import '../services/session.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_data_service.dart';
import '../widgets/app_holders.dart';

export '../models/app_data.dart' show
    OrderResult,
    OrderSummary,
    StoreApplication,
    StoreProfile;

/// Mode aplikasi: demo (lokal) atau production (Firebase).
enum AppMode { demo, production }

/// Konfigurasi mode aplikasi.
/// Diatur sekali di startup berdasarkan environment / build config.
class AppConfig extends ChangeNotifier {
  AppConfig._();
  static final instance = AppConfig._();

  AppMode _mode = AppMode.demo;
  bool _initialized = false;

  AppMode get mode => _mode;
  bool get isProduction => _mode == AppMode.production;
  bool get isDemo => _mode == AppMode.demo;
  bool get initialized => _initialized;

  /// Inisialisasi dari environment / dart-define.
  /// - PRODUCTION_MODE=true → production
  /// - Default: demo
  Future<void> initialize() async {
    if (_initialized) return;

    const fromEnv = String.fromEnvironment(
      'PRODUCTION_MODE',
      defaultValue: '',
    );
    final isProd = fromEnv.toLowerCase() == 'true';

    _mode = isProd ? AppMode.production : AppMode.demo;
    _initialized = true;
    notifyListeners();
  }

  /// Ganti mode runtime (hanya untuk testing/debug).
  void setMode(AppMode mode) {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
  }
}

/// Factory: bangun ServicesHolder sesuai mode.
class ServicesHolderFactory {
  static Future<ServicesHolder> create({
    required Widget child,
    required AppConfig config,
    required SessionState session,
    required PanganAuthService auth,
    required DeviceIdentity device,
    required DailyClaimLedger ledger,
    required ProviderRegistry providers,
    required PaymentGateway payments,
    required PanganDataService data,
    FaceVerificationGateway? face,
  }) async {
    // Pre-load services yang butuh init async
    await device.load();
    final id = device.deviceId;
    if (id != null) await ledger.load(id);
    await providers.load();

    return ServicesHolder(
      device: device,
      ledger: ledger,
      providers: providers,
      payments: payments,
      auth: auth,
      data: data,
      face: face,
      config: config,
      session: session,
      child: child,
    );
  }
}

/// Helper: cek apakah sedang mode production DAN user sudah login.
bool isProductionReady(BuildContext context) {
  final holder = ServicesHolder.of(context);
  return holder.config.isProduction && holder.auth.isSignedIn;
}

/// Implementasi untuk DemoStore (adaptor).
class DemoDataService implements PanganDataService {
  final DemoStore _store;
  final ProviderRegistry _providers;
  DemoDataService(this._store, this._providers);

  @override
  Future<List<FoodListing>> fetchListings({
    String query = '',
    String kategori = '',
    String kota = '',
    bool gratisSaja = false,
    int limit = 48,
  }) async {
    var list = _store.myListings;
    if (query.isNotEmpty) {
      list = list.where((e) => e.title.toLowerCase().contains(query.toLowerCase())).toList();
    }
    if (kategori.isNotEmpty) {
      list = list.where((e) => e.category == kategori).toList();
    }
    if (kota.isNotEmpty) {
      list = list.where((e) => e.city.toLowerCase().contains(kota.toLowerCase())).toList();
    }
    if (gratisSaja) {
      list = list.where((e) => e.isFree || e.priceRupiah == 0).toList();
    }
    return list;
  }

  @override
  Future<FoodListing?> fetchDetail(String id) async {
    try {
      return _store.myListings.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FoodListing>> fetchMyListings() async => _store.myListings;

  @override
  Future<FoodListing> createListing(FoodListing listing) async {
    _store.addListing(listing);
    return listing;
  }

  @override
  Future<void> updateListing(FoodListing listing) async {
    final idx = _store.myListings.indexWhere((e) => e.id == listing.id);
    if (idx >= 0) {
      _store.myListings[idx] = listing;
      _store.bumpListeners(); // API publik DemoStore (bukan notifyListeners).
    }
  }

  @override
  Future<void> deleteListing(String id) async {
    _store.myListings.removeWhere((e) => e.id == id);
    _store.bumpListeners();
  }

  @override
  Future<OrderResult> createOrder({
    required String listingId,
    required int quantity,
    String? faceToken,
  }) async {
    final listing = _store.myListings.firstWhere((e) => e.id == listingId);
    if (quantity > listing.quantityAvailable) {
      return OrderResult(success: false, message: 'Stok tidak mencukupi');
    }
    final code = _store.placeOrder(listing, quantity);
    return OrderResult(success: true, message: 'Pesanan dibuat', pickupCode: code);
  }

  @override
  Future<List<OrderSummary>> fetchMyOrders({bool asRecipient = true}) async {
    final orders = asRecipient ? _store.myOrders : _store.myOrders; // Demo: same
    return orders.map((o) => OrderSummary(
      id: o.id,
      listingTitle: o.listing.title,
      listingCategory: o.listing.category,
      listingImage: o.listing.imageUrl,
      storeName: o.listing.providerId, // Demo: providerId as store name
      recipientName: null,
      quantity: o.quantity,
      unitPrice: o.listing.effectivePrice,
      totalPrice: o.total,
      status: o.status,
      paymentStatus: o.paymentStatus.name,
      createdAt: o.createdAt,
      pickupCode: o.pickupCode,
    )).toList();
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    _store.setOrderStatus(orderId, status);
  }

  @override
  Future<void> markPickedUp(String orderId) async {
    _store.markPickedUp(orderId);
  }

  @override
  Future<StoreProfile?> getMyStore() async {
    if (!_providers.isVerified('demo-penyedia')) return null;
    return StoreProfile(
      id: 'demo-penyedia',
      ownerId: 'demo-penyedia',
      namaToko: 'Toko Demo',
      jenisUsaha: 'Warung makan',
      alamat: 'Jl. Demo No. 1',
      kota: 'Bandung',
      verificationStatus: 'terverifikasi',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<StoreProfile> createStore(StoreApplication app) async {
    throw UnimplementedError('Demo mode: gunakan ProviderRegistry.submit()');
  }

  @override
  Future<PaymentRecord?> createPayment({
    required String orderId,
    required int amount,
    required String method,
    required String gatewayRef,
  }) async {
    return null; // Demo pakai MidtransPaymentService terpisah
  }

  @override
  Future<void> updatePaymentStatus(String paymentId, String status) async {
    // Demo: handled by MidtransPaymentService
  }

  @override
  Future<ImpactSummary?> fetchImpact() async {
    final orders = _store.myOrders.where((o) => o.status == 'selesai');
    int porsi = 0;
    for (final o in orders) {
      porsi += o.quantity;
    }
    return ImpactSummary(
      porsiTersalurkan: porsi,
      pesananSelesai: orders.length,
      penyediaAktif: 0,
      estimasiKg: porsi * 0.3,
      estimasiCo2eKg: porsi * 0.3 * 2.5,
    );
  }

  @override
  Future<({bool ok, String message, String? orderId})> claimPickup({
    required String storeId,
    required String token,
  }) async => (
    ok: false,
    message: 'Pengambilan produksi memerlukan backend Firebase.',
    orderId: null,
  );

  @override
  Future<List<({FoodListing listing, double jarakM})>> fetchNearbyListings(
    double lat,
    double lng, {
    int radiusM = 8000,
    int limit = 50,
  }) async => [];
}

