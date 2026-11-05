import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/data/feed_filter.dart';
import 'package:panganputar_flutter/core/theme.dart';
import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/screens/home_screen.dart';
import 'package:panganputar_flutter/services/api_client.dart';
import 'package:panganputar_flutter/services/claim_ledger.dart';
import 'package:panganputar_flutter/services/demo_store.dart';
import 'package:panganputar_flutter/services/device_identity.dart';
import 'package:panganputar_flutter/services/midtrans.dart';
import 'package:panganputar_flutter/services/provider_registry.dart';
import 'package:panganputar_flutter/services/service_holder.dart';
import 'package:panganputar_flutter/services/session.dart';
import 'package:panganputar_flutter/services/supabase_auth_service.dart';
import 'package:panganputar_flutter/services/supabase_data_service.dart';
import 'package:panganputar_flutter/widgets/app_holders.dart';
import 'package:panganputar_flutter/widgets/listing_tile.dart';

// Tahap 2 redesign — logika murni feed + integrasi UI Beranda.
class _Harness {
  final device = DeviceIdentity();
  final ledger = DailyClaimLedger();
  final providers = ProviderRegistry();
  final api = PanganPutarApi(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('tidak ada', 404)),
  );
  final payments = MidtransPaymentService(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('tidak ada', 500)),
  );
  final session = SessionState();
  final store = DemoStore();

  Future<void> siapkan() async {
    await initializeDateFormatting('id_ID', null);
    await device.load();
    await ledger.load(device.deviceId!);
    await providers.load();
  }

  Widget bungkus(Widget child) => SessionHolder(
    session: session,
    child: DemoHolder(
      store: store,
      child: ServicesHolder(
        auth: SupabaseAuthService.instance,
        data: SupabaseDataService.instance,
        config: AppConfig.instance,
        session: session,
        device: device,
        ledger: ledger,
        providers: providers,
        payments: payments,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: child),
        ),
      ),
    ),
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(800, 2600),
    double textScale = 1,
  }) async {
    // Permukaan besar: semua contoh kartu render tanpa gulir demi asersi.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      bungkus(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: HomeScreen(
            api: api,
            session: session,
            goTab: (_) {},
            isProduction: false,
            data: SupabaseDataService.instance,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(() async {
    // Use the shipped typeface for width assertions, not test-only Ahem metrics.
    final fonts = FontLoader('Montserrat');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Montserrat-$weight.ttf'));
    }
    await fonts.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('logika murni applyFeedFilter', () {
    final coblong = sampleLocations[1];
    final sumber = sampleListings();

    test('Gratis hanya item isFree', () {
      final hasil = applyFeedFilter(
        sumber: sumber,
        filter: FeedFilter.gratis,
        lokasi: null,
      );
      expect(hasil.length, sumber.where((l) => l.isFree).length);
      expect(hasil.every((l) => l.isFree), isTrue);
    });

    test('Berbayar hanya item bermata uang', () {
      final hasil = applyFeedFilter(
        sumber: sumber,
        filter: FeedFilter.berbayar,
      );
      expect(hasil.every((l) => !l.isFree), isTrue);
    });

    test('Terdekat tanpa lokasi kosong; dengan lokasi tertata oleh jarak', () {
      expect(
        applyFeedFilter(sumber: sumber, filter: FeedFilter.terdekat),
        isEmpty,
      );
      final hasil = applyFeedFilter(
        sumber: sumber,
        filter: FeedFilter.terdekat,
        lokasi: coblong,
      );
      expect(hasil, isNotEmpty);
      // Urut: paksi acuan Coblong — Dago & Lembang di belakang.
      expect(hasil.first.id, isNot('contoh-3'));
    });

    test('Segera berakhir: window ≤ 3 jam', () {
      final hasil = applyFeedFilter(
        sumber: sumber,
        filter: FeedFilter.segera,
        now: DateTime.now(),
      );
      final batas = DateTime.now().add(const Duration(hours: 3, minutes: 1));
      for (final l in hasil) {
        expect(
          l.pickupEnd.isBefore(batas),
          isTrue,
          reason: '${l.id} harus window ≤ 3 jam',
        );
      }
      expect(hasil, isNotEmpty);
    });
  });

  group('Beranda UI', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('location prompt and selected label fit 320 at ${scale}x', (
        tester,
      ) async {
        final errors = <FlutterErrorDetails>[];
        final previousHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          previousHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousHandler);
        final h = _Harness();
        await tester.runAsync(h.siapkan);
        await h.pumpHome(tester, size: const Size(320, 740), textScale: scale);
        await tester.scrollUntilVisible(
          find.text('Pilih lokasi'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // The action itself is the prompt; no redundant, truncated status.
        expect(find.text('Lokasi belum dipilih'), findsNothing);
        expect(find.text('Pilih lokasi'), findsOneWidget);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('Pilih lokasi'))
              .didExceedMaxLines,
          isFalse,
        );
        await tester.ensureVisible(find.text('Pilih lokasi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pilih lokasi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kota Bandung (pusat)'));
        await tester.pumpAndSettle();

        final label = find.text('Kota Bandung (pusat)');
        expect(label, findsOneWidget);
        final text = tester.widget<Text>(label);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
        );
        expect(tester.getRect(label).right, lessThanOrEqualTo(300));
        expect(find.text('Pilih lokasi'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: errors.map((e) => e.toString()).join('\n'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    for (final size in [const Size(320, 740), const Size(600, 960)]) {
      testWidgets('header wraps at $size with 1.3x text', (tester) async {
        final h = _Harness();
        await tester.runAsync(h.siapkan);
        await h.pumpHome(tester, size: size, textScale: 1.3);
        expect(tester.takeException(), isNull);
        expect(find.text('Putaran kebaikan.'), findsOneWidget);
        expect(find.text('Cari makanan'), findsOneWidget);
        expect(find.text('Jadi penyedia'), findsOneWidget);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ListingTile), findsWidgets);
      });
    }

    testWidgets('filter chips: Gratis mempersempit feed, Semua balik', (
      tester,
    ) async {
      final h = _Harness();
      await tester.runAsync(h.siapkan);
      await h.pumpHome(tester);

      final semua = jumlahKartu(tester);
      expect(semua, sampleListings().length);

      await tester.tap(find.text('Gratis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final gratis = jumlahKartu(tester);
      expect(gratis, lessThan(semua));
      expect(find.text('GRATIS'), findsAtLeastNWidgets(gratis));

      await tester.tap(find.text('Semua'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(jumlahKartu(tester), semua);
    });

    testWidgets('"Terdekat" tanpa lokasi → snackbar jelas', (tester) async {
      final h = _Harness();
      await tester.runAsync(h.siapkan);
      await h.pumpHome(tester);

      await tester.tap(find.text('Terdekat'));
      await tester.pump();
      expect(
        find.text('Pilih lokasi dulu agar "Terdekat" punya acuan.'),
        findsOneWidget,
      );
    });

    testWidgets('preferensi lokasi tersimpan dipulihkan → jarak tampil', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'pp_lokasi_demo_v1': 'coblong'});
      final h = _Harness();
      await tester.runAsync(h.siapkan);
      await h.pumpHome(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Kec. Coblong'), findsOneWidget);
      await tester.tap(find.text('Terdekat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('±'), findsWidgets);
    });

    testWidgets('feed 1 kolom: kartu lebar penuh (tinggi pengikuti isi)', (
      tester,
    ) async {
      final h = _Harness();
      await tester.runAsync(h.siapkan);
      await h.pumpHome(tester);
      expect(find.byType(ListingTile), findsWidgets);
      final size = tester.getSize(find.byType(ListingTile).first);
      expect(size.width, greaterThan(400), reason: 'kartu memakai 1 kolom');
    });
  });
}

int jumlahKartu(WidgetTester tester) =>
    tester.widgetList<ListingTile>(find.byType(ListingTile)).length;
