// Aturan keamanan & anti-penyalahgunaan PanganPutar.
// Murni tanpa dependensi Flutter agar mudah diuji unit (lihat test/).
//
// PENTING: semua aturan di file ini ditegakkan di client untuk UX, tetapi
// WAJIB dicek ulang di backend saat produksi (klien bisa dimodifikasi).
// Kontrak backend & header perangkat didokumentasikan di README.md.

import '../models/models.dart';
import 'business_rules.dart';

/// ---------- 1. Batas ambil makanan per hari (per perangkat) ----------

/// Kuota harian bawaan. Dihitung PER PERANGKAT, bukan per akun, agar satu
/// orang tidak bisa membuat banyak akun untuk mengambil jatah berkali-kali.
class DailyClaimLimits {
  static const int defaultMaxPorsi = 4;
  static const int defaultMaxPesanan = 2;

  final int maxPorsiPerHari;
  final int maxPesananPerHari;

  const DailyClaimLimits({
    this.maxPorsiPerHari = defaultMaxPorsi,
    this.maxPesananPerHari = defaultMaxPesanan,
  });
}

/// Kunci hari lokal (yyyy-mm-dd). Kuota direset otomatis saat ganti hari.
String dayKey(DateTime waktu) {
  final l = waktu.toLocal();
  final bulan = l.month.toString().padLeft(2, '0');
  final hari = l.day.toString().padLeft(2, '0');
  return '${l.year}-$bulan-$hari';
}

/// Pemakaian kuota pada satu hari.
class DailyUsage {
  final String day;
  final int pesanan;
  final int porsi;

  const DailyUsage({required this.day, this.pesanan = 0, this.porsi = 0});

  static DailyUsage empty(DateTime now) => DailyUsage(day: dayKey(now));

  /// Pemakaian yang berlaku pada hari [now]; hari lain dianggap kosong.
  DailyUsage forDay(DateTime now) {
    if (day == dayKey(now)) return this;
    return DailyUsage.empty(now);
  }
}

class ClaimDecision {
  final bool ok;
  final String? reason;
  final int sisaPorsi;
  final int sisaPesanan;

  const ClaimDecision.ok({required this.sisaPorsi, required this.sisaPesanan})
    : ok = true,
      reason = null;

  const ClaimDecision.fail(
    this.reason, {
    required this.sisaPorsi,
    required this.sisaPesanan,
  }) : ok = false;
}

/// Cek apakah [porsi] porsi masih boleh diambil hari ini oleh perangkat ini.
ClaimDecision canClaimDaily({
  required DailyUsage usage,
  required int porsi,
  int pesananDiminta = 1,
  DailyClaimLimits limits = const DailyClaimLimits(),
  DateTime? now,
}) {
  final waktu = now ?? DateTime.now();
  final u = usage.forDay(waktu);

  var sisaPorsi = limits.maxPorsiPerHari - u.porsi;
  if (sisaPorsi < 0) sisaPorsi = 0;
  var sisaPesanan = limits.maxPesananPerHari - u.pesanan;
  if (sisaPesanan < 0) sisaPesanan = 0;

  if (porsi <= 0) {
    return ClaimDecision.fail(
      'Jumlah harus minimal 1.',
      sisaPorsi: sisaPorsi,
      sisaPesanan: sisaPesanan,
    );
  }
  if (sisaPesanan < pesananDiminta) {
    return ClaimDecision.fail(
      'Batas pesanan harian perangkat tercapai '
      '(maks ${limits.maxPesananPerHari}/hari).',
      sisaPorsi: sisaPorsi,
      sisaPesanan: sisaPesanan,
    );
  }
  if (porsi > sisaPorsi) {
    return ClaimDecision.fail(
      'Sisa kuota harian perangkat tinggal $sisaPorsi porsi '
      'dari ${limits.maxPorsiPerHari}.',
      sisaPorsi: sisaPorsi,
      sisaPesanan: sisaPesanan,
    );
  }
  return ClaimDecision.ok(sisaPorsi: sisaPorsi, sisaPesanan: sisaPesanan);
}

