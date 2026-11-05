// Aturan QR pengambilan PanganPutar (murni, tanpa dependensi Flutter).

import 'dart:math';
//
// Dua arah verifikasi serah-terima makanan:
// 1. TIKET PEMBELI (QR pesanan) — dipindai PENYEDIA saat menyerahkan makanan.
//    Hanya toko penerima pesanan yang berhak memindainya. Kode di dalam QR
//    harus cocok dengan kode pengambilan pesanan.
// 2. QR TOKO (dipajang di lokasi usaha) — dipindai PEMBELI saat tiba, untuk
//    memastikan dirinya berada di toko yang benar sesuai pesanannya.
//
// PENTING: seperti semua aturan klien, pemeriksaan di sini menjaga UX dan
// menangkal penyalahgunaan kasual. Produksi WAJIB memvalidasi ulang di
// backend dengan token bertanda tangan (HMAC) dan membaca status
// pesanan/pembayaran dari basis data — bukan dari isi QR (QR bisa dipalsukan).

/// Skema tautan QR PanganPutar.
const String qrScheme = 'panganputar';

/// Host/segmen tautan: tiket pengambilan pembeli.
const String qrHostAmbil = 'ambil';

/// Host/segmen tautan: QR toko penyedia.
const String qrHostToko = 'toko';

/// Versi format tautan — memudahkan rotasi format di masa depan.
const int qrVersi = 1;

/// Alfabet kode pengambilan tanpa karakter membingungkan (tanpa 0/O, 1/I/L).
const String pickupCodeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/// Kode pengambilan ACAK per pesanan, mis. `PP-7KQ2XN4F`.
///
/// Setiap pesanan mendapat kode acak baru — tidak bisa ditebak dari waktu
/// maupun urutan pemesanan, dan bekas pesanan yang sudah diambil tidak
/// berlaku lagi (lihat [checkPickupTicket]). Produksi tetap wajib memakai
/// token bertanda tangan di backend; kode ini menjaga kasus lokal/demo.
String generatePickupCode([Random? rng]) {
  final random = rng ?? Random.secure();
  var chars = '';
  for (var i = 0; i < 8; i++) {
    chars += pickupCodeAlphabet[random.nextInt(pickupCodeAlphabet.length)];
  }
  return 'PP-$chars';
}

/// Tiket pengambilan milik pembeli, menempel pada satu pesanan.
///
/// Format: `panganputar://ambil?o=<orderId>&k=<kode>&t=<providerId>&v=1`
class PickupTicket {
  final String orderId;

  /// Harus sama persis dengan `pickupCode` pesanan.
  final String kode;

  /// Toko (penyedia) penerima pesanan — pemegang hak pindai.
  final String providerId;

  const PickupTicket({
    required this.orderId,
    required this.kode,
    required this.providerId,
  });

  String encode() => Uri(
    scheme: qrScheme,
    host: qrHostAmbil,
    queryParameters: {
      'o': orderId,
      'k': kode,
      't': providerId,
      'v': '$qrVersi',
    },
  ).toString();

  /// Baca tiket dari teks QR. `null` bila bukan tiket PanganPutar yang sah.
  static PickupTicket? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != qrScheme || uri.host != qrHostAmbil) {
      return null;
    }
    final v = uri.queryParameters['v'];
    if (v != null && v != '$qrVersi') return null;
    final o = (uri.queryParameters['o'] ?? '').trim();
    final k = (uri.queryParameters['k'] ?? '').trim();
    final t = (uri.queryParameters['t'] ?? '').trim();
    if (o.isEmpty || k.isEmpty || t.isEmpty) return null;
    if (o.length > 128 || k.length > 64 || t.length > 128) return null;
    return PickupTicket(orderId: o, kode: k, providerId: t);
  }
}

/// Mode produksi: hasil pindai penyedia → token serah-terima.
///
/// Menerima:
/// - telanjang ('PP-' + hex, seperti yang digabungkan server — dibungkus QR),
/// - QR tiket lengkap `panganputar://ambil?...k=<token>&...` (viabel untuk
///   kedepan nanti agar `o` tetap diminta).
///
/// Mengembalikan '' bila format tidak dikenal — pemanggil tidak boleh
/// mengarang token; keputusan akhir tetap di server (hash).
String tokenDariPindai(String raw) {
  final r = raw.trim();
  if (r.isEmpty) return '';

  final uri = Uri.tryParse(r);
  if (uri != null && uri.scheme == 'panganputar' && uri.host == 'ambil') {
    return (uri.queryParameters['k'] ?? '').trim();
  }

  // Telanjang: berawal 'PP-' (huruf apa pun, dinormalkan ke huruf besar —
  // server juga membandingkan hash atas token huruf besar).
  final upper = r.toUpperCase();
  if (upper.startsWith('PP-') && r.length <= 40) {
    return upper;
  }
  return '';
}

/// QR toko yang dipajang di lokasi usaha (kasir/pintu/meja).
///
/// Format: `panganputar://toko?t=<providerId>&n=<nama>&v=1`
/// Tidak memuat data pribadi apa pun — hanya identitas toko.
class StoreQr {
  final String providerId;
  final String namaToko;

