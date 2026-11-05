import 'package:flutter_test/flutter_test.dart';

import 'package:panganputar_flutter/models/payment.dart';

void main() {
  test('pemetaan status Midtrans ke status internal', () {
    expect(paymentStatusFromCode('settlement'), PaymentStatus.dibayar);
    expect(paymentStatusFromCode('capture'), PaymentStatus.dibayar);
    expect(paymentStatusFromCode('pending'), PaymentStatus.menunggu);
    expect(paymentStatusFromCode('deny'), PaymentStatus.gagal);
    expect(paymentStatusFromCode('cancel'), PaymentStatus.gagal);
    expect(paymentStatusFromCode('expire'), PaymentStatus.kedaluwarsa);
    expect(paymentStatusFromCode('refund'), PaymentStatus.dikembalikan);
    expect(paymentStatusFromCode('entah'), PaymentStatus.belumDibayar);
    expect(paymentStatusFromCode(null), PaymentStatus.belumDibayar);
  });

  test('label status pembayaran lengkap', () {
    for (final s in PaymentStatus.values) {
      expect(paymentStatusLabel[s], isNotNull);
    }
  });

  test('item pembayaran ter-serialisasi untuk backend', () {
    const item = PaymentItem(
      id: 'l-1',
      nama: 'Nasi kotak',
      harga: 5000,
      jumlah: 2,
    );
    final json = item.toJson();
    expect(json['id'], 'l-1');
    expect(json['price'], 5000);
    expect(json['quantity'], 2);
  });

  test('copyWith mempertahankan nilai lain', () {
    const rec = PaymentRecord(
      orderId: 'demo-1',
      grossAmount: 10000,
      status: PaymentStatus.menunggu,
    );
    final paid = rec.copyWith(
      status: PaymentStatus.dibayar,
      metode: 'qris',
      transaksiId: 'abc',
    );
    expect(paid.status, PaymentStatus.dibayar);
    expect(paid.metode, 'qris');
    expect(paid.grossAmount, 10000);
    expect(paid.simulasi, isFalse);
  });
}