/// ---------- 2. Validasi toko penyedia (benar-benar punya toko) ----------

enum ProviderStatus { belumDiajukan, menungguReview, terverifikasi, ditolak }

String providerStatusLabel(ProviderStatus s) => switch (s) {
  ProviderStatus.belumDiajukan => 'Belum diajukan',
  ProviderStatus.menungguReview => 'Menunggu review',
  ProviderStatus.terverifikasi => 'Terverifikasi',
  ProviderStatus.ditolak => 'Ditolak',
};

String providerStatusToCode(ProviderStatus s) => switch (s) {
  ProviderStatus.belumDiajukan => 'belum_diajukan',
  ProviderStatus.menungguReview => 'menunggu_review',
  ProviderStatus.terverifikasi => 'terverifikasi',
  ProviderStatus.ditolak => 'ditolak',
};

ProviderStatus providerStatusFromCode(String? code) {
  switch (code) {
    case 'terverifikasi':
      return ProviderStatus.terverifikasi;
    case 'menunggu_review':
      return ProviderStatus.menungguReview;
    case 'ditolak':
      return ProviderStatus.ditolak;
    default:
      return ProviderStatus.belumDiajukan;
  }
}

/// Data pengajuan verifikasi toko.
class ProviderApplication {
  final String namaToko;
  final String jenisUsaha;
  final String nomorUsaha; // NIB (13 digit) / NPWP
  final String telepon;
  final String alamat;
  final String kota;
  final bool adaFotoToko; // foto depan toko (demo: konfirmasi; produksi: unggah)
  final bool adaTitikLokasi; // titik peta toko

  const ProviderApplication({
    required this.namaToko,
    required this.jenisUsaha,
    required this.nomorUsaha,
    required this.telepon,
    required this.alamat,
    required this.kota,
    required this.adaFotoToko,
    required this.adaTitikLokasi,
  });

  Map<String, dynamic> toJson() => {
    'namaToko': namaToko,
    'jenisUsaha': jenisUsaha,
    'nomorUsaha': nomorUsaha,
    'telepon': telepon,
    'alamat': alamat,
    'kota': kota,
    'adaFotoToko': adaFotoToko,
    'adaTitikLokasi': adaTitikLokasi,
  };

  factory ProviderApplication.fromJson(Map<String, dynamic> j) {
    return ProviderApplication(
      namaToko: (j['namaToko'] ?? '').toString(),
      jenisUsaha: (j['jenisUsaha'] ?? '').toString(),
      nomorUsaha: (j['nomorUsaha'] ?? '').toString(),
      telepon: (j['telepon'] ?? '').toString(),
      alamat: (j['alamat'] ?? '').toString(),
      kota: (j['kota'] ?? '').toString(),
      adaFotoToko: j['adaFotoToko'] == true,
      adaTitikLokasi: j['adaTitikLokasi'] == true,
    );
  }
}

class ProviderValidation {
  final Map<String, String> errors;
  const ProviderValidation(this.errors);

  bool get valid => errors.isEmpty;
  String? operator [](String field) => errors[field];
}

final RegExp _hanyaDigit = RegExp(r'^\d+$');

String _digitBersih(String v) => v.replaceAll(RegExp(r'[\s+().-]'), '');

