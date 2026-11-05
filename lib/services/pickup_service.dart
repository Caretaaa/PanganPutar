import '../core/pickup_rules.dart';
import '../models/payment.dart';
import 'demo_store.dart';

/// Hasil satu operasi pemindaian QR — siap ditampilkan ke pengguna.
class PickupOutcome {
  /// Berhasil (pesanan diproses) atau ditolak.
  final bool sukses;

  /// Pesan utama (alasan penolakan, atau ringkasan keberhasilan).
  final String pesan;

  /// Catatan tambahan saat berhasil (mis. mode demo, dipindai dari kode).
  final String? peringatan;

  /// Pesanan yang diproses (saat berhasil).
  final DemoOrder? order;

  const PickupOutcome._(this.sukses, this.pesan, {this.peringatan, this.order});

  factory PickupOutcome.gagal(String pesan) => PickupOutcome._(false, pesan);

  factory PickupOutcome.sukses(
    DemoOrder order,
    String pesan, {
    String? peringatan,
  }) => PickupOutcome._(true, pesan, peringatan: peringatan, order: order);
}

/// Jembatan antara hasil pindai QR dan [DemoStore].
///
/// Alur yang didukung:
/// 1. [prosesScanTiketPembeli] — penyedia memindai tiket QR pembeli; pesanan
///    ditandai selesai dan tercatat "terverifikasi QR".
/// 2. [prosesScanQrToko] — pembeli memindai QR toko; tercatat tiba di lokasi.
///
/// Di produksi, pemindaian tiket harus mengirim bukti ke backend (orderId +
/// token bertanda tangan) dan backend yang mengubah status. Versi demo ini
/// memvalidasi terhadap data lokal dengan aturan yang sama.
class PickupService {
  final DemoStore store;
  PickupService(this.store);

  /// Penyedia memindai tiket pembeli → tandai pesanan selesai.
  ///
  /// [scannerProviderId] = ID toko yang sedang memindai (pemegang hak).
  /// [operatorDemo] = izinkan menangani pesanan toko contoh mana pun dalam
  /// DEMO satu perangkat (satu ponsel memainkan pembeli sekaligus operator
  /// toko contoh). Produksi: biarkan `false`.
  PickupOutcome prosesScanTiketPembeli({
    required String raw,
    required String scannerProviderId,
    bool operatorDemo = false,
    DateTime? now,
  }) {
    final waktu = now ?? DateTime.now();

    PickupTicket? tiket = PickupTicket.parse(raw);
    DemoOrder? order;
    var viaKode = false;

    if (tiket != null) {
      order = store.orderById(tiket.orderId);
    } else {
      // Toleransi: barcode berisi kode pengambilan telanjang (mis. cetak
      // struk), bukan tautan QR. Cari berdasarkan kode.
      final kode = raw.trim().toUpperCase();
      if (kode.isNotEmpty && kode.length <= 32) {
        order = store.orderByPickupCode(kode);
        if (order != null) {
          viaKode = true;
          tiket = PickupTicket(
            orderId: order.id,
            kode: order.pickupCode,
            providerId: order.listing.providerId,
          );
        }
      }
    }

    if (tiket == null || order == null) {
      return PickupOutcome.gagal(
        'Bukan QR tiket PanganPutar. Minta pembeli membuka Pesanan → '
        'Tampilkan QR, lalu pindai ulang.',
      );
    }

    // Demo satu perangkat: pemindaian diproses sebagai operator toko pada
    // tiket. Produksi tetap menolak bila bukan pesanan toko pemindai.
    final idPemindai = operatorDemo
        ? order.listing.providerId
        : scannerProviderId;

    final check = checkPickupTicket(
      tiket: tiket,
      scannerProviderId: idPemindai,
      orderStatus: order.status,
      kodePesanan: order.pickupCode,
      orderProviderId: order.listing.providerId,
      perluBayar: order.perluBayar,
      pembayaranLunas: order.paymentStatus == PaymentStatus.dibayar,
      pickupEnd: order.listing.pickupEnd,
      now: waktu,
    );
    if (!check.ok) return PickupOutcome.gagal(check.alasan!);

    store.markPickedUp(order.id);

    final catatan = <String>[
      if (operatorDemo && order.listing.providerId != scannerProviderId)
        'Mode demo: diproses sebagai operator toko pemilik tiket.',
      if (viaKode) 'Dipindai dari kode pengambilan (tanpa QR).',
      if (check.peringatan != null) check.peringatan!,
    ];
    return PickupOutcome.sukses(
      order,
      'Pengambilan pesanan ${order.pickupCode} terverifikasi: '
      '${order.listing.title} × ${order.quantity}.',
      peringatan: catatan.isEmpty ? null : catatan.join(' '),
    );
  }

  /// Pembeli memindai QR toko saat tiba di lokasi.
  PickupOutcome prosesScanQrToko({
    required String raw,
    required DemoOrder order,
    required bool tokoTerverifikasi,
  }) {
    if (order.status == 'selesai') {
      return PickupOutcome.gagal('Pesanan ini sudah selesai — tidak perlu pindai ulang.');
    }
    if (order.status == 'dibatalkan') {
      return PickupOutcome.gagal('Pesanan ini sudah dibatalkan.');
    }

    final toko = StoreQr.parse(raw);
    if (toko == null) {
      return PickupOutcome.gagal(
        'QR ini bukan QR toko PanganPutar. Minta penyedia menunjukkan QR '
        'toko aslinya di kasir/pintu.',
      );
    }

    final check = checkStoreQr(
      toko: toko,
      orderProviderId: order.listing.providerId,
      tokoTerverifikasi: tokoTerverifikasi,
    );
    if (!check.ok) return PickupOutcome.gagal(check.alasan!);

    store.markArrivalVerified(order.id);
    return PickupOutcome.sukses(
      order,
      'Kamu berada di toko yang benar sesuai pesananmu. Tunjukkan QR '
      'pesanan ke penyedia untuk menyelesaikan pengambilan.',
      peringatan: check.peringatan,
    );
  }
}
