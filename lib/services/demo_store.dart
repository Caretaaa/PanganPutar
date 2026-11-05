import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../models/payment.dart';
import '../data/sample_data.dart';
import '../core/pickup_rules.dart';

class DemoOrder {
  final String id;
  final FoodListing listing;
  final int quantity;
  String status; // menunggu | dikonfirmasi | siap_diambil | selesai | dibatalkan
  final String pickupCode;
  final DateTime createdAt;
  PaymentRecord? payment;

  // Verifikasi serah-terima QR (dua arah):
  DateTime? pickedUpAt; // penyedia memindai tiket QR pembeli
  bool pickupVerified = false; // true = selesai lewat pemindaian QR (bukan tombol manual)
  DateTime? arrivalVerifiedAt; // pembeli memindai QR toko saat tiba

  DemoOrder({
    required this.id,
    required this.listing,
    required this.quantity,
    required this.status,
    required this.pickupCode,
    required this.createdAt,
    this.payment,
  });

  int get total => listing.effectivePrice * quantity;
  bool get perluBayar => total > 0;

  PaymentStatus get paymentStatus =>
      !perluBayar ? PaymentStatus.tidakPerlu : (payment?.status ?? PaymentStatus.belumDibayar);
}

// Penyimpanan lokal perangkat untuk alur pesan/batal/konfirmasi tanpa backend.
// RIWAYAT PESANAN TERSIMPAN DI PERANGKAT (SharedPreferences) dan bertahan
// saat aplikasi di-tutup/di-buka ulang. Tidak ada data akun yang dikirim
// ke database mana pun — login nama tersimpan lokal lewat SessionState.
// Data produksi tetap lewat API/server terpisah bila nanti diaktifkan.
class DemoStore extends ChangeNotifier {
  static const _ordersKey = 'pp_demo_orders_v1';

  final List<FoodListing> myListings = [];
  final List<DemoOrder> myOrders = [];
  int _seq = 1;
  bool _loaded = false;

  /// Menyala ulang pendengar dari luar kelas ini (bukan [notifyListeners]
  /// yang terproteksi Flutter).
  void bumpListeners() => notifyListeners();

  DemoStore() {
    myListings.addAll(sampleListings().take(1));
  }

  bool get loaded => _loaded;