/// Validasi kelengkapan & format data toko.
/// Inilah gerbang "apakah penyedia benar-benar punya toko": identitas usaha,
/// kontak, alamat fisik, foto toko, dan titik lokasi wajib ada.
ProviderValidation validateProviderApplication(ProviderApplication a) {
  final e = <String, String>{};

  final nama = a.namaToko.trim();
  if (nama.length < 3) {
    e['namaToko'] = 'Nama toko minimal 3 karakter.';
  } else if (nama.length > 60) {
    e['namaToko'] = 'Nama toko maksimal 60 karakter.';
  }

  if (a.jenisUsaha.trim().isEmpty) {
    e['jenisUsaha'] = 'Pilih jenis usaha.';
  }

  final nomor = _digitBersih(a.nomorUsaha);
  if (!_hanyaDigit.hasMatch(nomor) || nomor.length < 13 || nomor.length > 20) {
    e['nomorUsaha'] = 'NIB/NPWP harus 13–20 digit angka (NIB = 13 digit).';
  }

  final tel = _digitBersih(a.telepon);
  if (!_hanyaDigit.hasMatch(tel) || tel.length < 9 || tel.length > 15) {
    e['telepon'] = 'Nomor telepon harus 9–15 digit.';
  }

  if (a.alamat.trim().length < 10) {
    e['alamat'] = 'Alamat toko minimal 10 karakter (jalan, nomor, patokan).';
  }

  if (a.kota.trim().length < 3) {
    e['kota'] = 'Kota/kabupaten wajib diisi.';
  }

  if (!a.adaFotoToko) {
    e['fotoToko'] = 'Foto depan toko wajib — bukti toko benar-benar ada.';
  }

  if (!a.adaTitikLokasi) {
    e['titikLokasi'] = 'Titik lokasi toko di peta wajib diisi.';
  }

  return ProviderValidation(e);
}

/// Skor bukti keberadaan toko (0–100).
int skorBuktiToko(ProviderApplication a) {
  var skor = 0;
  if (a.adaFotoToko) skor += 30;
  if (a.adaTitikLokasi) skor += 25;
  final nomor = _digitBersih(a.nomorUsaha);
  if (_hanyaDigit.hasMatch(nomor) && nomor.length >= 13 && nomor.length <= 20) {
    skor += 25;
  }
  final tel = _digitBersih(a.telepon);
  if (_hanyaDigit.hasMatch(tel) && tel.length >= 9 && tel.length <= 15) {
    skor += 10;
  }
  if (a.alamat.trim().length >= 10) skor += 10;
  return skor;
}

class ProviderReview {
  final ProviderStatus status;
  final int skor;
  final List<String> catatan;
  const ProviderReview({
    required this.status,
    required this.skor,
    required this.catatan,
  });
}

/// Tinjau pengajuan. Demo/offline: data lengkap (foto + lokasi + NIB + kontak)
/// langsung terverifikasi. Produksi: backend memverifikasi NIB ke sumber
/// resmi, mencocokkan foto/geotag, dan boleh menahan di [menungguReview].
const int _ambangTerverifikasi = 85;

ProviderReview reviewProvider(ProviderApplication a) {
  final validasi = validateProviderApplication(a);
  final skor = skorBuktiToko(a);

  if (!validasi.valid) {
    return ProviderReview(
      status: ProviderStatus.menungguReview,
      skor: skor,
      catatan: validasi.errors.values.toList(),
    );
  }
  if (skor >= _ambangTerverifikasi) {
    return ProviderReview(
      status: ProviderStatus.terverifikasi,
      skor: skor,
      catatan: const [
        'Bukti lengkap: foto toko, titik lokasi, nomor usaha, dan kontak valid.',
      ],
    );
  }
  return ProviderReview(
    status: ProviderStatus.menungguReview,
    skor: skor,
    catatan: ['Skor bukti $skor/100 — perlu verifikasi manual admin.'],
  );
}

/// ---------- 3. Daftar periksa keamanan penawaran (di layar detail) ----------

class SafetyCheck {
  final String label;
  final bool lulus;
  final bool wajib;
  final String? catatan;
  const SafetyCheck({
    required this.label,
    required this.lulus,
    required this.wajib,
    this.catatan,
  });
}

class ListingSafetyReport {
  final List<SafetyCheck> checks;
  const ListingSafetyReport(this.checks);

  bool get wajibLulus => checks.where((c) => c.wajib).every((c) => c.lulus);
  int get jumlahLulus => checks.where((c) => c.lulus).length;
  int get jumlah => checks.length;
}

