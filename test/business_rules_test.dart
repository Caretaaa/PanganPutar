import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/core/business_rules.dart';

void main() {
  test('stok negatif ditolak', () {
    final r = canOrder(
      status: 'tersedia',
      available: -1,
      pickupEnd: DateTime.now().add(const Duration(hours: 1)),
      quantity: 1,
    );
    expect(r.ok, isFalse);
  });

  test('pesanan melebihi stok ditolak, sama dengan stok diterima', () {
    final future = DateTime.now().add(const Duration(hours: 2));
    expect(
      canOrder(
        status: 'tersedia',
        available: 3,
        pickupEnd: future,
        quantity: 4,
      ).ok,
      isFalse,
    );
    expect(
      canOrder(
        status: 'tersedia',
        available: 3,
        pickupEnd: future,
        quantity: 3,
      ).ok,
      isTrue,
    );
  });

  test('kedaluwarsa tidak dapat dipesan', () {
    final past = DateTime.now().subtract(const Duration(hours: 1));
    expect(isExpired(past), isTrue);
    final r = canOrder(
      status: 'tersedia',
      available: 5,
      pickupEnd: past,
      quantity: 1,
    );
    expect(r.ok, isFalse);
  });

  test('transisi status resmi', () {
    expect(
      canTransition(OrderStatus.menunggu, OrderStatus.dikonfirmasi),
      isTrue,
    );
    expect(canTransition(OrderStatus.menunggu, OrderStatus.selesai), isFalse);
    expect(
      canTransition(OrderStatus.siapDiambil, OrderStatus.selesai),
      isTrue,
    );
  });

  test('estimasi dampak memakai rumus terdokumentasi', () {
    final e = estimateImpact(10);
    expect(e.porsi, 10);
    expect(e.estimasiKg, closeTo(4.0, 0.001));
    expect(e.estimasiCo2eKg, closeTo(10.0, 0.001));
  });
}
