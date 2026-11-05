import '../core/geo.dart';
import '../models/models.dart';

// Data contoh untuk mode offline/demo (tanpa backend).
// Seluruh daftar ini adalah KATALOG CONTOH — dirangkum oleh badge
// "Data contoh" di antarmuka; data live diambil dari API bila tersedia.
// Nama-nama toko memakai akhiran "(contoh)" agar tidak bisa disalahartikan
// sebagai usaha nyata.

/// Waktu jadwal contoh dibangun relatif dari [DateTime.now] supaya window
/// pengambilan tetap masuk akal kapan pun dijalankan (perlu untuk countdown
/// memudar serta filter "Segera berakhir").
List<FoodListing> sampleListings() {
  final now = DateTime.now().toUtc();
  return [
    FoodListing(
      id: 'contoh-1',
      providerId: 'seed-penyedia-1',
      title: 'Nasi kotak ayam + sayur',
      imageAsset: 'assets/images/nasi-ayam.jpg',
      category: 'nasi',
      description: 'Nasi kotak lebih dari acara siang ini. Disimpan tertutup.',
      quantityTotal: 20,
      quantityAvailable: 12,
      unit: 'porsi',
      priceRupiah: 5000,
      originalPriceRupiah: 18000,
      isFree: false,
      city: 'Bandung',
      district: 'Coblong',
      pickupAddress: 'Jl. Contoh No. 12, Bandung',
      pickupNote: 'Ambil di pintu samping.',
      pickupStart: now.add(const Duration(hours: 1)),
      pickupEnd: now.add(const Duration(hours: 5)),
      storageNote: 'Simpan suhu ruang maks. 4 jam.',
      allergenInfo: 'Mengandung telur.',
      status: 'tersedia',
    ),
    FoodListing(
      id: 'contoh-2',
      providerId: 'seed-penyedia-1',
      title: 'Roti sobek cokelat (gratis)',
      imageAsset: 'assets/images/roti-cokelat.jpg',
      category: 'roti',
      description: 'Roti produksi kemarin sore, masih baik.',
      quantityTotal: 15,
      quantityAvailable: 15,
      unit: 'pcs',
      priceRupiah: 0,
      isFree: true,
      city: 'Bandung',
      district: 'Dago',
      pickupAddress: 'Jl. Contoh No. 12, Bandung',
      pickupNote: null,
      pickupStart: now.add(const Duration(hours: 1)),
      pickupEnd: now.add(const Duration(hours: 6)),
      storageNote: 'Simpan dalam wadah tertutup.',
      allergenInfo: 'Mengandung gluten, susu.',
      status: 'tersedia',
    ),
    FoodListing(
      id: 'contoh-3',
      providerId: 'seed-penyedia-2',
      title: 'Paket sayur segar petani',
      imageAsset: 'assets/images/sayur-segar.jpg',
      category: 'sayur',
      description: 'Kelebihan panen pagi ini.',
      quantityTotal: 30,
      quantityAvailable: 25,
      unit: 'kg',
      priceRupiah: 8000,
      isFree: false,
      city: 'Lembang',
      district: '',
      pickupAddress: 'Pasar Contoh Blok B, Lembang',
      pickupNote: null,
      pickupStart: now.add(const Duration(hours: 2)),
      pickupEnd: now.add(const Duration(hours: 8)),
      storageNote: 'Simpan dingin.',
      allergenInfo: null,
      status: 'tersedia',
    ),
    // Contoh "hampir habis": sisa 2 porsi.
    FoodListing(
      id: 'contoh-4',
      providerId: 'seed-penyedia-1',
      title: 'Bubur ayam terakhir 2 porsi',
      imageAsset: null,
      category: 'lauk',
      description: 'Produksi sore tinggal sebagian. Tersisa 2 porsi.',
      quantityTotal: 10,
      quantityAvailable: 2,
      unit: 'porsi',
      priceRupiah: 0,
      isFree: true,
      city: 'Bandung',
      district: 'Coblong',
      pickupAddress: 'Jl. Contoh No. 12, Bandung',
      pickupNote: null,
      pickupStart: now.add(const Duration(minutes: 30)),
      pickupEnd: now.add(const Duration(hours: 2, minutes: 30)),
      storageNote: 'Diambil langsung, tak disimpan.',
      allergenInfo: 'Mengandung gluten (kerupuk).',
      status: 'tersedia',
    ),
    // Contoh "segera berakhir": window ambil tersisa ± 80 menit.
    FoodListing(
      id: 'contoh-5',
      providerId: 'seed-penyedia-2',
      title: 'Sambal rasanesia sisa produksi',
      imageAsset: null,
      category: 'lauk',
      description: 'Sambal botol sisa produksi, kemasan tersegel.',
      quantityTotal: 12,
      quantityAvailable: 6,
      unit: 'botol',
      priceRupiah: 3000,
      originalPriceRupiah: 12000,
      isFree: false,
      city: 'Bandung',
      district: 'Lengkong',
      pickupAddress: 'Kios Contoh No. 8, Lengkong',
      pickupNote: null,
      pickupStart: now.add(const Duration(minutes: 15)),
      pickupEnd: now.add(const Duration(minutes: 80)),
      storageNote: 'Simpan dingin setelah dibuka.',
      allergenInfo: 'Tidak dijamin bebas kacang.',
      status: 'tersedia',
    ),
    FoodListing(
      id: 'contoh-6',
      providerId: 'seed-penyedia-2',
      title: 'Pisang emas sindesis',
      imageAsset: null,
      category: 'buah',
      description: 'Pisang berlebih dari piyuh kota. Pilih rapi.',
      quantityTotal: 25,
      quantityAvailable: 20,
      unit: 'sisir',
      priceRupiah: 2000,
      originalPriceRupiah: 8000,
      isFree: false,
      city: 'Bandung',
      district: 'Buahbatu',
      pickupAddress: 'Warung Contoh No. 3, Buahbatu',
      pickupNote: null,
      pickupStart: now.add(const Duration(hours: 1)),
      pickupEnd: now.add(const Duration(hours: 4)),
      storageNote: null,
      allergenInfo: null,
      status: 'tersedia',
    ),
  ];
}

