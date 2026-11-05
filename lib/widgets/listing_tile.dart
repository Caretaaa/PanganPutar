import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/geo.dart' show formatJarak;
import '../core/format.dart';
import '../core/tokens.dart';
import '../models/models.dart';
import 'listing_image.dart';
import 'putaran_primitives.dart';
import 'status_chips.dart';

/// Kartu listing — satu widget untuk feed dan grid.
/// Foto di atas pada kartu sempit; foto di kiri saat ruang mencukupi.
/// Tinggi mengikuti isi, termasuk pembesaran teks. Menampilkan:
/// nama toko • jarak (bila lokasi dipilih), countdown batas waktu ambil,
/// sisa porsi + tag "Hampir habis", harga normal dicoret, badge GRATIS
/// berbeda visual, tombol "Pesan" + ikon simpan.
class ListingTile extends StatelessWidget {
  final FoodListing item;
  final VoidCallback? onTap;
  final VoidCallback? onPesan;

  /// Teal "Toko terverifikasi" bila true.
  final bool verified;

  /// Nama toko (dari registry demo / profil toko). `null` → tak ditampilkan,
  /// bukan diganti nama fiktif.
  final String? storeName;

  /// Jarak dari lokasi terpilih dalam km; null = lokasi belum dipilih.
  final double? distanceKm;

  /// Status "disimpan" per sesi (in-memory, perangkat ini).
  final bool isSaved;
  final VoidCallback? onToggleSave;

  const ListingTile({
    super.key,
    required this.item,
    this.onTap,
    this.onPesan,
    this.verified = false,
    this.storeName,
    this.distanceKm,
    this.isSaved = false,
    this.onToggleSave,
  });

  bool get _adaFoto =>
      (item.imageAsset?.isNotEmpty ?? false) ||
      (item.imageUrl?.isNotEmpty ?? false);

  bool get _hampirHabis => item.quantityAvailable <= AppTokens.hampirHabisSisa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sec = AppColors.textSecondary(theme.brightness);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Fit the *available card width*, including rail/grid layouts.
            // At large font sizes give the food details the entire line.
            final stacked =
                constraints.maxWidth < 440 ||
                (constraints.maxWidth < 600 &&
                    MediaQuery.textScalerOf(context).scale(14) > 18);
            final photo = ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusInput),
              child: _adaFoto
                  ? ListingImage(item: item, height: stacked ? 96 : 160)
                  : _PlaceholderHalus(item: item),
            );
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: categoryDotLabel(context, item)),
                    if (verified)
                      Tooltip(
                        message: 'Toko terverifikasi',
                        child: Icon(
                          Icons.verified,
                          size: 18,
                          semanticLabel: 'Toko terverifikasi',
                          color: AppColors.positiveFgFor(
                            theme.brightness == Brightness.dark,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.15),
                ),
                if (item.id.startsWith('contoh-')) ...[
                  const SizedBox(height: 4),
                  HonestyBadge.dataContoh(context),
                ],
                const SizedBox(height: 3),
                // Baris nama toko • jarak; verifikasi tampil ikon atas.
                if (storeName != null || distanceKm != null)
                  Text(
                    [
                      if (storeName != null) storeName,
                      if (distanceKm != null) formatJarak(distanceKm!),
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sec,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            );
            final facts = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HampirHabisTag(
                  hampir: _hampirHabis,
                  sisa: item.quantityAvailable,
                  unit: item.unit,
                ),
                const SizedBox(height: 10),
                _SisaCountdown(item: item),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _Harga(item: item),
                    _AksiRow(
                      item: item,
                      onPesan: onPesan ?? onTap,
                      isSaved: isSaved,
                      onToggleSave: onToggleSave,
                    ),
                  ],
                ),
              ],
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [heading, const SizedBox(height: 12), facts],
            );
            return Padding(
              padding: const EdgeInsets.all(16),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_adaFoto)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 88, child: photo),
                              const SizedBox(width: 12),
                              Expanded(child: heading),
                            ],
                          )
                        else
                          heading,
                        const SizedBox(height: 12),
                        facts,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 132, child: photo),
                        const SizedBox(width: 16),
                        Expanded(child: details),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

