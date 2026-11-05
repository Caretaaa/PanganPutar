import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panganputar_flutter/screens/landing_screen.dart';

// Regresi bug lama: build OnboardingScreen mengembalikan OnboardingScreen lagi
// (rekursi tanpa akhir). Tes ini memastikan alur 3 langkah benar-benar jalan.
void main() {
  testWidgets('onboarding 3 langkah selesai tanpa rekursi', (tester) async {
    var selesai = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => selesai = true)),
    );

    expect(find.text('Temukan makanan berlebih'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(
      find.text('Periksa informasi sebelum memesan'),
      findsOneWidget,
    );

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Pesan, lalu ambil di toko'), findsOneWidget);

    await tester.tap(find.text('Mulai'));
    await tester.pump();
    expect(selesai, isTrue);
  });

  testWidgets('tombol Lewati langsung menyelesaikan onboarding',
      (tester) async {
    var selesai = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => selesai = true)),
    );
    await tester.tap(find.text('Lewati'));
    await tester.pump();
    expect(selesai, isTrue);
  });
}
