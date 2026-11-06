import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/adaptive.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'screens/account_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/provider_screen.dart';
import 'services/api_client.dart';
import 'services/claim_ledger.dart';
import 'services/demo_store.dart';
import 'services/contracts.dart';
import 'services/device_identity.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_data_service.dart';
import 'services/device_face_service.dart';
import 'services/firebase_face_service.dart';
import 'services/firebase_payment_service.dart';
import 'services/firebase_settings.dart';
import 'services/first_run.dart';
import 'services/provider_registry.dart';
import 'services/service_holder.dart';
import 'services/session.dart';
import 'widgets/app_holders.dart';
import 'widgets/demo_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Data locale tanggal Indonesia — wajib sebelum DateFormat('id_ID') dipakai.
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi config mode (demo/production) dari --dart-define=PRODUCTION_MODE=true
  final config = AppConfig.instance;
  await config.initialize();

  // Firebase is initialized only when the build carries public config (or
  // production mode asks for it). A missing config keeps demo mode honest
  // instead of pretending a backend is connected.
  final firebaseSettings = FirebaseSettings.fromEnvironment();
  if (firebaseSettings.isConfigured || config.isProduction) {
    await FirebaseBootstrap.initialize(override: firebaseSettings);
  }
  final auth = FirebaseAuthService.instance;
  await auth.initialize();

  // Service instances
  final session = SessionState();
  final store = DemoStore();
  // Riwayat pesanan disimpan DI PERANGKAT — muat sebelum UI tampil.
  await store.load();
  final themeController = ThemeController();
  final firstRun = FirstRunStore();
  final device = DeviceIdentity();
  final ledger = DailyClaimLedger();
  final providers = ProviderRegistry();
  final data = FirebaseDataService.instance;
  final api = PanganPutarApi(allowSampleFallback: !config.isProduction);
  // Production payments go through Firebase Cloud Functions (Midtrans server
  // key lives in Secret Manager). The client can never mark an order paid.
  final payments = FirebasePaymentService.instance;
  // On-device face embedding (TFLite) on Android; the AWS Rekognition image
  // path is only available on platforms where tflite_flutter cannot run.
  final bool faceUsesDevice =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final FaceVerificationGateway face = faceUsesDevice
      ? DeviceFaceVerificationService.instance
      : FirebaseFaceVerificationService.instance;

  // Build ServicesHolder (async init) lalu jalankan app
  final holder = await ServicesHolderFactory.create(
    config: config,
    session: session,
    auth: auth,
    device: device,
    ledger: ledger,
    providers: providers,
    payments: payments,
    data: data,
    face: face,
    child: _AppRoot(
      config: config,
      session: session,
      store: store,
      themeController: themeController,
      firstRun: firstRun,
      api: api,
      data: data,
      auth: auth,
    ),
  );

  runApp(holder);
}

/// Stage alur aplikasi: loading -> onboarding -> landing -> main
enum _Stage { loading, onboarding, landing, main }

class _AppRoot extends StatefulWidget {
  final AppConfig config;
  final SessionState session;
  final DemoStore store;
  final ThemeController themeController;
  final FirstRunStore firstRun;
  final PanganPutarApi api;
  final PanganDataService data;
  final PanganAuthService auth;

  const _AppRoot({
    required this.config,
    required this.session,
    required this.store,
    required this.themeController,
    required this.firstRun,
    required this.api,
    required this.data,
    required this.auth,
  });

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  _Stage _stage = _Stage.loading;
  int _initialTab = 0;

  @override
  void initState() {
    super.initState();
    widget.themeController.load();
    _resolveStage();
  }

  Future<void> _resolveStage() async {
    await widget.session.load();
    final done = await widget.firstRun.isDone();
    if (!mounted) return;
    setState(() {
      _stage = !done
          ? _Stage.onboarding
          : widget.session.isLoggedIn
          ? _Stage.main
          : _Stage.landing;
    });
  }

  Future<void> _finishOnboarding() async {
    await widget.firstRun.markDone();
    if (!mounted) return;
    setState(() => _stage = _Stage.landing);
  }

  void _enterMain(int tab) {
    setState(() {
      _initialTab = tab;
      _stage = _Stage.main;
    });
  }

