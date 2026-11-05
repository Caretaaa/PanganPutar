import 'package:flutter/widgets.dart';

import '../services/claim_ledger.dart';
import '../services/contracts.dart';
import '../services/demo_store.dart';
import '../services/device_identity.dart';
import '../services/provider_registry.dart';
import '../services/session.dart';
import '../services/service_holder.dart';

/// Akses cepat ke state dari Shell tanpa package tambahan.
/// Definisi tunggal di sini — jangan duplikasi per layar.

class SessionHolder extends InheritedWidget {
  final SessionState session;
  const SessionHolder({
    super.key,
    required this.session,
    required super.child,
  });

  static SessionState of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<SessionHolder>();
    assert(w != null, 'SessionHolder tidak ditemukan');
    return w!.session;
  }

  @override
  bool updateShouldNotify(SessionHolder old) => session != old.session;
}

class DemoHolder extends InheritedWidget {
  final DemoStore store;
  const DemoHolder({super.key, required this.store, required super.child});

  static DemoStore of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<DemoHolder>();
    assert(w != null, 'DemoHolder tidak ditemukan');
    return w!.store;
  }

  @override
  bool updateShouldNotify(DemoHolder old) => store != old.store;
}

/// Layanan keamanan & pembayaran tingkat aplikasi:
/// identitas perangkat, kuota harian, registry toko, dan Midtrans.
/// Extended dengan production services (auth, data, config).
class ServicesHolder extends InheritedWidget {
  final DeviceIdentity device;
  final DailyClaimLedger ledger;
  final ProviderRegistry providers;
  final PaymentGateway payments;
  final PanganAuthService auth;
  final PanganDataService data;
  final FaceVerificationGateway? face;
  final AppConfig config;
  final SessionState session;

  const ServicesHolder({
    super.key,
    required this.device,
    required this.ledger,
    required this.providers,
    required this.payments,
    required this.auth,
    required this.data,
    this.face,
    required this.config,
    required this.session,
    required super.child,
  });

  static ServicesHolder of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ServicesHolder>();
    assert(w != null, 'ServicesHolder tidak ditemukan');
    return w!;
  }

  @override
  bool updateShouldNotify(ServicesHolder old) =>
      device != old.device ||
      ledger != old.ledger ||
      providers != old.providers ||
      payments != old.payments ||
      auth != old.auth ||
      data != old.data ||
      face != old.face ||
      config != old.config ||
      session != old.session;
}
