import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/models.dart';
import 'status_chips.dart';

/// Foto listing dengan penanganan gagal-muat yang anggun.
///
/// Sumber gambar:
/// - `imageAsset` (data contoh) → aset lokal; selalu diberi label
///   "Foto ilustrasi" karena bukan foto makanan yang dijual.
/// - `imageUrl` (dari server/penyedia) → foto jaringan tanpa label ilustrasi.
///
/// Bila tidak ada sumber, gambar gagal dimuat, atau berkas rusak, widget ini
/// menyajikan panel placeholder bertekstur lembut — tanpa layout error.
class ListingImage extends StatelessWidget {
  final FoodListing item;

  /// Tinggi area gambar (kartu listing kecil, foto detail besar).
  final double height;

  /// Tampilkan baris keterangan di bawah gambar (khusus layar detail).
  final bool showCaption;

  const ListingImage({
    super.key,
    required this.item,
    this.height = 80,
    this.showCaption = false,
  });

  String? get _asset =>
      (item.imageAsset?.isNotEmpty ?? false) ? item.imageAsset : null;
  String? get _url =>
      (item.imageUrl?.isNotEmpty ?? false) ? item.imageUrl : null;

  /// True bila gambar berasal dari data contoh (aset lokal berlisensi).
  bool get _illustrative => _asset != null;

  @override
  Widget build(BuildContext context) {
    final src = _asset ?? _url;
    if (src == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    final image = _asset != null
        ? Image.asset(
            _asset!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context),
          )
        : Image.network(
            _url!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _placeholderShell(
                context,
                dark,
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            },
            errorBuilder: (_, _, _) => _fallback(context),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (_illustrative)
                  const Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _IllustrasiChip(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showCaption)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: _illustrative
                      ? warnFgOf(context)
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _illustrative
                        ? 'Foto ilustrasi — bukan foto makanan yang dijual.'
                        : 'Foto dari penyedia.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 1.4,
                      color: _illustrative
                          ? warnFgOf(context)
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Placeholder saat gambar gagal dimuat / berkas rusak.
  Widget _fallback(BuildContext context) => _placeholderShell(
    context,
    Theme.of(context).brightness == Brightness.dark,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: height > 120 ? 32 : 20,
            color: AppColors.textSecondary(Theme.of(context).brightness),
          ),
          if (height > 120)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Foto tidak tersedia',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary(Theme.of(context).brightness),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _placeholderShell(
    BuildContext context,
    bool dark, {
    required Widget child,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? AppColors.nightSurface : AppColors.sand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder(dark)),
      ),
      child: child,
    );
  }
}

/// Keterangan netral untuk foto data contoh.
class _IllustrasiChip extends StatelessWidget {
  const _IllustrasiChip();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Foto ilustrasi',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: colors.onSurface),
      ),
    );
  }
}
