import 'dart:math' as math;

/// Utilitas geolokasi murni — tanpa dependensi Flutter.
/// Dipakai feed "Dekat saya" berbasis data contoh yang sudah diberi label.

/// Koordinat lintang/bujur dalam derajat.
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

/// Jarak lingkaran-besar (haversine) antar dua koordinat, dalam kilometer.
/// Akurasi cukup untuk pengurutan dan teks "±x,x km" skala kota.
/// Pemakaian presisi (peta/rute) tetap wajib lewat server.
double haversineKm(GeoPoint a, GeoPoint b) {
  const r = 6371.0; // radius bumi, km
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = _sin(dLat / 2) * _sin(dLat / 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * _sin(dLng / 2) * _sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
}

double _rad(double deg) => deg * math.pi / 180.0;
double _sin(double rad) => math.sin(rad);

/// Teks jarak ramah Indonesia, mis. `±1,2 km` atau `±850 m`.
String formatJarak(double km) {
  if (km < 1.0) {
    final meter = (km * 1000).round();
    return '±$meter m';
  }
  if (km < 100.0) {
    final satu = km.toStringAsFixed(1).replaceAll('.', ',');
    return '±$satu km';
  }
  return '±${km.round()} km';
}
