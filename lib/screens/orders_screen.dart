import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../core/tokens.dart';
import '../models/payment.dart';
import '../services/demo_store.dart';
import '../services/device_identity.dart';
import '../services/contracts.dart';
import '../services/session.dart';
import '../services/service_holder.dart';
import '../widgets/app_holders.dart';
import '../widgets/async_view.dart';
import '../widgets/status_chips.dart';
import '../widgets/widgets.dart';
import 'payment_screen.dart';
import 'pickup_ticket_screen.dart';
import 'login_screen.dart';

class OrdersScreen extends StatelessWidget {
  final bool isProduction;
  final PanganDataService data;
  final SessionState session;
  final PanganAuthService auth;

  const OrdersScreen({
    super.key,
    required this.isProduction,
    required this.data,
    required this.session,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final store = DemoHolder.of(context);
    final services = ServicesHolder.of(context);

    if (isProduction) {
      if (!auth.isSignedIn) {
        return const EmptyView(
          title: 'Akun produksi belum terhubung',
          description: 'Pesanan nyata memerlukan akun Firebase. Masuk demo tidak membuka pesanan produksi.',
        );
      }
      return _ProductionOrdersView(
        data: data,
        session: session,
        auth: auth,
        payments: services.payments,
        device: services.device,
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([session, store]),
      builder: (context, _) {
        if (!session.isLoggedIn) {
          return EmptyView(
            title: 'Masuk demo dulu',
            description:
                'Riwayat pesanan tersimpan di perangkat ini. '
                'Masuk dengan nama demo untuk melihatnya.',
            action: FilledButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Masuk demo'),
            ),
          );
        }
        if (store.myOrders.isEmpty) {
          return const EmptyView(
            title: 'Belum ada pesanan',
            description: 'Pesan dari tab Jelajahi → Detail.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppTokens.pagePadPhone),
          itemCount: store.myOrders.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.gapCard),
            child: _OrderItem(
              order: store.myOrders[i],
              onTiket: () => _tiket(context, store.myOrders[i]),
              onBayar: () => _bayar(context, store.myOrders[i]),
              onBatal: () => _batal(context, store.myOrders[i]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _tiket(BuildContext context, DemoOrder order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PickupTicketScreen(order: order)),
    );
  }

  Future<void> _bayar(BuildContext context, DemoOrder order) async {
    final services = ServicesHolder.of(context);
    final store = DemoHolder.of(context);
    final session = SessionHolder.of(context);
    final lunas = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          order: order,
          store: store,
          payments: services.payments,
          deviceId: services.device.deviceId,
          namaPembeli: session.displayName,
        ),
      ),
    );
    if (lunas == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pembayaran lunas. Buka Pesanan → Tampilkan QR saat mengambil.',
          ),
        ),
      );
    }
  }

  Future<void> _batal(BuildContext context, DemoOrder order) async {
    final store = DemoHolder.of(context);
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Kuota harian perangkat TIDAK dikembalikan setelah pembatalan '
          '(anti-penyalahgunaan pesan-batalkan berulang).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (lanjut == true) {
      store.cancelOrder(order.id);
    }
  }
}

/// Production orders view - backend Firebase (kontrak PanganDataService)
class _ProductionOrdersView extends StatefulWidget {
  final PanganDataService data;
  final SessionState session;
  final PanganAuthService auth;
  final PaymentGateway payments;
  final DeviceIdentity device;

  const _ProductionOrdersView({
    required this.data,
    required this.session,
    required this.auth,
    required this.payments,
    required this.device,
  });

  @override
  State<_ProductionOrdersView> createState() => _ProductionOrdersViewState();
}

