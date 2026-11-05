import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/payment.dart';
import 'contracts.dart';
import 'firebase_settings.dart';

class PaymentActionException implements Exception {
  final String message;
  const PaymentActionException(this.message);
  @override
  String toString() => message;
}

/// Midtrans payments through Firebase Cloud Functions.
///
/// The client never holds a Midtrans server key and never decides that a
/// payment is settled. `paymentsSnap` creates the transaction; the Midtrans
/// webhook (a Cloud Function) is the only writer of the paid state.
class FirebasePaymentService implements PaymentGateway {
  FirebasePaymentService._();
  static final instance = FirebasePaymentService._();

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    region: FirebaseBootstrap.settings.functionsRegion,
  );

  @override
  Future<SnapSession> createSnap({
    required String orderId,
    required int grossAmount,
    required List<PaymentItem> items,
    String? namaPembeli,
    String? deviceId,
  }) async {
    try {
      final callable = _functions.httpsCallable('paymentsSnap');
      final res = await callable.call(<String, dynamic>{'orderId': orderId});
      final data = Map<String, dynamic>.from(res.data as Map);
      final token = (data['token'] as String?)?.trim() ?? '';
      final redirect = (data['redirectUrl'] as String?)?.trim() ?? '';
      if (token.isEmpty || redirect.isEmpty) {
        throw const PaymentActionException(
          'Server pembayaran tidak mengembalikan sesi Midtrans.',
        );
      }
      final expiryRaw = data['expiry'] ?? data['expiresAt'];
      return SnapSession(
        orderId: orderId,
        token: token,
        redirectUrl: redirect,
        kedaluwarsa: expiryRaw is String
            ? DateTime.tryParse(expiryRaw)
            : null,
        simulasi: false,
      );
    } on FirebaseFunctionsException catch (error) {
      throw PaymentActionException(_message(error));
    } on PaymentActionException {
      rethrow;
    } catch (_) {
      throw const PaymentActionException(
        'Layanan pembayaran tidak terjangkau. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  @override
  Future<PaymentRecord?> checkStatus(
    String orderId, {
    required int grossAmount,
    String? deviceId,
  }) async {
    try {
      final callable = _functions.httpsCallable('paymentsStatus');
      final res = await callable.call(<String, dynamic>{'orderId': orderId});
      final data = Map<String, dynamic>.from(res.data as Map);
      final rawStatus =
          (data['status'] ?? data['transactionStatus'] ?? '').toString();
      return PaymentRecord(
        orderId: orderId,
        grossAmount: (data['grossAmount'] as num?)?.toInt() ?? grossAmount,
        status: paymentStatusFromCode(rawStatus),
        metode: data['metode']?.toString() ?? data['paymentType']?.toString(),
        transaksiId:
            data['transactionId']?.toString() ??
            data['transaksiId']?.toString(),
        dibayarPada: _date(data['paidAt'] ?? data['dibayarPada']),
        simulasi: false,
      );
    } on FirebaseFunctionsException catch (error) {
      // Transient errors during polling are not a payment verdict. The next
      // poll will retry; the webhook remains the source of truth.
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return null;
      }
      rethrow;
    } catch (_) {
      return null;
    }
  }

  String _message(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map && details['message'] is String) {
      return details['message'] as String;
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!;
    }
    return switch (error.code) {
      'unauthenticated' => 'Masuk dengan Google dulu untuk membayar.',
      'permission-denied' => 'Pesanan ini bukan milik akun Anda.',
      'failed-precondition' =>
        'Pesanan belum siap dibayar atau reservasi sudah berakhir.',
      'unavailable' => 'Layanan pembayaran tidak terjangkau.',
      _ => 'Sesi pembayaran belum dapat dibuat.',
    };
  }

  static DateTime? _date(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