  const StoreQr({required this.providerId, required this.namaToko});

  String encode() => Uri(
    scheme: qrScheme,
    host: qrHostToko,
    queryParameters: {
      't': providerId,
      'n': namaToko,
      'v': '$qrVersi',
    },
  ).toString();

  /// Baca QR toko dari teks. `null` bila bukan QR toko PanganPutar yang sah.
  static StoreQr? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != qrScheme || uri.host != qrHostToko) {
      return null;
    }
    final v = uri.queryParameters['v'];
    if (v != null && v != '$qrVersi') return null;
    final t = (uri.queryParameters['t'] ?? '').trim();
    if (t.isEmpty || t.length > 128) return null;
    final n = (uri.queryParameters['n'] ?? '').trim();
    return StoreQr(providerId: t, namaToko: n.length > 80 ? n.substring(0, 80) : n);
  }
}

/// Hasil satu pemeriksaan pemindaian.
class ScanCheck {
  /// Lolos atau tidak.
  final bool ok;

  /// Alasan kegagalan (diisi hanya saat [ok] == false).
  final String? alasan;

  /// Catatan tambahan saat lolos (mis. jendela ambil sudah lewat).
  final String? peringatan;

  const ScanCheck.ok({this.peringatan}) : ok = true, alasan = null;

  const ScanCheck.gagal(String this.alasan)
    : ok = false,
      peringatan = null;
}

/// Validasi tiket pembeli dari sudut pandang toko yang memindai.
///
/// [orderStatus] `null` berarti pesanan tidak ditemukan pada perangkat ini
/// (di produksi: backend mencari pesanan dari `orderId` di tiket).
ScanCheck checkPickupTicket({
  required PickupTicket tiket,
  required String scannerProviderId,
  required String? orderStatus,
  required String? kodePesanan,
  required String? orderProviderId,
  required bool perluBayar,
  required bool pembayaranLunas,
  DateTime? pickupEnd,
  DateTime? now,
}) {
  final waktu = now ?? DateTime.now();

  if (orderStatus == null) {
    return const ScanCheck.gagal(
      'Pesanan dari tiket ini tidak ditemukan. Minta pembeli membuka '
      'Pesanan → Tampilkan QR, lalu pindai ulang.',
    );
  }
  if ((kodePesanan ?? '') != tiket.kode) {
    return const ScanCheck.gagal(
      'Kode pengambilan pada QR tidak cocok dengan pesanan.',
    );
  }
  if ((orderProviderId ?? '') != tiket.providerId) {
    return const ScanCheck.gagal(
      'Tiket tidak konsisten dengan pesanan (kemungkinan dipalsukan).',
    );
  }
  // Hak pindai: hanya toko penerima pesanan.
  if (tiket.providerId != scannerProviderId) {
    return const ScanCheck.gagal(
      'Tiket ini milik toko lain. Hanya toko penerima pesanan yang berhak '
      'memindai dan menyerahkan makanan.',
    );
  }
  if (orderStatus == 'dibatalkan') {
    return const ScanCheck.gagal(
      'Pesanan ini dibatalkan — jangan serahkan makanan.',
    );
  }
  if (orderStatus == 'selesai') {
    return const ScanCheck.gagal(
      'Pesanan sudah diambil sebelumnya. QR bekas/dobel tidak berlaku.',
    );
  }
  if (perluBayar && !pembayaranLunas) {
    return const ScanCheck.gagal(
      'Pembayaran belum lunas. Selesaikan pembayaran sebelum makanan '
      'diserahkan.',
    );
  }
  if (orderStatus == 'menunggu') {
    return const ScanCheck.gagal(
      'Pesanan belum dikonfirmasi toko. Tekan "Konfirmasi" dulu di daftar '
      'pesanan, lalu pindai ulang.',
    );
  }
  if (orderStatus != 'dikonfirmasi' && orderStatus != 'siap_diambil') {
    return ScanCheck.gagal('Status pesanan tidak dikenal ($orderStatus).');
  }

  String? peringatan;
  if (pickupEnd != null && waktu.toUtc().isAfter(pickupEnd.toUtc())) {
    peringatan =
        'Jendela pengambilan sudah berakhir — pastikan makanan masih layak '
        'sebelum diserahkan.';
  }
  return ScanCheck.ok(peringatan: peringatan);
}

/// Validasi QR toko dari sudut pandang pembeli yang memindai.
ScanCheck checkStoreQr({
  required StoreQr toko,
  required String orderProviderId,
  required bool tokoTerverifikasi,
}) {
  if (toko.providerId != orderProviderId) {
    final nama = toko.namaToko.isEmpty ? 'toko lain' : 'milik ${toko.namaToko}';
    return ScanCheck.gagal(
      'QR ini $nama — bukan toko pesananmu. Pastikan kamu berada di tempat '
      'yang benar.',
    );
  }
  if (!tokoTerverifikasi) {
    return const ScanCheck.ok(
      peringatan:
          'Kamu di toko yang benar, tetapi verifikasi toko ini masih '
          'ditinjau. Tetap cek kondisi makanan sebelum menerima.',
    );
  }
  return const ScanCheck.ok();
}