  @override
  void dispose() {
    widget.session.dispose();
    widget.themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.config,
      builder: (context, _) {
        final isProd = widget.config.isProduction;

        return SessionHolder(
          session: widget.session,
          child: DemoHolder(
            store: widget.store,
            child: ListenableBuilder(
              listenable: widget.themeController,
              builder: (context, _) {
                return MaterialApp(
                  title: 'PanganPutar',
                  debugShowCheckedModeBanner: false,
                  theme: buildLightTheme(),
                  darkTheme: buildDarkTheme(),
                  themeMode: widget.themeController.mode,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [Locale('id', 'ID')],
                  locale: const Locale('id', 'ID'),
                  home: _buildStage(isProd),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStage(bool isProd) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Stage.onboarding:
        return OnboardingScreen(onDone: _finishOnboarding);
      case _Stage.landing:
        return LandingScreen(
          onEnter: _enterMain,
          themeController: widget.themeController,
        );
      case _Stage.main:
        return _MainShell(
          isProduction: isProd,
          session: widget.session,
          themeController: widget.themeController,
          api: widget.api,
          data: widget.data,
          auth: widget.auth,
          initialIndex: _initialTab,
        );
    }
  }
}

/// Main shell yang switch antara demo API dan production data service.
class _MainShell extends StatefulWidget {
  final bool isProduction;
  final SessionState session;
  final ThemeController themeController;
  final PanganPutarApi api;
  final PanganDataService data;
  final PanganAuthService auth;
  final int initialIndex;

  const _MainShell({
    required this.isProduction,
    required this.session,
    required this.themeController,
    required this.api,
    required this.data,
    required this.auth,
    this.initialIndex = 0,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  late int _index;
  // Reparent the same pages when rail/bar changes, preserving filters, scroll,
  // and in-flight requests across rotation or window resizing.
  final _contentKey = GlobalKey(debugLabel: 'main-pages');

  static const _titles = ['Beranda', 'Jelajahi', 'Pesanan', 'Akun'];

  static const _destinations = [
    (Icons.home_outlined, Icons.home, 'Beranda'),
    (Icons.search_outlined, Icons.search, 'Jelajahi'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Pesanan'),
    (Icons.person_outline, Icons.person, 'Akun'),
  ];

  bool get _providerHome =>
      !widget.isProduction && widget.session.role == 'penyedia';

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _titles.length - 1);
    widget.session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _goTab(int i) => setState(() => _index = i);

  /// FAB hanya di Beranda, hanya untuk penyedia terverifikasi.
  Widget? _homeFab(BuildContext context) {
    final holder = ServicesHolder.of(context);
    final session = widget.session;
    final auth = widget.auth;

    // Demo: cek role demo + provider verified
    // Production: cek role Firebase; detail toko dimuat di provider screen.
    if (widget.isProduction) {
      if (!auth.isSignedIn) return const SizedBox.shrink();
      if (auth.role != 'penyedia') return const SizedBox.shrink();
    } else {
      if (session.role != 'penyedia' && session.role != 'admin') {
        return const SizedBox.shrink();
      }
      if (!holder.providers.isVerified('demo-penyedia')) {
        return const SizedBox.shrink();
      }
    }

    return FloatingActionButton.extended(
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProviderHubScreen())),
      icon: const Icon(Icons.add),
      label: const Text('Tambah penawaran'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerHome = _providerHome;
    final destinations = [
      if (providerHome)
        (Icons.storefront_outlined, Icons.storefront, 'Penyedia')
      else
        _destinations.first,
      ..._destinations.skip(1),
    ];
    final pages = [
      if (providerHome)
        const ProviderScreen()
      else
        HomeScreen(
          api: widget.api,
          session: widget.session,
          goTab: _goTab,
          isProduction: widget.isProduction,
          data: widget.data,
        ),
      ExploreScreen(
        api: widget.api,
        isProduction: widget.isProduction,
        data: widget.data,
      ),
      OrdersScreen(
        isProduction: widget.isProduction,
        data: widget.data,
        session: widget.session,
        auth: widget.auth,
      ),
      AccountScreen(
        session: widget.session,
        themeController: widget.themeController,
        api: widget.api,
        isProduction: widget.isProduction,
        data: widget.data,
        auth: widget.auth,
      ),
    ];

    final appSize = appSizeOf(MediaQuery.sizeOf(context).width);
    final rail = useNavigationRail(appSize);

    return Scaffold(
      appBar: AppBar(
        // Satu kata "Beranda" cukup di navigasi bawah; tab 0 tampil PanganPutar.
        title: Text(
          _index == 0
              ? (providerHome ? 'Area Penyedia' : 'PanganPutar')
              : _titles[_index],
        ),
        actions: [
          IconButton(
            tooltip: 'Ganti mode tampilan',
            icon: Icon(
              widget.themeController.isDark(context)
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => widget.themeController.setDark(
              !widget.themeController.isDark(context),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Banner tipis mode demo — jujur satu tempat, bisa ditutup.
          DemoBanner(active: !widget.isProduction),
          Expanded(
            flex: 9,
            child: SafeArea(
              top: false,
              child: rail
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: _goTab,
                          extended: appSize == AppSize.expanded,
                          labelType: appSize == AppSize.expanded
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          destinations: [
                            for (final d in destinations)
                              NavigationRailDestination(
                                icon: Icon(d.$1),
                                selectedIcon: Icon(d.$2),
                                label: Text(d.$3),
                              ),
                          ],
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          child: AppContentFrame(
                            key: _contentKey,
                            child: IndexedStack(index: _index, children: pages),
                          ),
                        ),
                      ],
                    )
                  : AppContentFrame(
                      key: _contentKey,
                      child: IndexedStack(index: _index, children: pages),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _index == 0 && !providerHome
          ? _homeFab(context)
          : null,
      bottomNavigationBar: rail
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _goTab,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                  ),
              ],
            ),
    );
  }
}
