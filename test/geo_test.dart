import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/core/geo.dart';

void main() {
  test('haversine: dua titik identik jarak nol', () {
    final p = const GeoPoint(-6.9148, 107.6098);
    expect(haversineKm(p, p), lessThan(0.001));
  });

  test('haversine: jarak antar kecamatan Bandung masuk rentang masuk akal',
      () {
    final coblong = const GeoPoint(-6.8900, 107.6160);
    final buahbatu = const GeoPoint(-6.9560, 107.6300);
    final km = haversineKm(coblong, buahbatu);
    // Realita ± 7–9 km; batu jaring: 5–12.
    expect(km, greaterThan(5.0));
    expect(km, lessThan(12.0));
    // Simetri.
    expect(haversineKm(buahbatu, coblong), closeTo(km, 0.0001));
  });

  test('formatJarak: meter di bawah 1 km, koma Indonesia, bulat jauh', () {
    expect(formatJarak(0.4), '±400 m');
    expect(formatJarak(1.23), '±1,2 km');
    expect(formatJarak(153.6), '±154 km');
  });
}
