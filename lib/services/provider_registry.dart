import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security_rules.dart';

/// Profil & status verifikasi seorang penyedia.
class ProviderProfile {
  final String providerId;
  final String namaToko;
  final String jenisUsaha;
  final String nomorUsaha;
  final String telepon;
  final String alamat;
  final String kota;
  final ProviderStatus status;
  final int skor;
  final List<String> catatan;
  final DateTime? diperbarui;

  const ProviderProfile({
    required this.providerId,
    required this.namaToko,
    required this.jenisUsaha,
    required this.nomorUsaha,
    required this.telepon,
    required this.alamat,
    required this.kota,
    required this.status,
    required this.skor,
    this.catatan = const [],
    this.diperbarui,
  });

  bool get terverifikasi => status == ProviderStatus.terverifikasi;

  Map<String, Object?> toJson() => {
    'providerId': providerId,
    'namaToko': namaToko,
    'jenisUsaha': jenisUsaha,
    'nomorUsaha': nomorUsaha,
    'telepon': telepon,
    'alamat': alamat,
    'kota': kota,
    'status': providerStatusToCode(status),
    'skor': skor,
    'catatan': catatan,
    'diperbarui': diperbarui?.toIso8601String(),
  };

  factory ProviderProfile.fromJson(Map<String, Object?> j) {
    return ProviderProfile(
      providerId: (j['providerId'] ?? '').toString(),
      namaToko: (j['namaToko'] ?? '').toString(),
      jenisUsaha: (j['jenisUsaha'] ?? '').toString(),
      nomorUsaha: (j['nomorUsaha'] ?? '').toString(),
      telepon: (j['telepon'] ?? '').toString(),
      alamat: (j['alamat'] ?? '').toString(),
      kota: (j['kota'] ?? '').toString(),
      status: providerStatusFromCode(j['status']?.toString()),
      skor: (j['skor'] is num) ? (j['skor'] as num).toInt() : 0,
      catatan: (j['catatan'] as List<Object?>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      diperbarui: DateTime.tryParse((j['diperbarui'] ?? '').toString()),
    );
  }
}

/// Registry status verifikasi toko penyedia.
///
/// Demo/offline: disimpan lokal (SharedPreferences) + data contoh.
/// Verifikasi produksi membutuhkan backend terpisah; registry ini lokal.
class ProviderRegistry extends ChangeNotifier {
  static const _key = 'pp_providers_v1';

  final Map<String, ProviderProfile> _byId = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  Iterable<ProviderProfile> get semua => _byId.values;

  ProviderProfile? profileOf(String providerId) => _byId[providerId];

  ProviderStatus statusOf(String providerId) =>
      _byId[providerId]?.status ?? ProviderStatus.belumDiajukan;

  bool isVerified(String providerId) =>
      statusOf(providerId) == ProviderStatus.terverifikasi;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<Object?>;
        for (final e in list.whereType<Map<String, Object?>>()) {
          final p = ProviderProfile.fromJson(e);
          if (p.providerId.isNotEmpty) _byId[p.providerId] = p;
        }
      } catch (_) {
        _byId.clear();
      }
    }
    if (_byId.isEmpty) {
      _seedContoh();
      await _persist();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Ajukan verifikasi toko. Mengembalikan hasil review (skor & catatan).
  Future<ProviderReview> submit(
    String providerId,
    ProviderApplication aplikasi,
  ) async {
    final review = reviewProvider(aplikasi);
    _byId[providerId] = ProviderProfile(
      providerId: providerId,
      namaToko: aplikasi.namaToko.trim(),
      jenisUsaha: aplikasi.jenisUsaha.trim(),
      nomorUsaha: aplikasi.nomorUsaha.trim(),
      telepon: aplikasi.telepon.trim(),
      alamat: aplikasi.alamat.trim(),
      kota: aplikasi.kota.trim(),
      status: review.status,
      skor: review.skor,
      catatan: review.catatan,
      diperbarui: DateTime.now(),
    );
    await _persist();
    notifyListeners();
    return review;
  }

  /// Perubahan status manual (demo admin): setujui / tolak.
  Future<void> setStatus(
    String providerId,
    ProviderStatus status, {
    List<String> catatan = const [],
  }) async {
    final lama = _byId[providerId];
    if (lama == null) return;
    _byId[providerId] = ProviderProfile(
      providerId: lama.providerId,
      namaToko: lama.namaToko,
      jenisUsaha: lama.jenisUsaha,
      nomorUsaha: lama.nomorUsaha,
      telepon: lama.telepon,
      alamat: lama.alamat,
      kota: lama.kota,
      status: status,
      skor: lama.skor,
      catatan: catatan,
      diperbarui: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> resetAll() async {
    _byId.clear();
    _seedContoh();
    await _persist();
    notifyListeners();
  }

  void _seedContoh() {
    _byId['seed-penyedia-1'] = ProviderProfile(
      providerId: 'seed-penyedia-1',
      namaToko: 'Warung Bu Sari (contoh)',
      jenisUsaha: 'Warung makan',
      nomorUsaha: '1234567890123',
      telepon: '081234567890',
      alamat: 'Jl. Contoh No. 12, Bandung',
      kota: 'Bandung',
      status: ProviderStatus.terverifikasi,
      skor: 100,
      catatan: const ['Data contoh: toko terverifikasi.'],
      diperbarui: DateTime.now(),
    );
    _byId['seed-penyedia-2'] = ProviderProfile(
      providerId: 'seed-penyedia-2',
      namaToko: 'Kebun Lembang (contoh)',
      jenisUsaha: 'Petani/kebun',
      nomorUsaha: '9876543210987',
      telepon: '081298765432',
      alamat: 'Pasar Contoh Blok B, Lembang',
      kota: 'Lembang',
      status: ProviderStatus.menungguReview,
      skor: 75,
      catatan: const ['Data contoh: menunggu review admin.'],
      diperbarui: DateTime.now(),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_byId.values.map((e) => e.toJson()).toList()),
    );
  }
}
