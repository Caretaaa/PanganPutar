import 'package:flutter/foundation.dart';

import '../models/app_data.dart';
import '../models/models.dart';
import '../models/payment.dart';

/// Identity contract used by the UI. Implemented by the Firebase production
/// service and by the legacy Supabase service (kept for demo/tests).
abstract class PanganAuthService implements Listenable {
  bool get isReady;
  bool get isConfigured;
  bool get isSignedIn;
  bool get busy;

  String? get initializationError;
  String? get profileError;

  String? get userId;
  String? get email;
  String? get displayName;
  String? get photoUrl;
  String? get role;

  /// Biometric identity attached to this account after a successful selfie
  /// check. Null until the user verifies their face.
  String? get faceIdentityId;
  DateTime? get faceVerifiedAt;

  /// Server-reported weekly usage for the face attached to this account.
  /// Null until the profile/face status has loaded.
  int? get weeklyPorsi;
  int? get weeklyPesanan;
  int get maxPorsiPerWeek;
  int get maxPesananPerWeek;

  /// True when the account has no face or the last check is older than the
  /// server-defined window. The server is still the authority; this is UX.
  bool get needsFaceVerification;

  Future<void> initialize();
  Future<void> refreshProfile();
  Future<bool> signInGoogle();
  Future<void> signOut();
  Future<void> updateProfile({required String name, required String role});
  Future<String?> getIdToken({bool forceRefresh = false});
}

/// Data contract used by screens. Both the demo and Firebase implementations
/// satisfy it; screens never import a concrete backend.
abstract class PanganDataService {
  Future<List<FoodListing>> fetchListings({
    String query = '',
    String kategori = '',
    String kota = '',
    bool gratisSaja = false,
    int limit = 48,
  });

  Future<FoodListing?> fetchDetail(String id);
  Future<List<FoodListing>> fetchMyListings();
  Future<FoodListing> createListing(FoodListing listing);
  Future<void> updateListing(FoodListing listing);
  Future<void> deleteListing(String id);

  Future<OrderResult> createOrder({
    required String listingId,
    required int quantity,
    String? faceToken,
  });

  Future<List<OrderSummary>> fetchMyOrders({bool asRecipient = true});
  Future<void> updateOrderStatus(String orderId, String status);
  Future<void> markPickedUp(String orderId);

  Future<StoreProfile?> getMyStore();
  Future<StoreProfile> createStore(StoreApplication app);
  Future<ImpactSummary?> fetchImpact();

  Future<({bool ok, String message, String? orderId})> claimPickup({
    required String storeId,
    required String token,
  });

  Future<List<({FoodListing listing, double jarakM})>> fetchNearbyListings(
    double lat,
    double lng, {
    int radiusM = 8000,
    int limit = 50,
  });

  Future<PaymentRecord?> createPayment({
    required String orderId,
    required int amount,
    required String method,
    required String gatewayRef,
  });
  Future<void> updatePaymentStatus(String paymentId, String status);
}

/// Payment gateway contract. Production uses Firebase Cloud Functions
/// (Midtrans Snap); demo/tests can keep the HTTP Midtrans service.
abstract class PaymentGateway {
  Future<SnapSession> createSnap({
    required String orderId,
    required int grossAmount,
    required List<PaymentItem> items,
    String? namaPembeli,
    String? deviceId,
  });

  Future<PaymentRecord?> checkStatus(
    String orderId, {
    required int grossAmount,
    String? deviceId,
  });
}

/// Result of one server-side face check. Never contains the raw selfie.
class FaceVerificationResult {
  final String faceId;
  final DateTime verifiedAt;
  final double? matchScore;
  final bool existingFace;
  final int weeklyPorsi;
  final int weeklyPesanan;
  final int maxPorsiPerWeek;
  final int maxPesananPerWeek;
  final String? weekKey;

  const FaceVerificationResult({
    required this.faceId,
    required this.verifiedAt,
    this.matchScore,
    required this.existingFace,
    required this.weeklyPorsi,
    required this.weeklyPesanan,
    required this.maxPorsiPerWeek,
    required this.maxPesananPerWeek,
    this.weekKey,
  });
}

/// Face verification contract. Implemented by a Cloud Functions client.
abstract class FaceVerificationGateway {
  Future<FaceVerificationResult> verifyFace(Uint8List imageBytes);
  Future<FaceVerificationResult?> fetchStatus();
}
