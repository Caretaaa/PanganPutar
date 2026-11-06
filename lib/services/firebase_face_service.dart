import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'contracts.dart';
import 'firebase_settings.dart';

class FaceActionException implements Exception {
  final String message;
  const FaceActionException(this.message);
  @override
  String toString() => message;
}

/// Server-side face identity matching through Cloud Functions. Two paths:
/// - AWS Rekognition (image pipeline, when AWS credentials are configured).
/// - On-device embedding (1:N cosine match in Firestore) — the client computes
/// the embedding with TFLite and uploads only the vector, never the image.
/// The server stores the face template/reference, never the raw image.
class FirebaseFaceVerificationService implements FaceVerificationGateway {
  FirebaseFaceVerificationService._();
  static final instance = FirebaseFaceVerificationService._();

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    region: FirebaseBootstrap.settings.functionsRegion,
  );

  @override
  Future<FaceVerificationResult> verifyFace(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw const FaceActionException('Foto selfie kosong. Coba lagi.');
    }
    if (imageBytes.length > 6 * 1024 * 1024) {
      throw const FaceActionException(
        'Foto terlalu besar. Ambil ulang dengan resolusi lebih rendah.',
      );
    }
    try {
      final callable = _functions.httpsCallable('verifyFace');
      final res = await callable.call(<String, dynamic>{
        'imageBase64': base64Encode(imageBytes),
        'contentType': 'image/jpeg',
      });
      return _parse(res.data);
    } on FirebaseFunctionsException catch (error) {
      throw FaceActionException(_message(error));
    } on FaceActionException {
      rethrow;
    } catch (_) {
      throw const FaceActionException(
        'Verifikasi wajah tidak terjangkau. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// On-device path: upload only the embedding vector. The server performs
  /// 1:N cosine matching against stored face templates in Firestore.
  Future<FaceVerificationResult> verifyEmbedding(List<double> embedding) async {
    if (embedding.isEmpty) {
      throw const FaceActionException('Wajah belum dapat diproses. Coba lagi.');
    }
    try {
      final callable = _functions.httpsCallable('verifyFace');
      final res = await callable.call(<String, dynamic>{
        'embedding': embedding,
      });
      return _parse(res.data);
    } on FirebaseFunctionsException catch (error) {
      throw FaceActionException(_message(error));
    } on FaceActionException {
      rethrow;
    } catch (_) {
      throw const FaceActionException(
        'Verifikasi wajah tidak terjangkau. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  @override
  Future<FaceVerificationResult?> fetchStatus() async {
    try {
      final callable = _functions.httpsCallable('faceStatus');
      final res = await callable.call(<String, dynamic>{});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['faceId'] == null) return null;
      return _parse(data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated' || error.code == 'permission-denied') {
        return null;
      }
      throw FaceActionException(_message(error));
    } catch (_) {
      return null;
    }
  }

  FaceVerificationResult _parse(Object? raw) {
    if (raw is! Map) {
      throw const FaceActionException(
        'Server tidak mengembalikan hasil verifikasi wajah.',
      );
    }
    final data = Map<String, dynamic>.from(raw);
    final faceId = (data['faceId'] as String?)?.trim() ?? '';
    if (faceId.isEmpty) {
      throw FaceActionException(
        (data['message'] as String?) ??
            'Wajah belum dapat diverifikasi. Coba selfie ulang.',
      );
    }
    return FaceVerificationResult(
      faceId: faceId,
      verifiedAt:
          _date(data['verifiedAt']) ??
          _date(data['faceVerifiedAt']) ??
          DateTime.now(),
      matchScore: (data['matchScore'] as num?)?.toDouble(),
      existingFace: data['existingFace'] == true,
      weeklyPorsi: (data['weeklyPorsi'] as num?)?.toInt() ?? 0,
      weeklyPesanan: (data['weeklyPesanan'] as num?)?.toInt() ?? 0,
      maxPorsiPerWeek: (data['maxPorsiPerWeek'] as num?)?.toInt() ?? 4,
      maxPesananPerWeek: (data['maxPesananPerWeek'] as num?)?.toInt() ?? 2,
      weekKey: data['weekKey'] as String?,
    );
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
      'unauthenticated' => 'Masuk dengan Google dulu untuk verifikasi wajah.',
      'permission-denied' => 'Verifikasi wajah ditolak server.',
      'resource-exhausted' =>
        'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.',
      'unavailable' => 'Layanan verifikasi wajah tidak terjangkau.',
      'failed-precondition' =>
        'Verifikasi wajah belum dikonfigurasi di server. Hubungi pengelola.',
      _ => 'Verifikasi wajah gagal. Coba lagi.',
    };
  }

  static DateTime? _date(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
