// Model pembayaran Midtrans — murni, tanpa dependensi Flutter.

enum PaymentStatus {
  tidakPerlu, // pesanan gratis
  belumDibayar,
  menunggu, // pending (mis. VA/QRIS belum dibayar)
  dibayar, // settlement / capture
  gagal, // deny / cancel / failure
  kedaluwarsa, // expire
  dikembalikan, // refund
}

const Map<PaymentStatus, String> paymentStatusLabel = {
  PaymentStatus.tidakPerlu: 'Tanpa pembayaran',
  PaymentStatus.belumDibayar: 'Belum dibayar',
  PaymentStatus.menunggu: 'Menunggu pembayaran',
  PaymentStatus.dibayar: 'Lunas',
  PaymentStatus.gagal: 'Gagal',
  PaymentStatus.kedaluwarsa: 'Kedaluwarsa',
  PaymentStatus.dikembalikan: 'Dikembalikan',
};

/// Petakan status mentah Midtrans / backend ke [PaymentStatus].
PaymentStatus paymentStatusFromCode(String? code) {
  switch ((code ?? '').toLowerCase()) {
    case 'settlement':
    case 'capture':
    case 'dibayar':
    case 'lunas':
      return PaymentStatus.dibayar;
    case 'pending':
    case 'menunggu':
      return PaymentStatus.menunggu;
    case 'deny':
    case 'cancel':
    case 'cancelled':
    case 'failure':
    case 'gagal':
      return PaymentStatus.gagal;
    case 'expire':
    case 'expired':
    case 'kedaluwarsa':
      return PaymentStatus.kedaluwarsa;
    case 'refund':
    case 'partial_refund':
    case 'dikembalikan':
      return PaymentStatus.dikembalikan;
    default:
      return PaymentStatus.belumDibayar;
  }
}

class PaymentRecord {
  final String orderId;
  final int grossAmount;
  final PaymentStatus status;
  final String? metode; // qris | gopay | ovo | dana | va_bca | ...
  final String? transaksiId; // transaction_id Midtrans
  final DateTime? dibayarPada;
  final bool simulasi; // true = mode demo tanpa uang nyata

  const PaymentRecord({
    required this.orderId,
    required this.grossAmount,
    required this.status,
    this.metode,
    this.transaksiId,
    this.dibayarPada,
    this.simulasi = false,
  });

  PaymentRecord copyWith({
    PaymentStatus? status,
    String? metode,
    String? transaksiId,
    DateTime? dibayarPada,
  }) {
    return PaymentRecord(
      orderId: orderId,
      grossAmount: grossAmount,
      status: status ?? this.status,
      metode: metode ?? this.metode,
      transaksiId: transaksiId ?? this.transaksiId,
      dibayarPada: dibayarPada ?? this.dibayarPada,
      simulasi: simulasi,
    );
  }
}

/// Item yang dikirim ke backend untuk membuat transaksi Snap.
class PaymentItem {
  final String id;
  final String nama;
  final int harga;
  final int jumlah;

  const PaymentItem({
    required this.id,
    required this.nama,
    required this.harga,
    required this.jumlah,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': nama,
    'price': harga,
    'quantity': jumlah,
  };
}

/// Sesi Snap: token dari backend (server key tidak pernah ada di aplikasi).
class SnapSession {
  final String orderId;
  final String token;
  final String redirectUrl;
  final DateTime? kedaluwarsa;
  final bool simulasi;

  const SnapSession({
    required this.orderId,
    required this.token,
    required this.redirectUrl,
    this.kedaluwarsa,
    this.simulasi = false,
  });
}
