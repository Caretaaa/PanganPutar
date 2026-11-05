import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/adaptive.dart';
import '../core/business_rules.dart';
import '../core/format.dart';
import '../core/security_rules.dart';
import '../core/tokens.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/demo_store.dart';
import '../services/contracts.dart';
import '../services/provider_registry.dart';
import '../widgets/app_holders.dart';
import '../widgets/listing_image.dart';
import '../widgets/status_chips.dart';
import 'face_verification_screen.dart';
import 'payment_screen.dart';
import 'login_screen.dart';
import 'production_login_screen.dart';

class DetailScreen extends StatefulWidget {
  final PanganPutarApi api;
  final String listingId;
  final FoodListing? fallback;
  const DetailScreen({
    super.key,
    required this.api,
    required this.listingId,
    this.fallback,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<FoodListing?> _future;
  final _qty = TextEditingController(text: '1');
  final _orderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchDetail(widget.listingId);
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail penawaran')),
      bottomNavigationBar: FutureBuilder<FoodListing?>(
        future: _future,
        builder: (context, snap) {
          final item = snap.data ?? widget.fallback;
          if (item == null) return const SizedBox.shrink();
          final services = ServicesHolder.of(context);
          final session = SessionHolder.of(context);
          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: AppContentFrame(
                fillHeight: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total pesanan',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.textSecondary(
                                    Theme.of(context).brightness,
                                  ),
                                ),
                          ),
                          Text(
                            item.isFree
                                ? 'Gratis'
                                : formatRupiah(
                                    item.effectivePrice *
                                        (int.tryParse(_qty.text) ?? 1),
                                  ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      FilledButton(
                        onPressed: () async {
                          if (services.config.isProduction) {
                            if (!services.auth.isSignedIn) {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProductionLoginScreen(),
                                ),
                              );
                              if (mounted) setState(() {});
                              return;
                            }
                          } else if (!session.isLoggedIn) {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                            return;
                          }
                          final target = _orderKey.currentContext;
                          if (target != null) {
                            Scrollable.ensureVisible(
                              target,
                              duration: AppTokens.animStandard,
                              alignment: .1,
                            );
                          }
                        },
                        child: Text(
                          services.config.isProduction
                              ? (services.auth.isSignedIn
                                    ? 'Atur jumlah'
                                    : 'Masuk untuk memesan')
                              : session.isLoggedIn
                              ? 'Atur jumlah'
                              : 'Masuk untuk memesan',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      body: AppContentFrame(
        child: FutureBuilder<FoodListing?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                widget.fallback == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Memuat detail penawaran...'),
                  ],
                ),
              );
            }
            final item = snap.data ?? widget.fallback;
            if (item == null) {
              return const Center(child: Text('Penawaran tidak ditemukan.'));
            }
            final services = ServicesHolder.of(context);
            return ListenableBuilder(
              listenable: Listenable.merge([
                services.ledger,
                services.providers,
                SessionHolder.of(context),
              ]),
              builder: (context, _) => _buildDetail(context, item, services),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    FoodListing item,
    ServicesHolder services,
  ) {
    final production = services.config.isProduction;
    final status = production
        ? ProviderStatus.belumDiajukan
        : services.providers.statusOf(item.providerId);
    final profil = production
        ? null
        : services.providers.profileOf(item.providerId);
    final laporan = evaluateListingSafety(
      listing: item,
      providerStatus: status,
    );

    final qtyDiminta = int.tryParse(_qty.text) ?? 1;
    final qty = qtyDiminta < 1 ? 1 : qtyDiminta;
    final auth = services.auth;
    final productionBlockers = <String>[
      if (!auth.isSignedIn) 'Masuk dengan Google untuk membuat pesanan nyata.',
      if (isExpired(item.pickupEnd)) 'Waktu pengambilan sudah berakhir.',
      if (item.quantityAvailable <= 0) 'Stok habis.',
    ];
    final productionWarnings = <String>[
      if (auth.isSignedIn && auth.needsFaceVerification)
        'Verifikasi wajah diperlukan untuk kuota mingguan sebelum memesan.',
      if (auth.isSignedIn && qty > 4)
        'Maksimal 4 porsi per pesanan pada jalur produksi.',
    ];
    final guard = production
        ? OrderGuard(
            allowed: productionBlockers.isEmpty && qty <= 4,
            blockers: [
              ...productionBlockers,
              if (qty > 4) 'Jumlah porsi tidak wajar (1..4).',
            ],
            warnings: productionWarnings,
          )
        : guardOrder(
            listing: item,
            quantity: qty,
            providerStatus: status,
            usage: services.ledger.usage,
            limits: services.ledger.limits,
          );
    final total = item.effectivePrice * qty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          categoryDotLabel(context, item),
          const SizedBox(height: 6),
          AdaptiveSectionHeader(
            title: Text(
              item.title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(height: 1.05, letterSpacing: -0.5),
            ),
            action: status == ProviderStatus.terverifikasi
                ? HonestyBadge.terverifikasi(context)
                : null,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.id.startsWith('contoh-'))
                HonestyBadge.dataContoh(context),
              _pill(context, formatRupiah(item.effectivePrice)),
              _pill(context, 'Sisa ${item.quantityAvailable} ${item.unit}'),
              _pill(
                context,
                isExpired(item.pickupEnd)
                    ? 'Sudah berakhir'
                    : formatTanggal(item.pickupEnd),
              ),
            ],
          ),
          // Foto (bila ada): ilustrasi data contoh berlabel, foto penyedia apa
          // adanya. Teks hero tetap di atas — foto tidak menggantikan judul.
          if ((item.imageAsset?.isNotEmpty ?? false) ||
              (item.imageUrl?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            ListingImage(item: item, height: 200, showCaption: true),
          ],
          const SizedBox(height: 16),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deskripsi', style: _judulCard(context)),
                const SizedBox(height: 4),
                Text(item.description ?? 'Tidak ada deskripsi.'),
                const SizedBox(height: 12),
                Text('Pengambilan', style: _judulCard(context)),
                const SizedBox(height: 4),
                Text(
                  '${item.pickupAddress}\n'
                  '${formatTanggal(item.pickupStart)} — '
                  '${formatTanggal(item.pickupEnd)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(context, _infoPenting(context, item)),
          const SizedBox(height: 12),
          if (!production)
            _card(context, _keamanan(context, item, status, profil, laporan))
          else
            _card(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Keamanan & validasi toko',
                          style: _judulCard(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Penawaran ini berasal dari data server (Firestore). '
                    'Status verifikasi toko mengikuti data toko yang '
                    'dikelola backend; aplikasi tidak mengarang badge '
                    'terverifikasi.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _card(context, _kuota(context, services)),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _orderKey,
            child: _jumlahDanPesan(context, item, qty, guard, total, services),
          ),
        ],
      ),
    );
  }

  // ---------- Bagian keamanan & validasi toko ----------

  /// Info penting: alergen, penyimpanan, countdown ambil. Kejujuran:
  /// info kebersihan & ulasan TIDAK dimodelkan — ditampilkan apa adanya
  /// ("menyusul"/"belum ada"), bukan dipalsukan.
  Widget _infoPenting(BuildContext context, FoodListing item) {
    final theme = Theme.of(context);
    final sec = AppColors.textSecondary(theme.brightness);

    Widget baris(String judul, String isi) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.positiveFgFor(theme.brightness == Brightness.dark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$judul: ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: isi,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: sec,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final sudahBerakhir = isExpired(item.pickupEnd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveSectionHeader(
          leading: Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.positiveFgFor(theme.brightness == Brightness.dark),
          ),
          title: Text('Info penting', style: _judulCard(context)),
        ),
        const SizedBox(height: 6),
        baris(
          'Batas ambil',
          sudahBerakhir ? 'Sudah berakhir' : timeLeft(item.pickupEnd),
        ),
        baris(
          'Alergen',
          item.allergenInfo ??
              'Tidak dicantumkan oleh penyedia. Tanyakan langsung bila ragu.',
        ),
        baris(
          'Penyimpanan',
          item.storageNote ?? 'Petunjuk penyimpanan tidak dicantumkan.',
        ),
        baris(
          'Info kebersihan',
          'Menyusul dari penyedia — saat ini belum dimodelkan di aplikasi.',
        ),
        baris('Ulasan', 'Belum ada ulasan untuk item ini.'),
      ],
    );
  }

  Widget _keamanan(
    BuildContext context,
    FoodListing item,
    ProviderStatus status,
    ProviderProfile? profil,
    ListingSafetyReport laporan,
  ) {
    final theme = Theme.of(context);
    final terverifikasi = status == ProviderStatus.terverifikasi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveSectionHeader(
          leading: Icon(
            terverifikasi ? Icons.verified : Icons.shield_outlined,
            size: 20,
            color: terverifikasi
                ? theme.colorScheme.secondary
                : AppColors.textSecondary(theme.brightness),
          ),
          title: Text('Keamanan & validasi toko', style: _judulCard(context)),
          action: providerStatusChip(context, status),
        ),
        const SizedBox(height: 6),
        Text(
          profil != null
              ? 'Toko: ${profil.namaToko} • ${profil.kota}'
              : 'Toko belum terdaftar di sistem verifikasi.',
          style: theme.textTheme.bodySmall,
        ),
        const Divider(height: 20),
        ...laporan.checks.map(
          (c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  c.lulus ? Icons.check_circle : Icons.cancel_outlined,
                  size: 16,
                  color: c.lulus
                      ? theme.colorScheme.secondary
                      : (c.wajib
                            ? theme.colorScheme.error
                            : AppColors.textSecondary(theme.brightness)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: c.wajib
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (!c.lulus && c.catatan != null)
                        Text(
                          c.catatan!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary(theme.brightness),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'PanganPutar tidak menyatakan makanan aman hanya karena terdaftar. '
          'Periksa aroma, warna, dan kemasan sebelum mengambil.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            height: 1.5,
            color: AppColors.textSecondary(theme.brightness),
          ),
        ),
      ],
    );
  }

  // ---------- Bagian kuota harian per perangkat ----------

  Widget _kuota(BuildContext context, ServicesHolder services) {
    final theme = Theme.of(context);
    if (services.config.isProduction) {
      return _kuotaProduksi(context, services);
    }
    final ledger = services.ledger;
    final max = ledger.limits.maxPorsiPerHari;
    final terpakai = ledger.porsiHariIni;
    final fraksi = max == 0 ? 0.0 : (terpakai / max).clamp(0.0, 1.0);
    final habis = ledger.sisaPorsi <= 0 || ledger.sisaPesanan <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.smartphone,
              size: 20,
              color: AppColors.textSecondary(theme.brightness),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Kuota harian perangkat', style: _judulCard(context)),
            ),
            Text(
              '$terpakai/$max porsi',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: habis
                    ? theme.colorScheme.error
                    : theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraksi.toDouble(),
            minHeight: 8,
            backgroundColor: AppColors.grayLight.withValues(alpha: 0.35),
            color: habis
                ? theme.colorScheme.error
                : AppColors.positiveFgFor(theme.brightness == Brightness.dark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sisa ${ledger.sisaPorsi} porsi • ${ledger.sisaPesanan}/'
          '${ledger.limits.maxPesananPerHari} pesanan hari ini.\n'
          'Batas dihitung per perangkat (${services.device.displayId}), '
          'bukan per akun — ganti akun tidak menambah kuota.',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ---------- Kuota produksi (per wajah, ditegakkan server) ----------

  Widget _kuotaProduksi(BuildContext context, ServicesHolder services) {
    final theme = Theme.of(context);
    final auth = services.auth;
    final face = services.face;
    final porsi = auth.weeklyPorsi;
    final pesanan = auth.weeklyPesanan;
    final maxPorsi = auth.maxPorsiPerWeek;
    final maxPesanan = auth.maxPesananPerWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.face_retouching_natural,
              size: 20,
              color: AppColors.textSecondary(theme.brightness),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Kuota mingguan per wajah', style: _judulCard(context)),
            ),
            if (porsi != null && pesanan != null)
              Text(
                '$porsi/$maxPorsi porsi',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.secondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!auth.isSignedIn)
          const Text(
            'Masuk dengan Google untuk melihat kuota wajah dan memesan.',
          )
        else if (auth.needsFaceVerification)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wajah belum terverifikasi. Satu wajah dibatasi beberapa '
                'porsi dan pesanan per minggu; server menegakkan batas ini '
                'secara independen.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: face == null
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FaceVerificationScreen(gateway: face),
                          ),
                        );
                        if (context.mounted) setState(() {});
                      },
                icon: const Icon(Icons.face_outlined),
                label: const Text('Verifikasi wajah'),
              ),
            ],
          )
        else
          Text(
            'Terpakai minggu ini: ${porsi ?? 0}/$maxPorsi porsi • '
            '${pesanan ?? 0}/$maxPesanan pesanan.\n'
            'Verifikasi wajah terakhir: '
            '${auth.faceVerifiedAt == null ? '-' : formatTanggal(auth.faceVerifiedAt!)}.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
      ],
    );
  }

  // ---------- Jumlah & tombol pesan ----------

  Widget _jumlahDanPesan(
    BuildContext context,
    FoodListing item,
    int qty,
    OrderGuard guard,
    int total,
    ServicesHolder services,
  ) {
    final theme = Theme.of(context);
    final maxQty = services.config.isProduction
        ? (item.quantityAvailable.clamp(0, 4))
        : _ledgerMaxQty(item, services);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Jumlah', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusInput),
                border: Border.all(
                  color: AppColors.cardBorder(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final v = int.tryParse(_qty.text) ?? 1;
                      setState(
                        () => _qty.text = (v > 1 ? v - 1 : 1).toString(),
                      );
                    },
                  ),
                  Text(
                    _qty.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final v = int.tryParse(_qty.text) ?? 0;
                      final naik = v + 1;
                      setState(() {
                        _qty.text = (naik > maxQty ? maxQty : naik).toString();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        if (maxQty < item.quantityAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Dibatasi kuota perangkat: maks $maxQty ${item.unit} '
              'untuk pesanan ini.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        const SizedBox(height: 10),
        ...guard.blockers.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    b,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...guard.warnings.map(
          (w) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: warnFgOf(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    w,
                    style: TextStyle(fontSize: 12, color: warnFgOf(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: guard.allowed ? () => _order(context, item, qty) : null,
          child: Text(
            total > 0
                ? 'Pesan & bayar ${formatRupiah(total)}'
                : 'Pesan sekarang (gratis)',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          services.config.isProduction
              ? 'Pemesanan nyata dibuat server dengan reservasi stok 10 menit. '
                    'Pembayaran diverifikasi webhook Midtrans — klien tidak '
                    'pernah menandai lunas. Kuota mingguan per wajah ditegakkan '
                    'server.'
              : total > 0
              ? 'Pembayaran diproses Midtrans bila server tersedia; jika tidak, '
                    'aplikasi memakai simulasi berlabel "tanpa uang nyata". '
                    'Kuota harian terpakai saat pesanan dibuat dan tidak kembali '
                    'walau dibatalkan.'
              : 'Gratis. Kuota harian tetap terpakai saat pesanan dibuat.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary(theme.brightness),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  int _ledgerMaxQty(FoodListing item, ServicesHolder services) {
    final sisaKuota = services.ledger.sisaPorsi;
    final byStock = item.quantityAvailable;
    var max = byStock < sisaKuota ? byStock : sisaKuota;
    if (max < 1) max = 1;
    return max;
  }

  // ---------- Aksi pesan ----------

  Future<void> _order(BuildContext context, FoodListing item, int qty) async {
    final session = SessionHolder.of(context);
    final store = DemoHolder.of(context);
    final services = ServicesHolder.of(context);

    // Mode produksi + sudah masuk Supabase: seluruh siklus pesanan lewat
    // server (create_order atomik + webhook pembayaran). Tidak menulis
    // apapun ke penyimpanan demo.
    if (services.config.isProduction) {
      await _orderProduksi(context, item, qty, session.displayName);
      return;
    }

    if (session.role == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (mounted) setState(() {});
      return;
    }
    if (session.role == 'penyedia') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun penyedia demo tidak memesan milik sendiri.'),
        ),
      );
      return;
    }

    final guard = guardOrder(
      listing: item,
      quantity: qty,
      providerStatus: services.providers.statusOf(item.providerId),
      usage: services.ledger.usage,
      limits: services.ledger.limits,
    );
    if (!guard.allowed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(guard.blockers.first)));
      return;
    }

    final code = store.placeOrder(item, qty);
    // Kuota perangkat dicatat di sini; sengaja TIDAK dikembalikan saat batal
    // (anti-penyalahgunaan pesan-batalkan berulang).
    await services.ledger.record(qty);

    if (!context.mounted) return;
    final order = store.myOrders.firstWhere((o) => o.pickupCode == code);
    final total = item.effectivePrice * qty;

    if (total > 0) {
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
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(lunas == true ? 'Pesanan dibayar' : 'Pesanan dibuat'),
          content: Text(
            'Kode pengambilan:\n$code\n\n'
            'Status bayar: ${lunas == true ? 'LUNAS' : 'belum dibayar'}.\n'
            'Status pesanan: menunggu konfirmasi penyedia.\n\n'
            'Kuota perangkat hari ini: ${services.ledger.porsiHariIni}/'
            '${services.ledger.limits.maxPorsiPerHari} porsi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pesanan dibuat (gratis)'),
          content: Text(
            'Kode pengambilan:\n$code\n\n'
            'Tunjukkan saat mengambil. Status: menunggu.\n\n'
            'Kuota perangkat hari ini: ${services.ledger.porsiHariIni}/'
            '${services.ledger.limits.maxPorsiPerHari} porsi.',
          ),
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

  /// Pesanan produksi: create_order (stok atomik + kuota server), lalu
  /// pembayaran berbayar lewat Midtrans via Edge Functions. Tidak ada
  /// simulasi stok/kuota di perangkat — semua keputusan ada di server.
  Future<void> _orderProduksi(
    BuildContext context,
    FoodListing item,
    int qty,
    String? namaPembeli,
  ) async {
    final services = ServicesHolder.of(context);
    final data = services.data;
    final auth = services.auth;

    if (!auth.isSignedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProductionLoginScreen(
            reason: 'Masuk dengan Google untuk membuat pesanan nyata.',
          ),
        ),
      );
      if (!context.mounted) return;
      if (auth.isSignedIn) {
        await _orderProduksi(context, item, qty, auth.displayName);
      }
      return;
    }

    if (auth.needsFaceVerification) {
      final face = services.face;
      if (face == null) {
        await showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Verifikasi wajah belum tersedia'),
            content: Text(
              'Build ini belum menghubungkan layanan verifikasi wajah. '
              'Pesanan produksi tidak dapat dibuat tanpa verifikasi server.',
            ),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceVerificationScreen(gateway: face),
        ),
      );
      await auth.refreshProfile();
      if (!context.mounted) return;
      if (auth.needsFaceVerification) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Wajah belum terverifikasi'),
            content: Text(
              'Pesanan belum dibuat. Selesaikan verifikasi wajah terlebih '
              'dahulu agar kuota mingguan dapat dihitung server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (qty < 1 || qty > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah porsi tidak wajar (1..4).')),
      );
      return;
    }
    if (item.quantityAvailable < qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok tidak mencukupi (tersisa ${item.quantityAvailable}).',
          ),
        ),
      );
      return;
    }

    final res = await data.createOrder(listingId: item.id, quantity: qty);
    if (!context.mounted) return;
    if (!res.success) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pesanan gagal dibuat'),
          content: Text(res.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await auth.refreshProfile();
    if (!context.mounted) return;
    final token = res.pickupCode ?? '';
    // Kulit DemoOrder untuk layar pembayaran — TIDAK masuk penyimpanan
    // demo; status asli dimiliki server.
    final kulit = DemoOrder(
      id: res.orderId ?? '',
      listing: item,
      quantity: qty,
      status: 'menunggu',
      pickupCode: token,
      createdAt: DateTime.now(),
    );
    final total = item.effectivePrice * qty;

    if (total > 0) {
      final lunas = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            order: kulit,
            payments: services.payments,
            deviceId: services.device.deviceId,
            namaPembeli: namaPembeli,
            produksi: true,
          ),
        ),
      );
      if (!context.mounted) return;
      final batas = res.reservationExpiresAt == null
          ? 'Tahan reservasi hingga 10 menit (kelola server).'
          : 'Tahan reservasi s/d ${formatTanggal(res.reservationExpiresAt!)}.';
      final info = lunas == true
          ? 'Status pembayaran ditetapkan webhook server (bukan UI ini).'
          : 'Pembayaran belum lunas — selesai-kan sebelum reservasi '
                'kedaluwarsa.';
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(lunas == true ? 'Pembayaran diproses' : 'Pesanan dibuat'),
          content: Text(
            'Kode pengambilan:\n$token\n\n'
            '$info\n$batas\n\n'
            'Kuota dihitung server — tidak ditampilkan dari perangkat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pesanan dibuat (gratis)'),
        content: Text(
          'Kode pengambilan:\n$token\n\n'
          'Tunjukkan saat mengambil. Reservasi stok menunggu konfirmasi '
          'penyedia; kedaluwarsa dikelola server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- Helper tampilan ----------

  TextStyle? _judulCard(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  Widget _card(BuildContext context, Widget child) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _pill(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
