// Aturan bisnis murni PanganPutar (port dari lib/business/rules.ts di web).
// Sengaja tanpa dependensi Flutter agar mudah diuji unit.

enum OrderStatus {
  menunggu,
  dikonfirmasi,
  siapDiambil,
  selesai,
  dibatalkan,
}

OrderStatus orderStatusFromString(String s) {
  switch (s) {
    case 'dikonfirmasi':
      return OrderStatus.dikonfirmasi;
    case 'siap_diambil':
      return OrderStatus.siapDiambil;
    case 'selesai':
      return OrderStatus.selesai;
    case 'dibatalkan':
      return OrderStatus.dibatalkan;
    case 'menunggu':
    default:
      return OrderStatus.menunggu;
  }
}

String orderStatusToString(OrderStatus s) {
  switch (s) {
    case OrderStatus.dikonfirmasi:
      return 'dikonfirmasi';
    case OrderStatus.siapDiambil:
      return 'siap_diambil';
    case OrderStatus.selesai:
      return 'selesai';
    case OrderStatus.dibatalkan:
      return 'dibatalkan';
    case OrderStatus.menunggu:
      return 'menunggu';
  }
}

bool isExpired(DateTime pickupEnd, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toUtc();
  return !pickupEnd.toUtc().isAfter(current);
}

class OrderCheck {
  final bool ok;
  final String? reason;
  const OrderCheck.ok() : ok = true, reason = null;
  const OrderCheck.fail(this.reason) : ok = false;
}

OrderCheck canOrder({
  required String status,
  required int available,
  required DateTime pickupEnd,
  required int quantity,
  DateTime? now,
}) {
  if (quantity <= 0) return const OrderCheck.fail('Jumlah harus minimal 1.');
  if (status != 'tersedia') {
    return const OrderCheck.fail('Penawaran tidak tersedia.');
  }
  if (isExpired(pickupEnd, now: now)) {
    return const OrderCheck.fail('Penawaran sudah melewati batas pengambilan.');
  }
  if (available < 0) return const OrderCheck.fail('Stok tidak valid.');
  if (quantity > available) {
    return const OrderCheck.fail('Pesanan melebihi stok tersedia.');
  }
  return const OrderCheck.ok();
}

const Map<OrderStatus, List<OrderStatus>> allowedTransitions = {
  OrderStatus.menunggu: [OrderStatus.dikonfirmasi, OrderStatus.dibatalkan],
  OrderStatus.dikonfirmasi: [OrderStatus.siapDiambil, OrderStatus.dibatalkan],
  OrderStatus.siapDiambil: [OrderStatus.selesai, OrderStatus.dibatalkan],
  OrderStatus.selesai: [],
  OrderStatus.dibatalkan: [],
};

bool canTransition(OrderStatus from, OrderStatus to) {
  return allowedTransitions[from]?.contains(to) ?? false;
}

bool canCancelByBuyer(OrderStatus status, DateTime pickupEnd, {DateTime? now}) {
  if (status != OrderStatus.menunggu && status != OrderStatus.dikonfirmasi) {
    return false;
  }
  return !isExpired(pickupEnd, now: now);
}

// Estimasi dampak — rumus sama dengan web, selalu berlabel estimasi.
class ImpactAssumptions {
  static const double kgPerPorsi = 0.4;
  static const double co2ePerKg = 2.5;
  static const String sumber =
      'Asumsi internal PanganPutar: 0,4 kg/porsi; 2,5 kg CO2e/kg sampah makanan (kisaran literatur FAO/IPCC). Angka bersifat estimasi.';
}

class ImpactEstimate {
  final int porsi;
  final double estimasiKg;
  final double estimasiCo2eKg;
  const ImpactEstimate(this.porsi, this.estimasiKg, this.estimasiCo2eKg);
}

ImpactEstimate estimateImpact(int servedPortions) {
  final safe = servedPortions < 0 ? 0 : servedPortions;
  final kg = safe * ImpactAssumptions.kgPerPorsi;
  return ImpactEstimate(safe, kg, kg * ImpactAssumptions.co2ePerKg);
}
