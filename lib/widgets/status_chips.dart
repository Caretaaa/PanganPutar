import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../models/payment.dart';
import '../core/security_rules.dart';

/// Lencana status kecil — satu bentuk untuk semua status.
class StatusChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  const StatusChip({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Pas warna chip sesuai tema (terang/gelap) — tanpa hex inline di screens.
({Color fg, Color bg}) statusColors(
  BuildContext context, {
  required bool positif,
  required bool waspada,
  required bool gagal,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (positif) {
    return (
      fg: dark ? AppColors.pineLight : AppColors.pine,
      bg: (dark ? AppColors.pineLight : AppColors.pine).withValues(
        alpha: dark ? 0.18 : 0.12,
      ),
    );
  }
  if (waspada) {
    return (
      fg: dark ? AppColors.warnFgDark : AppColors.warnFgLight,
      bg: dark ? AppColors.warnBgDark : AppColors.warnBgLight,
    );
  }
  if (gagal) {
    final err = Theme.of(context).colorScheme.error;
    return (fg: err, bg: err.withValues(alpha: 0.12));
  }
  return (
    fg: AppColors.textSecondaryFor(dark),
    bg: AppColors.grayLight.withValues(alpha: dark ? 0.16 : 0.4),
  );
}

/// Warna teks peringatan sesuai tema (mis. batasan kuota, verifikasi menunggu).
Color warnFgOf(BuildContext context) =>
    statusColors(context, positif: false, waspada: true, gagal: false).fg;

StatusChip providerStatusChip(BuildContext context, ProviderStatus status) {
  final c = statusColors(
    context,
    positif: status == ProviderStatus.terverifikasi,
    waspada: status == ProviderStatus.menungguReview,
    gagal: status == ProviderStatus.ditolak,
  );
  return StatusChip(
    label: providerStatusLabel(status),
    foreground: c.fg,
    background: c.bg,
  );
}

StatusChip paymentStatusChip(BuildContext context, PaymentStatus status) {
  final c = statusColors(
    context,
    positif: status == PaymentStatus.dibayar,
    waspada: status == PaymentStatus.menunggu,
    gagal: status == PaymentStatus.gagal || status == PaymentStatus.kedaluwarsa,
  );
  return StatusChip(
    label: paymentStatusLabel[status] ?? '-',
    foreground: c.fg,
    background: c.bg,
  );
}

/// Badge kejujuran data: DEMO, SIMULASI, Data contoh, Terverifikasi.
class HonestyBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool positif;
  final bool waspada;
  const HonestyBadge({
    super.key,
    required this.label,
    required this.icon,
    this.positif = false,
    this.waspada = false,
  });

  factory HonestyBadge.demo(BuildContext context) =>
      HonestyBadge(label: 'DEMO', icon: Icons.science_outlined, waspada: true);

  factory HonestyBadge.simulasi(BuildContext context) => HonestyBadge(
    label: 'SIMULASI · tanpa uang nyata',
    icon: Icons.replay_outlined,
    waspada: true,
  );

  factory HonestyBadge.dataContoh(BuildContext context) =>
      HonestyBadge(label: 'Data contoh', icon: Icons.dataset_outlined);

  factory HonestyBadge.terverifikasi(BuildContext context) => HonestyBadge(
    label: 'Toko terverifikasi',
    icon: Icons.verified,
    positif: true,
  );

  @override
  Widget build(BuildContext context) {
    final c = statusColors(
      context,
      positif: positif,
      waspada: waspada,
      gagal: false,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot kategori 6px — satu-satunya pemakaian warna per kategori.
Color dotForCategory(String category, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  if (category.isEmpty) return AppColors.textSecondary(brightness);
  return AppColors.positiveFgFor(dark);
}

/// Baris judul kartu: dot kategori + label kapital kecil.
Widget categoryDotLabel(BuildContext context, FoodListing item) {
  final theme = Theme.of(context);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dotForCategory(item.category, theme.brightness),
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          '${kategoriLabel[item.category] ?? item.category} • ${item.city}'
              .toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary(Theme.of(context).brightness),
            letterSpacing: 0.8,
          ),
        ),
      ),
    ],
  );
}
