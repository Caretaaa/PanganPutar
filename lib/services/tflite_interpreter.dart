import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Wraps a TFLite face-embedding model (MobileFaceNet: input 112x112x3,
/// output 192-d, already L2-normalizable) loaded lazily from assets.
///
/// Android/iOS only — `tflite_flutter` has no web implementation.
class FaceEmbeddingEngine {
  static const int inputSize = 112;
  static const String _modelAsset = 'assets/tflite/mobilefacenet.tflite';

  Interpreter? _interpreter;
  bool _loading = false;
  Future<void>? _loadingFuture;

  bool get isReady => _interpreter != null;

  /// Throws [FaceEmbeddingException] if the model cannot be loaded or run.
  Future<List<double>> embed(Uint8List imageBytes, Rect faceRect) async {
    if (_interpreter == null) {
      try {
        await load();
      } catch (_) {
        throw const FaceEmbeddingException('Model wajah gagal dimuat.');
      }
    }
    final interpreter = _interpreter!;
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FaceEmbeddingException('Foto tidak dapat dibaca.');
    }

    // Marginal crop (25% of the box) improves embedding stability —
    // ML Kit's tight bounding box alone is too narrow for face models.
    final margin = math.max(faceRect.width, faceRect.height) * 0.25;
    final cropLeft = (faceRect.left - margin).clamp(0.0, decoded.width.toDouble());
    final cropTop = (faceRect.top - margin).clamp(0.0, decoded.height.toDouble());
    final cropRight = (faceRect.right + margin).clamp(0.0, decoded.width.toDouble());
    final cropBottom = (faceRect.bottom + margin).clamp(0.0, decoded.height.toDouble());
    final face = img.copyCrop(
      decoded,
      x: cropLeft.toInt(),
      y: cropTop.toInt(),
      width: math.max(8, (cropRight - cropLeft).toInt()),
      height: math.max(8, (cropBottom - cropTop).toInt()),
    );
    // Square-distort to 112x112: face models expect a canonical crop.
    final resized = img.copyResize(
      face,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.average,
    );

    final flat = Float32List(inputSize * inputSize * 3);
    var i = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final p = resized.getPixel(x, y);
        // [-1, 1] normalization, RGB channel order.
        flat[i++] = (p.r / 127.5) - 1.0;
        flat[i++] = (p.g / 127.5) - 1.0;
        flat[i++] = (p.b / 127.5) - 1.0;
      }
    }

    // Nested input list matching tensor [1, 112, 112, 3].
    final input = List.generate(inputSize, (y) {
      return List.generate(inputSize, (x) {
        final base = (y * inputSize + x) * 3;
        return <double>[flat[base], flat[base + 1], flat[base + 2]];
      });
    });
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outSize = outputShape.fold<int>(1, (a, b) => a * b);
    // Shape the output buffer to match the tensor, e.g. [1][192].
    final outputShapePlan = <int>[...outputShape];
    if (outputShapePlan.isEmpty) {
      throw const FaceEmbeddingException('Model tidak punya output tensor.');
    }
    List<dynamic> buildOutput(List<int> shape) {
      if (shape.length == 1) {
        return <double>[...List<double>.filled(shape[0], 0.0)];
      }
      return [
        for (var i = 0; i < shape[0]; i++) buildOutput(shape.sublist(1)),
      ];
    }

    final output = buildOutput(outputShapePlan);
    try {
      interpreter.run(input, output);
    } catch (error, stack) {
      if (kDebugMode) debugPrint('TFLite embedding failed: $error\n$stack');
      throw const FaceEmbeddingException('Inferensi model gagal.');
    }

    final vector = flattenOutput(output).take(outSize).toList();
    var norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm <= 0) {
      throw const FaceEmbeddingException('Model mengembalikan vektor kosong.');
    }
    return [for (final v in vector) v / norm];
  }

  Future<void> load() async {
    if (_interpreter != null || _loading) return _loadingFuture;
    _loading = true;
    final future = _loadInternal();
    _loadingFuture = future;
    return future;
  }

  Future<void> _loadInternal() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    } catch (error, stack) {
      if (kDebugMode) debugPrint('TFLite model load failed: $error\n$stack');
      _loading = false;
      rethrow;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loadingFuture = null;
  }
}

class FaceEmbeddingException implements Exception {
  final String message;
  const FaceEmbeddingException(this.message);
  @override
  String toString() => message;
}

/// Recursively flattens a nested output buffer into a flat list of numbers.
List<double> flattenOutput(Object output) {
  final result = <double>[];
  void visit(Object node) {
    if (node is num) {
      result.add(node.toDouble());
    } else if (node is List) {
      for (final child in node) {
        visit(child as Object);
      }
    }
  }

  visit(output);
  return result;
}
