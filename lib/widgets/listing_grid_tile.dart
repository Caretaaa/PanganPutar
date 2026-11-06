import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../core/geo.dart' show formatJarak;
import '../core/tokens.dart';
import '../models/models.dart';
import 'listing_image.dart';
import 'status_chips.dart';

/// Kartu listing ringkas untuk grid 2 kolom (gaya Shopee).
///
/// Foto di atas, judul maksimal 2 baris, harga, sisa porsi, dan badge
/// GRATIS. Seluruh kartu dapat diketuk; tinggi mengikuti sel grid.
class ListingGridTile extends StatelessWidget {
  final FoodListing item;
  final VoidCallback? onTap;
  final bool verified;
  final String? storeName;
  final double? distanceKm;
  final bool isSaved;
  final VoidCallback? onToggleSave;

  const ListingGridTile({
    super.key,
    required this.item,
    this.onTap,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto mengisi sisa tinggi sel; teks di bawah berukuran tetap.
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: _adaFoto
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListingImage(
                          item: item,
                          height: constraints.maxHeight,
                        ),
                      )
                    : _PlaceholderGrid(item: item),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (storeName != null || distanceKm != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (storeName != null) storeName,
                        if (distanceKm != null) formatJarak(distanceKm!),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: sec),
                    ),
                  ],
                  if (item.id.startsWith('contoh-'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: HonestyBadge.dataContoh(context),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _HargaGrid(item: item)),
                      if (onToggleSave != null)
                        InkWell(
                          onTap: onToggleSave,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              size: 18,
                              color: isSaved
                                  ? AppColors.positiveFgFor(
                                      theme.brightness == Brightness.dark,
                                    )
                                  : sec,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (verified)
                        Icon(
                          Icons.verified,
                          size: 13,
                          semanticLabel: 'Toko terverifikasi',
                          color: AppColors.positiveFgFor(
                            theme.brightness == Brightness.dark,
                          ),
                        ),
                      if (verified) const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _hampirHabis
                              ? 'Hampir habis — ${item.quantityAvailable} ${item.unit}'
                              : 'Sisa ${item.quantityAvailable} ${item.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _hampirHabis
                                ? (theme.brightness == Brightness.dark
                                      ? AppColors.warnFgDark
                                      : AppColors.warnFgLight)
                                : sec,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HargaGrid extends StatelessWidget {
  final FoodListing item;
  const _HargaGrid({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (item.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.badgeGratisBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'GRATIS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.badgeGratisFg,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatRupiah(item.effectivePrice),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.positiveFgFor(theme.brightness == Brightness.dark),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (item.originalPriceRupiah != null &&
            item.originalPriceRupiah! > item.effectivePrice)
          Text(
            formatRupiah(item.originalPriceRupiah!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
              color: AppColors.textSecondary(theme.brightness),
            ),
          ),
      ],
    );
  }
}

class _PlaceholderGrid extends StatelessWidget {
  final FoodListing item;
  const _PlaceholderGrid({required this.item});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.nightSurface : AppColors.sand;
    final fg = AppColors.textSecondary(
      dark ? Brightness.dark : Brightness.light,
    );
    return Container(
      color: bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Icon(Icons.restaurant, size: 26, color: fg),
    );
  }
}
