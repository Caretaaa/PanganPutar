import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/sample_data.dart';
import '../models/models.dart';

// Klien API ke backend Next.js PanganPutar.
// - Android emulator menjangkau host via 10.0.2.2
// - iOS simulator / desktop via localhost
// Fallback contoh hanya untuk mode demo. Respons kosong dari server tetap
// kosong; data contoh tidak pernah disamarkan sebagai penawaran produksi.
class CatalogUnavailableException implements Exception {
  const CatalogUnavailableException();
}

class ApiConfig {
  static String get defaultBase {
    // Bisa dioverride dengan --dart-define=PANGANPUTAR_API_BASE=...
    const fromEnv = String.fromEnvironment(
      'PANGANPUTAR_API_BASE',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://10.0.2.2:3000';
  }
}

class ListingFilter {
  final String q;
  final String kategori;
  final String kota;
  final bool gratisSaja;
  const ListingFilter({
    this.q = '',
    this.kategori = '',
    this.kota = '',
    this.gratisSaja = false,
  });
}

class PanganPutarApi {
  final String base;
  final http.Client _client;
  final bool allowSampleFallback;
  PanganPutarApi({
    String? base,
    http.Client? client,
    this.allowSampleFallback = true,
  })
    : base = (base ?? ApiConfig.defaultBase).replaceAll(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  Future<bool> isBackendReachable() async {
    try {
      final r = await _client
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<FoodListing>> fetchListings([ListingFilter? filter]) async {
    final f = filter ?? const ListingFilter();
    final qs = <String, String>{'limit': '48'};
    if (f.q.trim().isNotEmpty) qs['q'] = f.q.trim();
    if (f.kategori.isNotEmpty) qs['kategori'] = f.kategori;
    if (f.kota.trim().isNotEmpty) qs['kota'] = f.kota.trim();
    if (f.gratisSaja) qs['gratisSaja'] = '1';
    try {
      final uri = Uri.parse('$base/api/listings').replace(queryParameters: qs);
      final r = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final list = (body['data'] as List<Object?>? ?? []);
      final parsed = list
          .whereType<Map<String, Object?>>()
          .map(FoodListing.fromJson)
          .toList();
      return parsed;
    } catch (_) {
      if (!allowSampleFallback) {
        throw const CatalogUnavailableException();
      }
      return _offlineFiltered(f);
    }
  }

  List<FoodListing> _offlineFiltered(ListingFilter f) {
    return sampleListings().where((e) {
      if (f.q.trim().isNotEmpty &&
          !e.title.toLowerCase().contains(f.q.trim().toLowerCase())) {
        return false;
      }
      if (f.kategori.isNotEmpty && e.category != f.kategori) return false;
      if (f.kota.trim().isNotEmpty &&
          !e.city.toLowerCase().contains(f.kota.trim().toLowerCase())) {
        return false;
      }
      if (f.gratisSaja && !e.isFree && e.priceRupiah != 0) return false;
      return true;
    }).toList();
  }

  Future<FoodListing?> fetchDetail(String id) async {
    try {
      final r = await _client
          .get(Uri.parse('$base/api/listings/$id'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 404) return null;
      if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
      final body = jsonDecode(r.body) as Map<String, Object?>;
      return FoodListing.fromJson(body['data'] as Map<String, Object?>);
    } catch (_) {
      if (!allowSampleFallback) {
        throw const CatalogUnavailableException();
      }
      try {
        return sampleListings().firstWhere((e) => e.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<ImpactSummary?> fetchImpact() async {
    try {
      final r = await _client
          .get(Uri.parse('$base/api/impact'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
      return ImpactSummary.fromJson(jsonDecode(r.body) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }
}
