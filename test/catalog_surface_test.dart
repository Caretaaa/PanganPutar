import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panganputar_flutter/core/theme.dart';
import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/widgets/listing_tile.dart';

// Optional, reproducible Flutter-rendered captures; not browser/device evidence.
// flutter test test/catalog_surface_test.dart --update-goldens
//   --dart-define=UI_CAPTURE_DIR=/absolute/directory
void main() {
  setUpAll(() async {
    final loader = FontLoader('Montserrat');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Montserrat-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final width in [360.0, 600.0, 840.0]) {
    for (final dark in [false, true]) {
      testWidgets('catalog $width ${dark ? 'dark' : 'light'} at 1.3x', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var orders = 0;
        var saves = 0;
        final item = sampleListings().first;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 960),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ListingTile(
                    item: item,
                    storeName: 'Toko contoh • Bandung',
                    verified: true,
                    distanceKm: 1.24,
                    onTap: () => orders++,
                    onPesan: () => orders++,
                    onToggleSave: () => saves++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            AssetImage(item.imageAsset!),
            tester.element(find.byType(ListingTile)),
          );
        });
        await tester.pumpAndSettle();
        const captureDir = String.fromEnvironment('UI_CAPTURE_DIR');
        if (captureDir.isNotEmpty) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              Uri.file(
                '$captureDir/catalog-${width.toInt()}-${dark ? 'dark' : 'light'}.png',
              ),
            ),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Pesan'));
        await tester.tap(find.byTooltip('Simpan'));
        expect(orders, 1);
        expect(saves, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
