class FoodListing {
  final String id;
  final String providerId;
  final String title;
  final String category;
  final String? description;
  final String? imageAsset;
  final String? imageUrl;
  final int quantityTotal;
  final int quantityAvailable;
  final String unit;
  final int priceRupiah;

  /// Harga normal sebelum diturunkan (tampil dicoret di kartu). `null` bila
  /// tidak ada penurunan harga. Isi ini HANYA bila penyedia memang
  /// menyatakan harga awal — tidak dihitung/dikarang aplikasi.
  final int? originalPriceRupiah;
  final bool isFree;
  final String city;
  final String district;
  final String pickupAddress;
  final String? pickupNote;
  final DateTime pickupStart;
  final DateTime pickupEnd;
  final String? storageNote;
  final String? allergenInfo;
  final String status;

  const FoodListing({
    required this.id,
    required this.providerId,
    required this.title,
    required this.category,
    this.description,
    this.imageAsset,
    this.imageUrl,
    required this.quantityTotal,
    required this.quantityAvailable,
    required this.unit,
    required this.priceRupiah,
    this.originalPriceRupiah,
    required this.isFree,
    required this.city,
    required this.district,
    required this.pickupAddress,
    this.pickupNote,
    required this.pickupStart,
    required this.pickupEnd,
    this.storageNote,
    this.allergenInfo,
    required this.status,
  });

  int get effectivePrice => isFree ? 0 : priceRupiah;

  factory FoodListing.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(Object? v) {
      if (v == null) return DateTime.now().toUtc();
      return DateTime.parse(v.toString());
    }

    int asInt(Object? v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return FoodListing(
      id: j['id'].toString(),
      providerId: (j['providerId'] ?? j['provider_id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      category: (j['category'] ?? 'lainnya').toString(),
      description: j['description']?.toString(),
      imageUrl: (j['imageUrl'] ?? j['image_url'])?.toString(),
      quantityTotal: asInt(j['quantityTotal'] ?? j['quantity_total']),
      quantityAvailable: asInt(
        j['quantityAvailable'] ?? j['quantity_available'],
      ),
      unit: (j['unit'] ?? 'porsi').toString(),
      priceRupiah: asInt(j['priceRupiah'] ?? j['price_rupiah']),
      originalPriceRupiah: j['originalPriceRupiah'] == null &&
              j['original_price_rupiah'] == null
          ? null
          : asInt(j['originalPriceRupiah'] ?? j['original_price_rupiah']),
      isFree: j['isFree'] == true || j['is_free'] == true,
      city: (j['city'] ?? '').toString(),
      district: (j['district'] ?? '').toString(),
      pickupAddress: (j['pickupAddress'] ?? j['pickup_address'] ?? '')
          .toString(),
      pickupNote: (j['pickupNote'] ?? j['pickup_note'])?.toString(),
      pickupStart: parseDate(j['pickupStart'] ?? j['pickup_start']),
      pickupEnd: parseDate(j['pickupEnd'] ?? j['pickup_end']),
      storageNote: (j['storageNote'] ?? j['storage_note'])?.toString(),
      allergenInfo: (j['allergenInfo'] ?? j['allergen_info'])?.toString(),
      status: (j['status'] ?? 'tersedia').toString(),
    );
  }
}

class ImpactSummary {
  final int porsiTersalurkan;
  final int pesananSelesai;
  final int penyediaAktif;
  final double estimasiKg;
  final double estimasiCo2eKg;

  const ImpactSummary({
    required this.porsiTersalurkan,
    required this.pesananSelesai,
    required this.penyediaAktif,
    required this.estimasiKg,
    required this.estimasiCo2eKg,
  });

  factory ImpactSummary.fromJson(Map<String, dynamic> j) {
    final d = j['data'] is Map ? j['data'] as Map : j;
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double asDouble(Object? v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ImpactSummary(
      porsiTersalurkan: asInt(d['porsiTersalurkan']),
      pesananSelesai: asInt(d['pesananSelesai']),
      penyediaAktif: asInt(d['penyediaAktif']),
      estimasiKg: asDouble(d['estimasiKg']),
      estimasiCo2eKg: asDouble(d['estimasiCo2eKg']),
    );
  }
}
