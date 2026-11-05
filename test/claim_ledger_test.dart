import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/core/security_rules.dart';
import 'package:panganputar_flutter/services/claim_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('pemakaian dicatat dan dibatasi kuota bawaan', () async {
    final ledger = DailyClaimLedger();
    await ledger.load('device-1');
    expect(ledger.sisaPorsi, 4);
    expect(ledger.check(4).ok, isTrue);

    await ledger.record(4);
    expect(ledger.porsiHariIni, 4);
    expect(ledger.sisaPorsi, 0);
    final r = ledger.check(1);
    expect(r.ok, isFalse);
    expect(r.reason, contains('Sisa kuota harian perangkat tinggal 0 porsi'));
  });

  test('kuota milik perangkat: perangkat lain tidak terpengaruh', () async {
    SharedPreferences.setMockInitialValues({
      'pp_claim_usage_dev-A': '${dayKey(DateTime.now())}|1|2',
    });
    final ledA = DailyClaimLedger();
    await ledA.load('dev-A');
    expect(ledA.porsiHariIni, 2);

    final ledB = DailyClaimLedger();
    await ledB.load('dev-B');
    expect(ledB.porsiHariIni, 0);
  });

  test('akun berbeda di perangkat sama berbagi kuota yang sama', () async {
    // Inti fitur anti-multi-akun: kunci penyimpanan per perangkat.
    final sesi1 = DailyClaimLedger();
    await sesi1.load('device-sama');
    await sesi1.record(3);

    final sesi2 = DailyClaimLedger();
    await sesi2.load('device-sama');
    expect(sesi2.porsiHariIni, 3);
    expect(sesi2.check(2).ok, isFalse); // sisa 1 porsi
  });

  test('data hari lama diabaikan (reset otomatis ganti hari)', () async {
    SharedPreferences.setMockInitialValues({
      'pp_claim_usage_dev-C': '2000-01-01|2|4',
    });
    final ledger = DailyClaimLedger();
    await ledger.load('dev-C');
    expect(ledger.porsiHariIni, 0);
    expect(ledger.pesananHariIni, 0);
    expect(ledger.check(4).ok, isTrue);
  });

  test('menolak pesanan ketiga walau porsi masih tersisa', () async {
    final ledger = DailyClaimLedger();
    await ledger.load('device-2');
    await ledger.record(1);
    await ledger.record(1);
    expect(ledger.sisaPesanan, 0);
    final r = ledger.check(1);
    expect(r.ok, isFalse);
    expect(r.reason, contains('Batas pesanan harian perangkat tercapai'));
  });

  test('reset demo mengosongkan kuota', () async {
    final ledger = DailyClaimLedger();
    await ledger.load('dev-D');
    await ledger.record(3);
    await ledger.resetForDemo();
    expect(ledger.porsiHariIni, 0);
    expect(ledger.pesananHariIni, 0);
    expect(ledger.check(4).ok, isTrue);
  });

  test('kuota bertahan setelah ledger dimuat ulang (persisten)', () async {
    final first = DailyClaimLedger();
    await first.load('device-3');
    await first.record(2);

    final second = DailyClaimLedger();
    await second.load('device-3');
    expect(second.porsiHariIni, 2);
    expect(second.pesananHariIni, 1);
  });
}
