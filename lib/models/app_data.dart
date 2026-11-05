/// Data transfer objects shared by demo and production services.
///
/// These were previously declared in `services/service_holder.dart`.
/// Keeping them in `models/` lets the service contracts depend on them
/// without importing a concrete backend (Supabase/Firebase).
library;

/// Hasil operasi pesanan.
class OrderResult {
  final bool success;
  final String message;
  final String? orderId;
  final String? pickupCode;

  /// Batas waktu reservasi stok (TTL 10 menit) untuk countdown
  /// "selesaikan pembayaran". `null` di jalur demo — demo tidak menahan stok.
  final DateTime? reservationExpiresAt;

  const OrderResult({
    required this.success,
    required this.message,
    this.orderId,
    this.pickupCode,
    this.reservationExpiresAt,
  });
}

/// Ringkasan pesanan untuk UI.
class OrderSummary {
  final String id;
  final String listingTitle;
  final String listingCategory;
  final String? listingImage;
  final String storeName;
  final String? recipientName;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final String pickupCode;

  const OrderSummary({
    required this.id,
    required this.listingTitle,
    required this.listingCategory,
    this.listingImage,
    required this.storeName,
    this.recipientName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.pickupCode,
  });
}

/// Profil toko.
class StoreProfile {
  final String id;
  final String ownerId;
  final String namaToko;
  final String jenisUsaha;
  final String alamat;
  final String kota;
  final String verificationStatus;
  final StoreApplication? application;
  final DateTime createdAt;

  const StoreProfile({
    required this.id,
    required this.ownerId,
    required this.namaToko,
    required this.jenisUsaha,
    required this.alamat,
    required this.kota,
    required this.verificationStatus,
    this.application,
    required this.createdAt,
  });

  bool get terverifikasi => verificationStatus == 'terverifikasi';
  bool get menungguReview => verificationStatus == 'menunggu_review';
}

/// Aplikasi verifikasi toko.
class StoreApplication {
  final String namaToko;
  final String jenisUsaha;
  final String nomorUsaha;
  final String telepon;
  final String alamat;
  final String kota;
  final bool fotoSiap;
  final bool lokasiSiap;

  const StoreApplication({
    required this.namaToko,
    required this.jenisUsaha,
    required this.nomorUsaha,
    required this.telepon,
    required this.alamat,
    required this.kota,
    required this.fotoSiap,
    required this.lokasiSiap,
  });
}
