import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panganputar_flutter/core/adaptive.dart';
import 'package:panganputar_flutter/core/theme.dart';
import 'package:panganputar_flutter/core/theme_controller.dart';
import 'package:panganputar_flutter/data/sample_data.dart';
import 'package:panganputar_flutter/screens/account_screen.dart';
import 'package:panganputar_flutter/screens/detail_screen.dart';
import 'package:panganputar_flutter/screens/explore_screen.dart';
import 'package:panganputar_flutter/screens/landing_screen.dart';
import 'package:panganputar_flutter/screens/login_screen.dart';
import 'package:panganputar_flutter/screens/merchant_join_screen.dart';
import 'package:panganputar_flutter/screens/orders_screen.dart';
import 'package:panganputar_flutter/screens/payment_screen.dart';
import 'package:panganputar_flutter/screens/provider_screen.dart';
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
import 'package:panganputar_flutter/widgets/widgets.dart';

class _SurfaceHarness {
  final device = DeviceIdentity();
  final ledger = DailyClaimLedger();
  final providers = ProviderRegistry();
  final session = SessionState();
  final store = DemoStore();
  final theme = ThemeController();
  final api = PanganPutarApi(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('', 404)),
  );
  final payments = MidtransPaymentService(
    base: 'http://uji.local',
    client: MockClient((_) async => http.Response('', 500)),
  );

  Future<void> prepare(String screen) async {
    await device.load();
    await ledger.load(device.deviceId!);
    await providers.load();
    if (screen == 'provider' || screen == 'orders') {
      await session.signInDemo(
        role: screen == 'provider' ? 'penyedia' : 'penerima',
        name: 'Pengguna uji',
      );
    }
    store.placeOrder(sampleListings().first, 1);
  }

  Widget page(String screen) => switch (screen) {
    'onboarding' => OnboardingScreen(onDone: () {}),
    'landing' => LandingScreen(onEnter: (_) {}, themeController: theme),
    'login' => const LoginScreen(),
    'merchant' => MerchantJoinScreen(onEnter: (_) {}),
    'detail' => DetailScreen(
      api: api,
      listingId: sampleListings().first.id,
      fallback: sampleListings().first,
    ),
    'payment' => PaymentScreen(
      order: store.myOrders.first,
      store: store,
      payments: payments,
    ),
    _ => Scaffold(
      body: AppContentFrame(
        child: switch (screen) {
          'explore' => ExploreScreen(
            api: api,
            isProduction: false,
            data: SupabaseDataService.instance,
          ),
          'account' => AccountScreen(
            session: session,
            themeController: theme,
            api: api,
          ),
          'provider' => const ProviderScreen(),
          'orders' => OrdersScreen(
            isProduction: false,
            data: SupabaseDataService.instance,
            session: session,
            auth: SupabaseAuthService.instance,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    ),
  };

  Widget wrap(Widget page, {required double scale, required bool dark}) =>
      SessionHolder(
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
              darkTheme: buildDarkTheme(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: page,
            ),
          ),
        ),
      );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final viewport in [
    (const Size(320, 740), 1.3, false),
    (const Size(375, 812), 1.0, false),
    (const Size(600, 960), 1.0, true),
    (const Size(1280, 900), 1.3, false),
    (const Size(740, 360), 1.3, false),
  ]) {
    for (final screen in [
      'onboarding',
      'landing',
      'login',
      'merchant',
      'explore',
      'account',
      'orders',
      'detail',
      'payment',
      'provider',
    ]) {
      testWidgets('$screen ${viewport.$1} scale ${viewport.$2}', (
        tester,
      ) async {
        tester.view.physicalSize = viewport.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = _SurfaceHarness();
        await tester.runAsync(() => h.prepare(screen));
        await tester.pumpWidget(
          h.wrap(h.page(screen), scale: viewport.$2, dark: viewport.$3),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -2400));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'lower page content must fit too',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('active search filters fit while keyboard reduces viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _SurfaceHarness();
    await tester.runAsync(() => h.prepare('explore'));
    await tester.pumpWidget(h.wrap(h.page('explore'), scale: 1.3, dark: false));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'nasi');
    await tester.pumpAndSettle();
    expect(find.text('Atur ulang'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Atur ulang'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final screen in ['orders', 'provider']) {
    testWidgets('$screen guest has usable sign-in even in short viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = _SurfaceHarness();
      await tester.runAsync(() async {
        await h.prepare(screen);
        await h.session.signOut();
      });
      await tester.pumpWidget(h.wrap(h.page(screen), scale: 1.3, dark: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small payment simulation retains honest label through success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _SurfaceHarness();
    await tester.runAsync(() => h.prepare('payment'));
    await tester.pumpWidget(h.wrap(h.page('payment'), scale: 1.3, dark: false));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lanjut bayar Rp5.000'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lanjut bayar Rp5.000'));
    await tester.pumpAndSettle();
    expect(find.text('MODE SIMULASI'), findsOneWidget);
    await tester.ensureVisible(find.text('Simulasikan gagal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Bayar Rp5.000'));
    await tester.tap(find.text('Bayar Rp5.000'));
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran lunas'), findsOneWidget);
    expect(find.textContaining('tanpa uang nyata'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(740, 360);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selesai'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('simulation failure and retry fit small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _SurfaceHarness();
    await tester.runAsync(() => h.prepare('payment'));
    await tester.pumpWidget(h.wrap(h.page('payment'), scale: 1.3, dark: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lanjut bayar Rp5.000'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lanjut bayar Rp5.000'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simulasikan gagal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulasikan gagal'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 240);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error retry remains reachable in short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ErrorView(
            title: 'Gagal memuat hasil',
            description: 'Data belum dapat dimuat. Coba lagi beberapa saat.',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.tap(find.text('Coba lagi'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
