import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/adaptive.dart';
import '../core/format.dart';
import '../core/pickup_rules.dart';
import '../core/tokens.dart';
import '../models/payment.dart';
import '../services/demo_store.dart';
import '../services/pickup_service.dart';
import '../widgets/app_holders.dart';
import '../widgets/qr_panel.dart';
import '../widgets/status_chips.dart';
import 'scan_screen.dart';
import 'payment_screen.dart';

/// Tiket pengambilan milik pembeli:
/// QR pesanan (dipindai penyedia saat serah-terima) + tombol pindai QR toko
/// (dipintai pembeli saat tiba untuk memastikan lokasi benar).
class PickupTicketScreen extends StatelessWidget {
  final DemoOrder order;
  const PickupTicketScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final store = DemoHolder.of(context);
    final services = ServicesHolder.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([store, services.providers]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final profil = services.providers.profileOf(order.listing.providerId);
        final namaToko = profil?.namaToko ?? 'Toko penyedia';
        final tiket = PickupTicket(
          orderId: order.id,
          kode: order.pickupCode,
          providerId: order.listing.providerId,
        );
        final selesai = order.status == 'selesai';
        final dibatalkan = order.status == 'dibatalkan';
        final nonaktif = selesai || dibatalkan;
        final belumBayar =
            order.perluBayar && order.paymentStatus != PaymentStatus.dibayar;
        final belumSiap = ![
          'dikonfirmasi',
          'siap_diambil',
        ].contains(order.status);

        return Scaffold(
          appBar: AppBar(title: const Text('Tiket pengambilan')),
          body: AppContentFrame(
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.pagePadPhone),
              children: [
                _bannerStatus(context, selesai, dibatalkan),
                if (!nonaktif && (belumBayar || belumSiap)) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      belumBayar
                          ? 'Belum siap diambil: pembayaran belum lunas. QR ini bukan izin mengambil makanan.'
                          : 'Menunggu konfirmasi toko. Jangan datang hanya berdasarkan QR ini.',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (belumBayar)
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(
                            order: order,
                            store: store,
                            payments: services.payments,
                            deviceId: services.device.deviceId,
                          ),
                        ),
                      ),
                      child: const Text('Lanjutkan pembayaran'),
                    ),
                ],
                const SizedBox(height: AppTokens.gapCard),
                Card(
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
                        Text(
                          '$namaToko'
                          '${services.providers.isVerified(order.listing.providerId) ? ' • Terverifikasi' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ambil: ${formatTanggal(order.listing.pickupStart)}'
                          ' — ${formatTanggal(order.listing.pickupEnd)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.listing.pickupAddress,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              order.perluBayar
                                  ? 'Total: ${formatRupiah(order.total)} • '
                                        '${paymentStatusLabel[order.paymentStatus] ?? '-'}'
                                  : 'Gratis',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (order.payment?.simulasi == true)
                              HonestyBadge.simulasi(context),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.gapCard),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'QR PENGAMBILAN',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary(theme.brightness),
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        QrPanel(
                          data: tiket.encode(),
                          redup: nonaktif || belumBayar || belumSiap,
                          size: 200,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusBtn,
                            ),
                          ),
                          child: Text(
                            order.pickupCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          selesai
                              ? 'Pesanan sudah diambil. QR tidak berlaku lagi.'
                              : dibatalkan
                              ? 'Pesanan dibatalkan. QR tidak berlaku lagi.'
                              : belumBayar || belumSiap
                              ? 'Simpan kode ini. Selesaikan pembayaran bila diperlukan dan tunggu konfirmasi toko sebelum mengambil.'
                              : 'Tunjukkan QR ini ke penyedia saat mengambil '
                                    'makanan. Penyedia memindainya untuk '
                                    'menandai pengambilan selesai dan '
                                    'terverifikasi.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.gapCard),
                _kartuKedatangan(context, nonaktif),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bannerStatus(BuildContext context, bool selesai, bool dibatalkan) {
    if (!selesai && !dibatalkan) return const SizedBox.shrink();
    final c = statusColors(
      context,
      positif: selesai,
      waspada: false,
      gagal: dibatalkan,
    );
    final teks = selesai
        ? 'Sudah diambil${order.pickedUpAt != null ? ' • ${formatTanggal(order.pickedUpAt!)}' : ''}'
              '${order.pickupVerified ? '\nTerverifikasi pindai QR penyedia.' : '\nDiselesaikan manual tanpa QR.'}'
        : 'Pesanan dibatalkan — tiket tidak berlaku.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        children: [
          Icon(
            selesai ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: c.fg,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(
                color: c.fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuKedatangan(BuildContext context, bool nonaktif) {
    final theme = Theme.of(context);
    final terverifikasi = order.arrivalVerifiedAt;
    final warnFg = warnFgOf(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cocokkan QR toko',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              terverifikasi != null
                  ? 'QR toko cocok dengan pesananmu '
                        '(${formatTanggal(terverifikasi)}). Ini bukan bukti posisi fisik.'
                  : 'Pindai QR toko yang dipajang di kasir/pintu untuk '
                        'mencocokkan identitas toko pesananmu. Hasil pindai '
                        'tidak berarti pesanan sudah lunas atau siap diambil; '
                        'tunggu konfirmasi toko sebelum berangkat.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            if (terverifikasi != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.verified,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Toko sesuai pesanan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ] else if (!nonaktif) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pindaiQrToko(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Pindai QR toko'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pemindaian hanya mencocokkan identitas QR — bukan bukti '
                'posisi GPS atau keamanan makanan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: warnFg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pindaiQrToko(BuildContext context) async {
    final store = DemoHolder.of(context);
    final services = ServicesHolder.of(context);

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          judul: 'Pindai QR toko',
          petunjuk:
              'Arahkan kamera ke QR toko yang dipajang di kasir/pintu. '
              'Pemindaian mencocokkan identitas toko dengan pesananmu, '
              'bukan memeriksa posisi fisik.',
        ),
      ),
    );
    if (raw == null || !context.mounted) return;

    final hasil = PickupService(store).prosesScanQrToko(
      raw: raw,
      order: order,
      tokoTerverifikasi: services.providers.isVerified(
        order.listing.providerId,
      ),
    );
    final isi = hasil.peringatan == null
        ? hasil.pesan
        : '${hasil.pesan}\n\n${hasil.peringatan}';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(hasil.sukses ? 'QR toko cocok' : 'QR tidak cocok'),
        content: Text(isi),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
