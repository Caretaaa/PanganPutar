import 'package:flutter/material.dart';

import 'widgets.dart';

/// Satu pola loading/empty/error untuk semua layar data (desain.md §1 butir 5).
///
/// Layar cukup memanggil ulang future-nya (setState) untuk memuat ulang;
/// galat selalu menyediakan aksi [onRetry] bila diberikan.
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  /// Dipakai saat hasil valid tetapi dianggap kosong (mis. list kosong).
  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String emptyDescription;
  final Widget? emptyAction;
  final String errorTitle;
  final VoidCallback? onRetry;
  final bool Function(Object error)? isOffline;

  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.isEmpty,
    this.emptyTitle = 'Belum ada data',
    this.emptyDescription = 'Belum ada yang bisa ditampilkan di sini.',
    this.emptyAction,
    this.errorTitle = 'Gagal memuat',
    this.onRetry,
    this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SkeletonFeed();
        }
        if (snap.hasError) {
          final offline = isOffline?.call(snap.error!) ?? false;
          return ErrorView(
            title: offline ? 'Sedang offline' : errorTitle,
            description: offline
                ? 'Koneksi ke server terputus. Periksa internet, lalu coba lagi.'
                : 'Data belum dapat dimuat. Coba lagi beberapa saat.',
            onRetry: onRetry,
          );
        }
        final data = snap.data;
        if (data == null || (isEmpty?.call(data) ?? false)) {
          return EmptyView(
            title: emptyTitle,
            description: emptyDescription,
            action: emptyAction,
          );
        }
        return builder(context, data);
      },
    );
  }
}

/// Skeleton feed: kartu-kartu bentuk lebih dulu sebelum data tiba.
/// Sengaja statis (tanpa Timer/animasi) agar tes tidak hang/leak.
class _SkeletonFeed extends StatelessWidget {
  const _SkeletonFeed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black12;
    Widget block(double h, {double? w, double r = 8}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    Widget kartu() => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(96, w: 96, r: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(10, w: 120),
                const SizedBox(height: 8),
                block(16),
                const SizedBox(height: 8),
                block(10, w: 180),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    block(28, w: 88, r: 999),
                    block(28, w: 120, r: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: 4,
      itemBuilder: (context, i) =>
          Card(margin: const EdgeInsets.only(bottom: 8), child: kartu()),
    );
  }
}
