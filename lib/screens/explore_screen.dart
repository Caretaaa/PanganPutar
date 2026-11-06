import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/contracts.dart';
import '../widgets/app_holders.dart';
import '../widgets/async_view.dart';
import '../widgets/listing_grid_tile.dart';
import 'detail_screen.dart';

const categories = [
  '',
  'nasi',
  'roti',
  'lauk',
  'sayur',
  'buah',
  'minuman',
  'paket',
  'jajanan',
  'lainnya',
];

class ExploreScreen extends StatefulWidget {
  final PanganPutarApi api;
  final bool isProduction;
  final PanganDataService data;
  const ExploreScreen({
    super.key,
    required this.api,
    required this.isProduction,
    required this.data,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _q = TextEditingController();
  final _kota = TextEditingController();
  String _kategori = '';
  bool _gratis = false;
  late Future<List<FoodListing>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FoodListing>> _load() async {
    if (widget.isProduction) {
      return widget.data.fetchListings(
        query: _q.text,
        kategori: _kategori,
        kota: _kota.text,
        gratisSaja: _gratis,
      );
    }
    return widget.api.fetchListings(
      ListingFilter(
        q: _q.text,
        kategori: _kategori,
        kota: _kota.text,
        gratisSaja: _gratis,
      ),
    );
  }

  void _apply() {
    setState(() {
      _future = _load();
    });
  }

  bool get _filterAktif =>
      _q.text.trim().isNotEmpty ||
      _kategori.isNotEmpty ||
      _kota.text.trim().isNotEmpty ||
      _gratis;

  void _reset() {
    _q.clear();
    _kota.clear();
    setState(() {
      _kategori = '';
      _gratis = false;
      _future = _load();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _kota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = ServicesHolder.of(context).providers;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            // Panel filter — kartu flat, tanpa border ganda (theme sudah menangani).
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _q,
                      decoration: InputDecoration(
                        labelText: 'Cari nama (mis. nasi kotak)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Cari makanan',
                          onPressed: _apply,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _apply(),
                    ),
                    const SizedBox(height: AppTokens.gapCard),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text('Filter makanan'),
                      subtitle: Text(
                        [
                          if (_kategori.isNotEmpty)
                            kategoriLabel[_kategori] ?? _kategori,
                          if (_kota.text.trim().isNotEmpty) _kota.text.trim(),
                          if (_gratis) 'Gratis saja',
                          if (_kategori.isEmpty &&
                              _kota.text.trim().isEmpty &&
                              !_gratis)
                            'Kategori, kota, dan gratis saja',
                        ].join(' • '),
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _kategori,
                                key: ValueKey(_kategori),
                                isExpanded: true,
                                style: Theme.of(context).textTheme.bodyMedium,
                                decoration: const InputDecoration(
                                  labelText: 'Kategori',
                                ),
                                items: categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c.isEmpty
                                              ? 'Semua'
                                              : kategoriLabel[c] ?? c,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _kategori = v ?? ''),
                              ),
                            ),
                            const SizedBox(width: AppTokens.gapCard),
                            Expanded(
                              child: TextField(
                                controller: _kota,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Kota',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.gapCard),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _gratis,
                                  onChanged: (v) =>
                                      setState(() => _gratis = v ?? false),
                                ),
                                const Text(
                                  'Gratis saja',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (_filterAktif)
                              TextButton(
                                onPressed: _reset,
                                child: const Text('Atur ulang'),
                              ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: _apply,
                          child: const Text('Terapkan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      body: ListenableBuilder(
        listenable: providers,
        builder: (context, _) => AsyncView<List<FoodListing>>(
          future: _future,
          onRetry: _apply,
          isEmpty: (l) => l.isEmpty,
          emptyTitle: 'Tidak ada penawaran yang cocok',
          emptyDescription:
              'Ubah kata kunci atau hapus filter. Yang kedaluwarsa '
              'otomatis disembunyikan.',
          emptyAction: TextButton(
            onPressed: _reset,
            child: const Text('Hapus semua filter'),
          ),
          errorTitle: 'Gagal memuat hasil',
          builder: (context, items) {
            // Height follows text scale so the compact card never overflows.
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final tileExtent = (252 + (textScale - 1) * 130).clamp(
              252.0,
              400.0,
            );
            return RefreshIndicator(
              onRefresh: () async => _apply(),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${items.length} penawaran',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (_filterAktif)
                            TextButton(
                              onPressed: _reset,
                              child: const Text('Atur ulang'),
                            ),
                          IconButton(
                            tooltip: 'Muat ulang hasil',
                            onPressed: _apply,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      AppTokens.gapSection,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: tileExtent,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => ListingGridTile(
                        item: items[i],
                        verified:
                            !widget.isProduction &&
                            providers.isVerified(items[i].providerId),
                        storeName: widget.isProduction
                            ? null
                            : providers
                                  .profileOf(items[i].providerId)
                                  ?.namaToko,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(
                              api: widget.api,
                              listingId: items[i].id,
                              fallback: items[i],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