/// Titik koordinat contoh per listing — untuk perhitungan jarak
/// pemilih lokasi dan filter "Dekat saya". Bagian dari data contoh.
const Map<String, GeoPoint> sampleGeo = {
  'contoh-1': GeoPoint(-6.8895, 107.6165),
  'contoh-2': GeoPoint(-6.8760, 107.6150),
  'contoh-3': GeoPoint(-6.8110, 107.6300),
  'contoh-4': GeoPoint(-6.8900, 107.6170),
  'contoh-5': GeoPoint(-6.9255, 107.6215),
  'contoh-6': GeoPoint(-6.9570, 107.6305),
};

/// Pilihan lokasi contoh untuk mode demo: pusat Bandung + kecamatan.
/// Jarak seluruhnya berasal dari data PINJAMAN contoh yang berlabel.
class SampleLocation {
  final String id;
  final String label;
  final GeoPoint point;
  const SampleLocation(this.id, this.label, this.point);
}

const sampleLocations = <SampleLocation>[
  SampleLocation('pusat', 'Kota Bandung (pusat)', GeoPoint(-6.9148, 107.6098)),
  SampleLocation('coblong', 'Kec. Coblong', GeoPoint(-6.8900, 107.6160)),
  SampleLocation('lengkong', 'Kec. Lengkong', GeoPoint(-6.9250, 107.6205)),
  SampleLocation('buahbatu', 'Kec. Buahbatu', GeoPoint(-6.9560, 107.6300)),
];

/// Jarak dari [loc] ke listing ber-ID [listingId], atau `null` bila
/// listing tidak punya koordinat contoh.
double? jarakDariGe(SampleLocation loc, String listingId) {
  final p = sampleGeo[listingId];
  if (p == null) return null;
  return haversineKm(loc.point, p);
}