  /// Muat riwayat pesanan tersimpan dari perangkat. Dipanggil sekali di
  /// startup (main.dart) sebelum UI tampil; mutasi berikutnya dipersist.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_ordersKey);
      if (raw == null || raw.isEmpty) return;
      final List list = jsonDecode(raw) as List;
      int maksSeq = 0;
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final order = _orderFromMap(item);
        if (order == null) continue;
        myOrders.add(order);
        final n = int.tryParse(order.id.replaceFirst('demo-', '')) ?? 0;
        if (n > maksSeq) maksSeq = n;
      }
      // Urutkan terbaru dulu agar konsisten dengan placeOrder (insert 0).
      myOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (maksSeq >= _seq) _seq = maksSeq;
    } catch (_) {
      // Data rusak/versi lama: mulai kosong, aplikasi tetap jalan.
      myOrders.clear();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _ordersKey,
        jsonEncode([for (final o in myOrders) _orderToMap(o)]),
      );
    } catch (_) {
      // Penyimpanan penuh/tidak tersedia: pesanan tetap ada di memori.
    }
  }

  Map<String, Object?> _orderToMap(DemoOrder o) => {
    'id': o.id,
    'quantity': o.quantity,
    'status': o.status,
    'pickupCode': o.pickupCode,
    'createdAt': o.createdAt.toIso8601String(),
    'pickedUpAt': o.pickedUpAt?.toIso8601String(),
    'pickupVerified': o.pickupVerified,
    'arrivalVerifiedAt': o.arrivalVerifiedAt?.toIso8601String(),
    'payment': o.payment == null ? null : _paymentToMap(o.payment!),
    'listing': _listingToMap(o.listing),
  };

  DemoOrder? _orderFromMap(Map<String, dynamic> m) {
    final listingMap = m['listing'];
    if (listingMap is! Map<String, dynamic>) return null;
    final paymentMap = m['payment'];
    final pickedUpAt = DateTime.tryParse((m['pickedUpAt'] ?? '').toString());
    final arrival = DateTime.tryParse((m['arrivalVerifiedAt'] ?? '').toString());
    final order = DemoOrder(
      id: (m['id'] ?? '').toString(),
      listing: _listingFromMap(listingMap),
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      status: (m['status'] ?? 'menunggu').toString(),
      pickupCode: (m['pickupCode'] ?? '').toString(),
      createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      payment: paymentMap is Map<String, dynamic> ? _paymentFromMap(paymentMap) : null,
    );
    if (pickedUpAt != null) order.pickedUpAt = pickedUpAt;
    order.pickupVerified = m['pickupVerified'] == true;
    if (arrival != null) order.arrivalVerifiedAt = arrival;
    return order;
  }

  Map<String, Object?> _listingToMap(FoodListing l) => {
    'id': l.id,
    'providerId': l.providerId,
    'title': l.title,
    'category': l.category,
    'description': l.description,
    'imageAsset': l.imageAsset, // ikut disimpan agar foto contoh tidak hilang
    'imageUrl': l.imageUrl,
    'quantityTotal': l.quantityTotal,
    'quantityAvailable': l.quantityAvailable,
    'unit': l.unit,
    'priceRupiah': l.priceRupiah,
    'isFree': l.isFree,
    'city': l.city,
    'district': l.district,
    'pickupAddress': l.pickupAddress,
    'pickupNote': l.pickupNote,
    'pickupStart': l.pickupStart.toIso8601String(),
    'pickupEnd': l.pickupEnd.toIso8601String(),
    'storageNote': l.storageNote,
    'allergenInfo': l.allergenInfo,
    'status': l.status,
  };

  FoodListing _listingFromMap(Map<String, dynamic> m) => FoodListing(
    id: (m['id'] ?? '').toString(),
    providerId: (m['providerId'] ?? '').toString(),
    title: (m['title'] ?? '').toString(),
    category: (m['category'] ?? 'lainnya').toString(),
    description: m['description']?.toString(),
    imageAsset: m['imageAsset']?.toString(),
    imageUrl: m['imageUrl']?.toString(),
    quantityTotal: (m['quantityTotal'] as num?)?.toInt() ?? 0,
    quantityAvailable: (m['quantityAvailable'] as num?)?.toInt() ?? 0,
    unit: (m['unit'] ?? 'porsi').toString(),
    priceRupiah: (m['priceRupiah'] as num?)?.toInt() ?? 0,
    isFree: m['isFree'] == true,
    city: (m['city'] ?? '').toString(),
    district: (m['district'] ?? '').toString(),
    pickupAddress: (m['pickupAddress'] ?? '').toString(),
    pickupNote: m['pickupNote']?.toString(),
    pickupStart: DateTime.tryParse((m['pickupStart'] ?? '').toString()) ??
        DateTime.now(),
    pickupEnd: DateTime.tryParse((m['pickupEnd'] ?? '').toString()) ??
        DateTime.now(),
    storageNote: m['storageNote']?.toString(),
    allergenInfo: m['allergenInfo']?.toString(),
    status: (m['status'] ?? 'tersedia').toString(),
  );

  Map<String, Object?> _paymentToMap(PaymentRecord p) => {
    'orderId': p.orderId,
    'grossAmount': p.grossAmount,
    'status': p.status.name,
    'metode': p.metode,
    'transaksiId': p.transaksiId,
    'dibayarPada': p.dibayarPada?.toIso8601String(),
    'simulasi': p.simulasi,
  };

  PaymentRecord _paymentFromMap(Map<String, dynamic> m) {
    final statusName = (m['status'] ?? '').toString();
    PaymentStatus status = PaymentStatus.belumDibayar;
    for (final s in PaymentStatus.values) {
      if (s.name == statusName) status = s;
    }
    return PaymentRecord(
      orderId: (m['orderId'] ?? '').toString(),
      grossAmount: (m['grossAmount'] as num?)?.toInt() ?? 0,
      status: status,
      metode: m['metode']?.toString(),
      transaksiId: m['transaksiId']?.toString(),
      dibayarPada: DateTime.tryParse((m['dibayarPada'] ?? '').toString()),
      simulasi: m['simulasi'] == true,
    );
  }

  String placeOrder(FoodListing listing, int qty) {
    // Kode pengambilan acak per pesanan — bukan urutan maupun waktu.
    final code = generatePickupCode();
    _seq++;
    myOrders.insert(
      0,
      DemoOrder(
        id: 'demo-$_seq',
        listing: listing,
        quantity: qty,
        status: 'menunggu',
        pickupCode: code,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _persist();
    return code;
  }

  void cancelOrder(String id) {
    final o = myOrders.firstWhere((e) => e.id == id);
    o.status = 'dibatalkan';
    notifyListeners();
    _persist();
  }

  void setOrderStatus(String id, String status) {
    final o = myOrders.firstWhere((e) => e.id == id);
    o.status = status;
    notifyListeners();
    _persist();
  }

  /// Pesanan berdasarkan id, `null` bila tidak ada (dipakai pemindaian QR).
  DemoOrder? orderById(String id) {
    for (final o in myOrders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Pesanan berdasarkan kode pengambilan (mis. barcode struk berisi kode).
  DemoOrder? orderByPickupCode(String code) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    for (final o in myOrders) {
      if (o.pickupCode.toUpperCase() == c) return o;
    }
    return null;
  }

  /// Pembeli dipastikan tiba di toko yang benar (hasil pindai QR toko).
  void markArrivalVerified(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    o.arrivalVerifiedAt = DateTime.now();
    notifyListeners();
    _persist();
  }

  /// Selesaikan pesanan lewat pemindaian QR tiket pembeli.
  /// Ini jalur "terverifikasi": pemilik toko memindai barcode pembeli.
  void markPickedUp(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    o.status = 'selesai';
    o.pickedUpAt = DateTime.now();
    o.pickupVerified = true;
    notifyListeners();
    _persist();
  }

  /// Selesaikan pesanan manual tanpa QR (cadangan bila kamera bermasalah).
  /// Tidak diberi tanda terverifikasi QR.
  void completeManually(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    o.status = 'selesai';
    o.pickedUpAt ??= DateTime.now();
    notifyListeners();
    _persist();
  }

  /// Simpan hasil pembayaran (Midtrans atau simulasi demo).
  void markPayment(String orderId, PaymentRecord record) {
    final o = myOrders.firstWhere((e) => e.id == orderId);
    o.payment = record;
    notifyListeners();
    _persist();
  }

  /// Tambah penawaran baru (dipakai penyedia terverifikasi di demo).
  void addListing(FoodListing listing) {
    myListings.insert(0, listing);
    notifyListeners();
  }
}
