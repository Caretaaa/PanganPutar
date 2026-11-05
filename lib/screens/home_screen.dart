import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/adaptive.dart';
import '../core/app_colors.dart';
import '../core/format.dart';
import '../core/tokens.dart';
import '../data/feed_filter.dart';
import '../data/sample_data.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../services/contracts.dart';
import '../widgets/app_holders.dart';
import '../widgets/async_view.dart';
import '../widgets/listing_tile.dart';
import '../widgets/status_chips.dart';
import '../widgets/widgets.dart' show EmptyView;
import 'detail_screen.dart';
import 'provider_screen.dart';

/// Beranda — kata "Beranda" hanya ada sekali: di navigasi bawah/rail
/// (main.dart). Header di sini hanya tagline + aksi.
/// Feed punya: pemilih lokasi & jarak dari data contoh (istilah "±x km"),
/// chips filter cepat fungsional, dan kartu listing tinggi-mengikuti-isi.
class HomeScreen extends StatefulWidget {
  final PanganPutarApi api;
  final SessionState session;
  final void Function(int) goTab;
  final bool isProduction;
  final PanganDataService data;
  const HomeScreen({
    super.key,
    required this.api,
    required this.session,
    required this.goTab,
    required this.isProduction,
    required this.data,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// ---- Filter cepat ------------------------------------------------------
// Enum & logika ada di lib/data/feed_filter.dart (murni, bisa diuji).
typedef _FeedFilter = FeedFilter;

extension _FeedFilterX on FeedFilter {
  String get label => switch (this) {
    FeedFilter.semua => 'Semua',
    FeedFilter.gratis => 'Gratis',
    FeedFilter.berbayar => 'Berbayar',
    FeedFilter.terdekat => 'Terdekat',
    FeedFilter.segera => 'Segera berakhir',
  };
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<FoodListing>> _future;
  _FeedFilter _filter = _FeedFilter.semua;
  String? _kategori; // null = semua kategori
  SampleLocation? _lokasi; // null = belum memilih
  final Set<String> _tersimpan = {}; // tanda simpan per sesi (in-memory)

  Map<String, double> _jarakServer = {}; // km, dihasilkan SERVER (PostGIS)
  bool _feedServer = false; // true saat dari nearby_listings

  @override
  void initState() {
    super.initState();
    _future = _load();
    _muatLokasi();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _muatLokasi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('pp_lokasi_demo_v1');
      if (id == null || !mounted) return;
      for (final l in sampleLocations) {
        if (l.id == id) {
          if (mounted) setState(() => _lokasi = l);
          // Mode produksi: lokasi sudah dikenal → feed jarak server.
          if (widget.isProduction && mounted) _reload();
          return;
        }
      }
    } catch (_) {
      // Tidak berpengaruh ke data; pemilih lokasi tetap bisa dipakai.
    }
  }

  Future<void> _pilihLokasi(SampleLocation? loc) async {
    setState(() => _lokasi = loc);
    if (_filter == _FeedFilter.terdekat && loc == null) {
      setState(() => _filter = _FeedFilter.semua);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (loc == null) {
        await prefs.remove('pp_lokasi_demo_v1');
      } else {
        await prefs.setString('pp_lokasi_demo_v1', loc.id);
      }
    } catch (_) {
      // Preferensi lokasi gagal disimpan: tetap aman dalam sesi ini.
    }
    if (widget.isProduction) _reload();
  }

  Future<List<FoodListing>> _load() async {
    if (widget.isProduction) {
      final loc = _lokasi;
      if (loc != null) {
        try {
          final dekat = await widget.data.fetchNearbyListings(
            loc.point.lat,
            loc.point.lng,
          );
          if (!mounted) return const [];
          _jarakServer = {
            for (final e in dekat) e.listing.id: e.jarakM / 1000.0,
          };
          _feedServer = true;
          return [for (final e in dekat) e.listing];
        } catch (_) {
          // Boleh jatuh ke feed biasa — tapi TANPA angka jarak:
          // data jarak tidak ada, tidak boleh dikarang.
          if (!mounted) return const [];
          _jarakServer = {};
          _feedServer = false;
          return widget.data.fetchListings();
        }
      }
      _jarakServer = {};
      _feedServer = false;
      return widget.data.fetchListings();
    }
    return widget.api.fetchListings();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  /// Terapkan filter via logika murni [applyFeedFilter].
  List<FoodListing> _terapkanFilter(List<FoodListing> sumber) =>
      applyFeedFilter(
        sumber: sumber,
        filter: _filter,
        kategori: _kategori,
        lokasi: _lokasi,
        // Jarak produksi dari server; null berarti jalan jalur demo
        // (jarak contoh berlabel di sampleGeo).
        jarakLuar: _feedServer && _jarakServer.isNotEmpty ? _jarakServer : null,
      );

  @override
  Widget build(BuildContext context) {
    final providers = ServicesHolder.of(context).providers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          onCari: () => widget.goTab(1),
          onPenyedia: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProviderHubScreen())),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: AsyncView<List<FoodListing>>(
              future: _future,
              onRetry: _reload,
              isEmpty: (l) => l.isEmpty,
              emptyTitle: 'Belum ada penawaran',
              emptyDescription: 'Coba lagi nanti. Penawaran kedaluwarsa otomatis disembunyikan.',
              errorTitle: 'Gagal memuat beranda',
              builder: (context, listings) {
                final hasil = _terapkanFilter(listings);
                final kategoriTersedia = <String>[];
                for (final l in listings) {
                  if (!kategoriTersedia.contains(l.category)) {
                    kategoriTersedia.add(l.category);
                  }
                }

                return ListenableBuilder(
                  listenable: providers,
                  builder: (context, _) {
                    final lokasiNullTerdekat =
                        _filter == _FeedFilter.terdekat && _lokasi == null;
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _LokasiDanFilter(
                            lokasi: _lokasi,
                            onLokasi: _pilihLokasi,
                            filter: _filter,
                            onFilter: (f) {
                              if (f == _FeedFilter.terdekat &&
                                  _lokasi == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Pilih lokasi dulu agar "Terdekat" punya acuan.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() => _filter = f);
                            },
                            kategori: _kategori,
                            kategoriTersedia: kategoriTersedia,
                            onKategori: (k) => setState(() => _kategori = k),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: pagePadding(context),
                            child: Row(
                              children: [
                                if (listings.any(
                                  (l) => l.id.startsWith('contoh-'),
                                )) ...[
                                  HonestyBadge.dataContoh(context),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    hasil.length == listings.length
                                        ? '${hasil.length} penawaran'
                                        : '${hasil.length} dari ${listings.length} penawaran',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary(
                                            Theme.of(context).brightness,
                                          ),
                                        ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Muat ulang penawaran',
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (lokasiNullTerdekat)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Lokasi belum dipilih — pilih di atas.',
                              ),
                            ),
                          )
                        else if (hasil.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: pagePadding(context),
                              child: EmptyView(
                                title: 'Tidak ada yang cocok',
                                description: 'Coba hapus filter atau pilih kategori lain.',
                                action: TextButton(
                                  onPressed: () => setState(() {
                                    _filter = _FeedFilter.semua;
                                    _kategori = null;
                                  }),
                                  child: const Text('Hapus semua filter'),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: pagePadding(context),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                i,
                              ) {
                                final l = hasil[i];
                                final lokasi = _lokasi;
                                final jarak = widget.isProduction
                                    ? (_jarakServer[l
                                          .id]) // dari server, tanpa itu: null
                                    : (lokasi == null
                                          ? null
                                          : jarakDariGe(lokasi, l.id));
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i == hasil.length - 1
                                        ? 0
                                        : AppTokens.gapCard,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: AppTokens.feedMaxWidth,
                                    ),
                                    child: ListingTile(
                                      item: l,
                                      verified:
                                          !widget.isProduction &&
                                          providers.isVerified(l.providerId),
                                      storeName: widget.isProduction
                                          ? null
                                          : providers
                                                .profileOf(l.providerId)
                                                ?.namaToko,
                                      distanceKm: jarak,
                                      isSaved: _tersimpan.contains(l.id),
                                      onToggleSave: () => _toggleSimpan(l),
                                      onTap: () => _bukaDetail(context, l),
                                      onPesan: () => _bukaDetail(context, l),
                                    ),
                                  ),
                                );
                              }, childCount: hasil.length),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _toggleSimpan(FoodListing l) {
    final sudah = _tersimpan.contains(l.id);
    setState(() => sudah ? _tersimpan.remove(l.id) : _tersimpan.add(l.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sudah ? 'Tanda simpan dihapus.' : 'Ditandai untuk sesi ini.',
        ),
      ),
    );
  }

  void _bukaDetail(BuildContext context, FoodListing l) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DetailScreen(api: widget.api, listingId: l.id, fallback: l),
      ),
    );
  }
}

// ---------- Header: tagline + aksi. TANPA kata "Beranda". ----------
class _Header extends StatelessWidget {
  final VoidCallback onCari;
  final VoidCallback onPenyedia;
  const _Header({required this.onCari, required this.onPenyedia});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pagePadding(context).left,
        12,
        pagePadding(context).right,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Putaran kebaikan.',
            style: theme.textTheme.titleLarge?.copyWith(
              height: 1.15,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: onCari,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                child: const Text('Cari makanan'),
              ),
              // Tombol sekunder yang JELAS (bukan teks biasa).
              OutlinedButton(
                onPressed: onPenyedia,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                child: const Text('Jadi penyedia'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Pemilih lokasi + chip filter ----------
class _LokasiDanFilter extends StatelessWidget {
  final SampleLocation? lokasi;
  final void Function(SampleLocation?) onLokasi;
  final _FeedFilter filter;
  final void Function(_FeedFilter) onFilter;
  final String? kategori;
  final List<String> kategoriTersedia;
  final void Function(String?) onKategori;

  const _LokasiDanFilter({
    required this.lokasi,
    required this.onLokasi,
    required this.filter,
    required this.onFilter,
    required this.kategori,
    required this.kategoriTersedia,
    required this.onKategori,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pagePadding(context).left,
            4,
            pagePadding(context).right,
            8,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (lokasi != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.positiveFgFor(
                        theme.brightness == Brightness.dark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        lokasi!.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              PopupMenuButton<String>(
                tooltip: 'Pilih lokasi (contoh kota Bandung)',
                onSelected: (id) {
                  if (id == '__tanpa') {
                    onLokasi(null);
                    return;
                  }
                  for (final l in sampleLocations) {
                    if (l.id == id) onLokasi(l);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: '__tanpa',
                    child: Text('Tanpa lokasi'),
                  ),
                  for (final l in sampleLocations)
                    PopupMenuItem(value: l.id, child: Text(l.label)),
                ],
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.cardBorderDark
                          : AppColors.cardBorderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lokasi == null) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.positiveFgFor(
                            theme.brightness == Brightness.dark,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          'Pilih lokasi',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.positiveFgFor(
                              theme.brightness == Brightness.dark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsetsDirectional.only(
            start: pagePadding(context).left + 4,
          ),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ChipBox(
                label: _FeedFilter.semua.label,
                selected: filter == _FeedFilter.semua,
                icon: Icons.apps,
                onTap: () => onFilter(_FeedFilter.semua),
              ),
              _ChipBox(
                label: _FeedFilter.gratis.label,
                selected: filter == _FeedFilter.gratis,
                icon: Icons.check_circle_outline,
                onTap: () => onFilter(_FeedFilter.gratis),
              ),
              _ChipBox(
                label: _FeedFilter.berbayar.label,
                selected: filter == _FeedFilter.berbayar,
                icon: Icons.payments_outlined,
                onTap: () => onFilter(_FeedFilter.berbayar),
              ),
              _ChipBox(
                label: _FeedFilter.terdekat.label,
                selected: filter == _FeedFilter.terdekat,
                icon: Icons.near_me_outlined,
                onTap: () => onFilter(_FeedFilter.terdekat),
              ),
              _ChipBox(
                label: _FeedFilter.segera.label,
                selected: filter == _FeedFilter.segera,
                icon: Icons.hourglass_bottom,
                onTap: () => onFilter(_FeedFilter.segera),
              ),
              for (final k in kategoriTersedia)
                _ChipBox(
                  label: kategoriLabel[k] ?? k,
                  selected: kategori == k,
                  onTap: () => onKategori(kategori == k ? null : k),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip filter AC AA: terpilih = pine penuh + teks terang; tidak terpilih
/// = latar samar + teks sekunder AA. Tinggi ≥ 44 px target sentuh.
class _ChipBox extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _ChipBox({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected
        ? Colors.white
        : AppColors.textSecondary(theme.brightness);
    final bg = selected
        ? AppColors.pine
        : (theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: fg),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