// ---------- Bagian-bagian kartu ----------

class _HampirHabisTag extends StatelessWidget {
  final bool hampir;
  final int sisa;
  final String unit;
  const _HampirHabisTag({
    required this.hampir,
    required this.sisa,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StatusChip(
      label: hampir
          ? 'Hampir habis — $sisa $unit terakhir'
          : 'Sisa $sisa $unit',
      foreground: hampir
          ? (dark ? AppColors.warnFgDark : AppColors.warnFgLight)
          : AppColors.textSecondary(Theme.of(context).brightness),
      background: hampir
          ? (dark ? AppColors.warnBgDark : AppColors.warnBgLight)
          : (dark
                ? AppColors.textSecondaryDark.withValues(alpha: 0.16)
                : AppColors.textSecondaryLight.withValues(alpha: 0.10)),
    );
  }
}

/// Countdown batas waktu pengambilan dengan Timer.periodic per 30 detik —
/// lembut dan selalu cancel di dispose agar tidak hang di tes.
class _SisaCountdown extends StatefulWidget {
  final FoodListing item;
  const _SisaCountdown({required this.item});

  @override
  State<_SisaCountdown> createState() => _SisaCountdownState();
}

class _SisaCountdownState extends State<_SisaCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = timeLeft(widget.item.pickupEnd);
    final habis = label == 'Sudah berakhir';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PutaranCountdownRing(
          remaining: widget.item.pickupEnd.difference(DateTime.now()),
          window: widget.item.pickupEnd.difference(widget.item.pickupStart),
          size: 40,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            habis ? label : 'Batas ambil\n$label',
            style: theme.textTheme.bodySmall?.copyWith(
              color: habis
                  ? theme.colorScheme.error
                  : AppColors.textSecondary(theme.brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Harga extends StatelessWidget {
  final FoodListing item;
  const _Harga({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adaDiskon =
        item.originalPriceRupiah != null &&
        item.originalPriceRupiah! > item.effectivePrice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.isFree)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.badgeGratisBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'GRATIS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.badgeGratisFg,
              ),
            ),
          )
        else
          Text(
            formatRupiah(item.effectivePrice),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.positiveFgFor(
                theme.brightness == Brightness.dark,
              ),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        if (adaDiskon)
          Text(
            formatRupiah(item.originalPriceRupiah!),
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textSecondary(theme.brightness),
              color: AppColors.textSecondary(theme.brightness),
            ),
          ),
      ],
    );
  }
}

class _AksiRow extends StatelessWidget {
  final FoodListing item;
  final VoidCallback? onPesan;
  final bool isSaved;
  final VoidCallback? onToggleSave;

  const _AksiRow({
    required this.item,
    required this.onPesan,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AppTokens.minTouch,
          child: FilledButton.tonal(
            onPressed: onPesan,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(88, AppTokens.minTouch),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: const Text('Pesan'),
          ),
        ),
        if (onToggleSave != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: isSaved ? 'Lepas tanda simpan' : 'Simpan',
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 22,
            ),
            color: isSaved
                ? AppColors.positiveFgFor(
                    Theme.of(context).brightness == Brightness.dark,
                  )
                : null,
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouch,
              minHeight: AppTokens.minTouch,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onToggleSave,
          ),
        ],
      ],
    );
  }
}

/// Placeholder foto yang halus — ikon + judul makanan, tanpa kata
/// "ilustrasi" (foto penyedia asli menggantikan placeholder bila ada).
class _PlaceholderHalus extends StatelessWidget {
  final FoodListing item;
  const _PlaceholderHalus({required this.item});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.nightSurface : AppColors.sand;
    final fg = AppColors.textSecondary(
      dark ? Brightness.dark : Brightness.light,
    );
    return Container(
      height: 96,
      decoration: BoxDecoration(color: bg),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant, size: 20, color: fg),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: fg, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
