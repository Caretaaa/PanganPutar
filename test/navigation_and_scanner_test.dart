import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/core/theme_controller.dart';
import 'package:panganputar_flutter/screens/landing_screen.dart';
import 'package:panganputar_flutter/screens/scan_screen.dart';
import 'package:panganputar_flutter/services/session.dart';
import 'package:panganputar_flutter/widgets/app_holders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kamera QR didukung di browser dan platform kamera native', () {
    expect(
      supportsScannerCamera(isWeb: true, platform: TargetPlatform.linux),
      isTrue,
    );
    expect(
      supportsScannerCamera(isWeb: false, platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      supportsScannerCamera(isWeb: false, platform: TargetPlatform.linux),
      isFalse,
    );
  });

  Future<SessionState> showLanding(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionState();
    await session.load();
    final themeController = ThemeController();
    var entered = false;
    await tester.pumpWidget(
      SessionHolder(
        session: session,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return entered
                  ? const Scaffold(body: Text('Halaman utama'))
                  : LandingScreen(
                      themeController: themeController,
                      onEnter: (tab) {
                        expect(tab, 0);
                        setState(() => entered = true);
                      },
                    );
            },
          ),
        ),
      ),
    );
    return session;
  }

  testWidgets('login penerima membuka halaman utama setelah nama disimpan', (
    tester,
  ) async {
    final session = await showLanding(tester);

    await tester.tap(find.text('Masuk demo dengan nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sari Rahayu');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(session.role, 'penerima');
    expect(find.text('Halaman utama'), findsOneWidget);
    expect(find.text('Sudah masuk'), findsNothing);
  });

  testWidgets('alur jadi penyedia memilih peran dan membuka halaman utama', (
    tester,
  ) async {
    final session = await showLanding(tester);

    await tester.tap(find.text('Jadi penyedia'));
    await tester.pumpAndSettle();
    final loginButton = find.widgetWithText(FilledButton, 'Masuk dengan nama');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final roleButton = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(roleButton.selected, {'penyedia'});

    await tester.enterText(find.byType(TextField), 'Toko Sari');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(session.role, 'penyedia');
    expect(find.text('Halaman utama'), findsOneWidget);
    expect(find.text('Sudah masuk'), findsNothing);
  });
}