class _ProductionOrdersViewState extends State<_ProductionOrdersView> {
  late Future<List<OrderSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.data.fetchMyOrders(asRecipient: true);
  }

  void _reload() {
    setState(() {
      _future = widget.data.fetchMyOrders(asRecipient: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future;
      },
      child: AsyncView<List<OrderSummary>>(
        future: _future,
        onRetry: _reload,
        isEmpty: (l) => l.isEmpty,
        emptyTitle: 'Belum ada pesanan',
        emptyDescription: 'Pesan dari tab Jelajahi → Detail.',
        errorTitle: 'Gagal memuat pesanan',
        builder: (context, orders) => ListView.builder(
          padding: const EdgeInsets.all(AppTokens.pagePadPhone),
          itemCount: orders.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Daftar ini membaca pesanan server. QR, melanjutkan pembayaran, dan pembatalan produksi belum tersedia di aplikasi ini; tombol tersebut dinonaktifkan. Status tidak diubah secara lokal.',
                ),
              );
            }
            final i = index - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.gapCard),
              child: _ProdOrderItem(
                order: orders[i],
                onTiket: null,
                onBayar: null,
                onBatal: null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Production order item widget
class _ProdOrderItem extends StatelessWidget {
  final OrderSummary order;
  final VoidCallback? onTiket;
  final VoidCallback? onBayar;
  final VoidCallback? onBatal;

  const _ProdOrderItem({
    required this.order,
    required this.onTiket,
    required this.onBayar,
    required this.onBatal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancellable =
        order.status == 'menunggu' || order.status == 'dikonfirmasi';
    final perluBayar =
        order.totalPrice > 0 &&
        order.status != 'dibatalkan' &&
        order.paymentStatus != 'dibayar' &&
        order.paymentStatus != 'menunggu';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.listingTitle} × ${order.quantity}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.status} • ${formatTanggal(order.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                paymentStatusChip(
                  context,
                  paymentStatusFromCode(order.paymentStatus),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Total: ${formatRupiah(order.totalPrice)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
                border: Border.all(
                  color: AppColors.cardBorder(
                    theme.brightness == Brightness.dark,
                  ),
                ),
              ),
              child: Text(
                order.pickupCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                if (order.status != 'dibatalkan')
                  OutlinedButton.icon(
                    onPressed: onTiket,
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('QR belum tersedia'),
                  ),
                if (perluBayar)
                  ElevatedButton(
                    onPressed: onBayar,
                    child: const Text('Bayar belum tersedia'),
                  ),
                if (cancellable)
                  TextButton(
                    onPressed: onBatal,
                    child: const Text('Batalkan belum tersedia'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItem extends StatelessWidget {
  final DemoOrder order;
  final VoidCallback onTiket;
  final VoidCallback onBayar;
  final VoidCallback onBatal;

  const _OrderItem({
    required this.order,
    required this.onTiket,
    required this.onBayar,
    required this.onBatal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancellable =
        order.status == 'menunggu' || order.status == 'dikonfirmasi';
    final status = order.paymentStatus;
    final perluBayar =
        order.perluBayar &&
        order.status != 'dibatalkan' &&
        status != PaymentStatus.dibayar &&
        status != PaymentStatus.menunggu;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.listing.title} × ${order.quantity}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${statusPesananLabel[order.status] ?? order.status} • '
                    '${formatTanggal(order.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                paymentStatusChip(context, status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.schedule,
                  size: 15,
                  color: AppColors.textSecondary(theme.brightness),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ambil di ${order.listing.pickupAddress} • '
                    'sebelum ${formatTanggal(order.listing.pickupEnd)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(theme.brightness),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Total: '
                  '${order.perluBayar ? formatRupiah(order.total) : 'Gratis'}'
                  '${order.payment?.metode != null ? ' • ${order.payment!.metode}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (order.payment?.simulasi == true)
                  HonestyBadge.simulasi(context),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              order.status == 'dibatalkan'
                  ? 'Pesanan dibatalkan. Kuota tidak kembali.'
                  : order.status == 'selesai'
                  ? 'Pengambilan selesai.'
                  : perluBayar
                  ? 'Langkah berikutnya: selesaikan pembayaran. Belum siap diambil.'
                  : order.status == 'menunggu'
                  ? 'Menunggu konfirmasi toko. Belum siap diambil.'
                  : order.status == 'siap_diambil'
                  ? 'Siap diambil. Periksa waktu dan alamat pada tiket.'
                  : 'Toko sedang menyiapkan pesanan. Tunggu sampai siap diambil.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
                border: Border.all(
                  color: AppColors.cardBorder(
                    theme.brightness == Brightness.dark,
                  ),
                ),
              ),
              child: Text(
                order.pickupCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (order.pickedUpAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      order.pickupVerified
                          ? Icons.verified
                          : Icons.info_outline,
                      size: 16,
                      color: order.pickupVerified
                          ? AppColors.positiveFgFor(
                              theme.brightness == Brightness.dark,
                            )
                          : AppColors.textSecondary(theme.brightness),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Diambil ${formatTanggal(order.pickedUpAt!)}'
                        '${order.pickupVerified ? ' • terverifikasi QR penyedia' : ' • diselesaikan manual'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: order.pickupVerified
                              ? AppColors.positiveFgFor(
                                  theme.brightness == Brightness.dark,
                                )
                              : AppColors.textSecondary(theme.brightness),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                if (order.status != 'dibatalkan')
                  OutlinedButton.icon(
                    onPressed: onTiket,
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Tampilkan QR'),
                  ),
                if (perluBayar)
                  ElevatedButton(
                    onPressed: onBayar,
                    child: const Text('Bayar sekarang'),
                  ),
                if (cancellable)
                  TextButton(onPressed: onBatal, child: const Text('Batalkan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