ListingSafetyReport evaluateListingSafety({
  required FoodListing listing,
  required ProviderStatus providerStatus,
  DateTime? now,
}) {
  final waktu = now ?? DateTime.now();
  final alamatLengkap = listing.pickupAddress.trim().length >= 8;
  final adaSimpan = (listing.storageNote ?? '').trim().isNotEmpty;
  final adaAlergen = (listing.allergenInfo ?? '').trim().isNotEmpty;
  final belumLewat = listing.pickupEnd.toUtc().isAfter(waktu.toUtc());
  final stokWajar = listing.status == 'tersedia' && listing.quantityAvailable > 0;
  final durasiJam = listing.pickupEnd.difference(listing.pickupStart).inHours;
  final jendelaWajar = durasiJam > 0 && durasiJam <= 24;

  return ListingSafetyReport([
    SafetyCheck(
      label: 'Toko penyedia terverifikasi',
      lulus: providerStatus == ProviderStatus.terverifikasi,
      wajib: false,
      catatan: providerStatus == ProviderStatus.terverifikasi
          ? 'Identitas usaha, foto, dan lokasi toko sudah dicek.'
          : 'Status: ${providerStatusLabel(providerStatus)}.',
    ),
    SafetyCheck(
      label: 'Jendela ambil belum berakhir',
      lulus: belumLewat,
      wajib: true,
    ),
    SafetyCheck(
      label: 'Stok masih tersedia',
      lulus: stokWajar,
      wajib: true,
    ),
    SafetyCheck(
      label: 'Alamat pengambilan lengkap',
      lulus: alamatLengkap,
      wajib: true,
    ),
    SafetyCheck(
      label: 'Catatan penyimpanan ada',
      lulus: adaSimpan,
      wajib: false,
      catatan: adaSimpan
          ? null
          : 'Penyedia belum menulis cara simpan — tanyakan saat ambil.',
    ),
    SafetyCheck(
      label: 'Info alergen dicantumkan',
      lulus: adaAlergen,
      wajib: false,
      catatan: adaAlergen
          ? null
          : 'Belum ada info alergen — tanyakan bahan sebelum makan.',
    ),
    SafetyCheck(
      label: 'Durasi ambil wajar (≤ 24 jam)',
      lulus: jendelaWajar,
      wajib: false,
    ),
  ]);
}

/// ---------- 4. Gerbang pesanan gabungan ----------

class OrderGuard {
  final bool allowed;
  final List<String> blockers;
  final List<String> warnings;
  const OrderGuard({
    required this.allowed,
    required this.blockers,
    required this.warnings,
  });
}

/// Gabungan semua aturan sebelum pesanan dibuat:
/// stok & waktu (business_rules) + kuota harian perangkat + status toko.
OrderGuard guardOrder({
  required FoodListing listing,
  required int quantity,
  required ProviderStatus providerStatus,
  DailyUsage? usage,
  DailyClaimLimits limits = const DailyClaimLimits(),
  DateTime? now,
}) {
  final waktu = now ?? DateTime.now();
  final blockers = <String>[];
  final warnings = <String>[];

  final check = canOrder(
    status: listing.status,
    available: listing.quantityAvailable,
    pickupEnd: listing.pickupEnd,
    quantity: quantity,
    now: waktu,
  );
  if (!check.ok && check.reason != null) blockers.add(check.reason!);

  if (providerStatus == ProviderStatus.ditolak) {
    blockers.add(
      'Penyedia ini ditolak verifikasinya. Pesanan diblokir demi keamanan.',
    );
  }

  if (usage != null) {
    final kuota = canClaimDaily(
      usage: usage,
      porsi: quantity,
      limits: limits,
      now: waktu,
    );
    if (!kuota.ok && kuota.reason != null) blockers.add(kuota.reason!);
  }

  if (providerStatus == ProviderStatus.belumDiajukan) {
    warnings.add('Penyedia belum mengajukan verifikasi toko.');
  } else if (providerStatus == ProviderStatus.menungguReview) {
    warnings.add('Verifikasi toko penyedia masih ditinjau admin.');
  }

  return OrderGuard(
    allowed: blockers.isEmpty,
    blockers: List.unmodifiable(blockers),
    warnings: List.unmodifiable(warnings),
  );
}
