import '../models/models.dart';
import 'sample_data.dart';

/// Filter cepat feed — implementasi murni (tanpa Flutter) supaya
/// dapat diuji langsung. UI Beranda hanya menerjemahkan input pengguna
/// ke enum ini.
enum FeedFilter { semua, gratis, berbayar, terdekat, segera }

/// Terapkan satu filter + kategori + urutan jarak.
///
/// Aturan:
/// - [FeedFilter.terdekat] membutuhkan [lokasi]; tanpa lokasi hasilnya kosong
///   (pemanggil wajib memunculkan pemilih lokasi, bukan mengarang jarak).
/// - [FeedFilter.segera] = window pengambilan bersisa ≤ 3 jam dari [now].
///
/// [jarakLuar] — jarak (km) per listing yang dihitung SERVER (RPC PostGIS,
/// mode produksi). Bila diberikan, menggantikan jarak contoh [jarakDariGe];
/// tanpa itu jarak hanya pernah ada di mode demo berlabel "contoh".
List<FoodListing> applyFeedFilter({
  required List<FoodListing> sumber,
  required FeedFilter filter,
  String? kategori,
  SampleLocation? lokasi,
  DateTime? now,
  Map<String, double>? jarakLuar,
}) {
  final kini = now ?? DateTime.now();
  double? jarak(String listingId) =>
      jarakLuar?[listingId] ??
      (lokasi == null ? null : jarakDariGe(lokasi, listingId));
  Iterable<FoodListing> hasil = sumber.where((l) {
    switch (filter) {
      case FeedFilter.semua:
        return true;
      case FeedFilter.gratis:
        return l.isFree;
      case FeedFilter.berbayar:
        return !l.isFree;
      case FeedFilter.terdekat:
        return lokasi != null && jarak(l.id) != null;
      case FeedFilter.segera:
        return l.pickupEnd.isAfter(kini) &&
            l.pickupEnd.isBefore(kini.add(const Duration(hours: 3)));
    }
  });
  if (kategori != null) {
    hasil = hasil.where((l) => l.category == kategori);
  }
  if (filter == FeedFilter.terdekat && lokasi != null) {
    final pasangan = [
      for (final l in hasil) (l, jarak(l.id) ?? double.infinity),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (l, _) in pasangan) l];
  }
  return hasil.toList();
}
