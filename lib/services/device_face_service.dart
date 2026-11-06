import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'contracts.dart';
import 'firebase_face_service.dart';
import 'tflite_interpreter.dart';

/// On-device face embedding with a TFLite model (MobileFaceNet),
/// then a Cloud Function does the 1:N match + weekly quota.
///
/// **The raw image never leaves the device** — only the embedding is
/// uploaded, and the server stores the credential template, not a photo.
///
/// **Honest limits of this build:** there is no certified liveness check,
/// and the client embedding is only as trustworthy as the client. Buying a
/// certified liveness/EVAL provider is recommended before claiming identity
/// grade verification.
class DeviceFaceVerificationService implements FaceVerificationGateway {
  DeviceFaceVerificationService._();
  static final instance = DeviceFaceVerificationService._();

  FaceDetector? _detector;
  FaceEmbeddingEngine get _engine => _engineRef ??= FaceEmbeddingEngine();
  FaceEmbeddingEngine? _engineRef;

  FaceDetector get _det =>
      _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableClassification: false,
          enableTracking: false,
          minFaceSize: 0.15,
        ),
      );

  @override
  Future<FaceVerificationResult> verifyFace(Uint8List imageBytes) async {
    if (kIsWeb) {
      throw const FaceVerificationFlowException(
        'Verifikasi wajah di browser tidak didukung build ini. '
        'Gunakan aplikasi Android.',
      );
    }
    if (imageBytes.isEmpty) {
      throw const FaceVerificationFlowException('Foto selfie kosong.');
    }
    if (imageBytes.length > 6 * 1024 * 1024) {
      throw const FaceVerificationFlowException(
        'Foto terlalu besar. Ambil ulang dengan resolusi lebih rendah.',
      );
    }

    final faceRect = await _detectSingleFace(imageBytes);
    final embedding = await _engine.embed(imageBytes, faceRect);
    if (embedding.isEmpty) {
      throw const FaceVerificationFlowException(
        'Selfie belum dapat diproses. Coba lagi.',
      );
    }

    // Upload only the vector; no photo, no raw pixels.
    return FirebaseFaceVerificationService.instance.verifyEmbedding(
      embedding,
    );
  }

  /// Exactly one face, reasonably sized in the frame.
  Future<Rect> _detectSingleFace(Uint8List imageBytes) async {
    final dir = await Directory.systemTemp.createTemp();
    final path =
        '${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(imageBytes, flush: true);
    try {
      final faces = await _det.processImage(InputImage.fromFilePath(path));
      if (faces.isEmpty) {
        throw const FaceVerificationFlowException(
          'Tidak ada wajah terdeteksi. Coba selfie di tempat lebih terang.',
        );
      }
      if (faces.length > 1) {
        throw const FaceVerificationFlowException(
          'Terdapat lebih dari satu wajah. Selfie sendiri saja.',
        );
      }
      final face = faces.first;
      // Very small or blurred faces give unreliable embeddings.
      final size = face.boundingBox.width;
      if (size < 60) {
        throw const FaceVerificationFlowException(
          'Wajah terlalu kecil. Dekatkan kamera ke wajah.',
        );
      }
      return face.boundingBox;
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
      try {
        await dir.delete();
      } catch (_) {}
    }
  }

  @override
  Future<FaceVerificationResult?> fetchStatus() =>
      FirebaseFaceVerificationService.instance.fetchStatus();

  void dispose() {
    _detector?.close();
    _detector = null;
    _engineRef?.dispose();
    _engineRef = null;
  }
}
// dispose() is app-shutdown hygiene only; it is not part of the
// FaceVerificationGateway contract.

class FaceVerificationFlowException implements Exception {
  final String message;
  const FaceVerificationFlowException(this.message);
  @override
  String toString() => message;
}
