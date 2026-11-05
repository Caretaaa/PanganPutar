import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/adaptive.dart';
import '../core/format.dart';
import '../core/pickup_rules.dart';
import '../core/security_rules.dart';
import '../core/tokens.dart';
import '../models/models.dart';
import '../services/demo_store.dart';
import '../services/pickup_service.dart';
import '../services/provider_registry.dart';
import '../services/contracts.dart';
import '../services/service_holder.dart' show StoreProfile;
import '../widgets/app_holders.dart';
import '../widgets/async_view.dart';
import '../widgets/qr_panel.dart';
import '../widgets/status_chips.dart';
import '../widgets/widgets.dart';
import 'scan_screen.dart';
import 'login_screen.dart';

/// ID penyedia untuk sesi demo (satu penyedia demo per perangkat).
const _demoProviderId = 'demo-penyedia';

/// Pintu masuk area penyedia (dari Akun & pengantar): Scaffold ber-AAppBar
/// yang membungkus [ProviderScreen].
class ProviderHubScreen extends StatelessWidget {
  const ProviderHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode penyedia')),
      body: AppContentFrame(
        child: ServicesHolder.of(context).config.isProduction
            ? const _ProviderProduksiView()
            : const ProviderScreen(),
      ),
    );
  }
}

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionHolder.of(context);
    final store = DemoHolder.of(context);
    final services = ServicesHolder.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([session, store, services.providers]),
      builder: (context, _) {
        if (session.role != 'penyedia' && session.role != 'admin') {
          return EmptyView(
            title: 'Khusus penyedia',
            description:
                'Halaman ini untuk penyedia. Masuk demo sebagai penyedia '
                'lewat tab Akun.',
            action: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(initialRole: 'penyedia'),
                ),
              ),
              child: const Text('Masuk sebagai penyedia'),
            ),
          );
        }
        final profil = services.providers.profileOf(_demoProviderId);
        final status = services.providers.statusOf(_demoProviderId);
        final terverifikasi = status == ProviderStatus.terverifikasi;
        final theme = Theme.of(context);

        return ListView(
          padding: const EdgeInsets.all(AppTokens.pagePadPhone),
          children: [
            _kartuVerifikasi(context, services.providers, profil, status),
            const SizedBox(height: AppTokens.gapSection),
            AdaptiveSectionHeader(
              title: Text(
                'Pesanan demo (${store.myOrders.length})',
                style: theme.textTheme.titleLarge,
              ),
              action: OutlinedButton.icon(
                onPressed: () => _pindaiTiketPembeli(context, store),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Pindai QR pembeli'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Periksa pembayaran, konfirmasi, lalu siapkan makanan. Demo satu perangkat dapat memainkan kedua peran; bukan sinkronisasi toko nyata.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            if (store.myOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Belum ada pesanan masuk pada perangkat demo ini.'),
              ),
            ...store.myOrders.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.gapCard),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.listing.title} × ${o.quantity}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Kode ${o.pickupCode} • '
                          '${statusPesananLabel[o.status] ?? o.status}',
                          style: theme.textTheme.bodySmall,
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              o.perluBayar
                                  ? 'Bayar: ${formatRupiah(o.total)}'
                                  : 'Gratis',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            paymentStatusChip(context, o.paymentStatus),
                            if (o.payment?.simulasi == true)
                              HonestyBadge.simulasi(context),
                          ],
                        ),
                        if (o.pickedUpAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Diambil ${formatTanggal(o.pickedUpAt!)}'
                              '${o.pickupVerified ? ' • terverifikasi QR' : ' • manual (tanpa QR)'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: o.pickupVerified
                                    ? Theme.of(context).colorScheme.secondary
                                    : AppColors.textSecondary(
                                        Theme.of(context).brightness,
                                      ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 4,
                          children: [
                            if (o.status == 'menunggu')
                              TextButton(
                                onPressed: () =>
                                    store.setOrderStatus(o.id, 'dikonfirmasi'),
                                child: const Text('Konfirmasi'),
                              ),
                            if (o.status == 'dikonfirmasi')
                              TextButton(
                                onPressed: () =>
                                    store.setOrderStatus(o.id, 'siap_diambil'),
                                child: const Text('Siap diambil'),
                              ),
                            if (o.status == 'siap_diambil')
                              TextButton(
                                onPressed: () => store.completeManually(o.id),
                                child: const Text('Selesai (manual)'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.gapSection),
            AdaptiveSectionHeader(
              title: Text(
                'Penawaran saya (${store.myListings.length})',
                style: theme.textTheme.titleLarge,
              ),
              action: FilledButton.icon(
                onPressed: terverifikasi
                    ? () => _showAdd(context, store, profil)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ),
            if (!terverifikasi)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Verifikasi toko terlebih dahulu untuk menerbitkan penawaran.',
                ),
              ),
            const SizedBox(height: 12),
            for (final l in store.myListings)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(l.title),
                    subtitle: Text(
                      'Sisa ${l.quantityAvailable} ${l.unit} • ${formatRupiah(l.effectivePrice)}',
                    ),
                    trailing: Text(l.status, style: theme.textTheme.labelSmall),
                  ),
                ),
              ),
            const SizedBox(height: AppTokens.gapSection),
            _kartuQrToko(context, profil, terverifikasi),
          ],
        );
      },
    );
  }

  Widget _kartuVerifikasi(
    BuildContext context,
    ProviderRegistry registry,
    ProviderProfile? profil,
    ProviderStatus status,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveSectionHeader(
              leading: const Icon(Icons.storefront_outlined, size: 20),
              title: Text(
                'Verifikasi toko',
                style: theme.textTheme.titleMedium,
              ),
              action: providerStatusChip(context, status),
            ),
            const SizedBox(height: 8),
            Text(
              profil == null
                  ? 'Lengkapi identitas toko sebelum menerbitkan penawaran. Verifikasi demo berupa konfirmasi lokal, bukan pemeriksaan usaha resmi atau jaminan keamanan pangan.'
                  : 'Toko: ${profil.namaToko} • ${profil.jenisUsaha}\n'
                        'Skor bukti: ${profil.skor}/100'
                        '${profil.catatan.isEmpty ? '' : '\n${profil.catatan.join('\n')}'}',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != ProviderStatus.terverifikasi)
                  FilledButton(
                    onPressed: () => _bukaFormVerifikasi(context, registry),
                    child: const Text('Ajukan verifikasi toko'),
                  ),
                if (status == ProviderStatus.menungguReview) ...[
                  OutlinedButton(
                    onPressed: () => registry.setStatus(
                      _demoProviderId,
                      ProviderStatus.terverifikasi,
                      catatan: const ['Disetujui admin (demo).'],
                    ),
                    child: const Text('Setujui (demo admin)'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuQrToko(
    BuildContext context,
    ProviderProfile? profil,
    bool terverifikasi,
  ) {
    final theme = Theme.of(context);
    final qr = StoreQr(
      providerId: _demoProviderId,
      namaToko: profil?.namaToko ?? 'Penyedia demo',
    ).encode();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AdaptiveSectionHeader(
              leading: const Icon(Icons.qr_code_2_outlined, size: 20),
              title: Text('QR toko', style: theme.textTheme.titleMedium),
              action: StatusChip(
                label: terverifikasi ? 'Aktif' : 'Belum terverifikasi',
                foreground: statusColors(
                  context,
                  positif: terverifikasi,
                  waspada: !terverifikasi,
                  gagal: false,
                ).fg,
                background: statusColors(
                  context,
                  positif: terverifikasi,
                  waspada: !terverifikasi,
                  gagal: false,
                ).bg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pajang QR ini di kasir/pintu toko. Pembeli memindainya saat '
              'tiba untuk mencocokkan ID toko dengan pesanannya. '
              'Kecocokan QR bukan bukti posisi fisik atau keamanan pangan. '
              'QR hanya memuat ID toko — tanpa data pribadi.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            QrPanel(
              data: qr,
              size: 180,
              redup: !terverifikasi,
              semanticLabel: 'QR toko untuk dipindai pembeli',
            ),
            if (!terverifikasi)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'QR tetap bisa dipindai, tetapi pembeli melihat peringatan '
                  'bahwa toko belum terverifikasi.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColors(
                      context,
                      positif: false,
                      waspada: true,
                      gagal: false,
                    ).fg,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Pemilik toko memindai tiket QR pembeli → tandai pengambilan selesai.
  Future<void> _pindaiTiketPembeli(
    BuildContext context,
    DemoStore store,
  ) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          judul: 'Pindai tiket pembeli',
          petunjuk:
              'Minta pembeli membuka Pesanan → Tampilkan QR. Arahkan kamera '
              'ke QR-nya: bila valid, pesanan langsung ditandai selesai dan '
              'terverifikasi.',
        ),
      ),
    );
    if (raw == null || !context.mounted) return;

    final hasil = PickupService(store).prosesScanTiketPembeli(
      raw: raw,
      scannerProviderId: _demoProviderId,
      // Demo satu perangkat: proses sebagai operator toko pemilik tiket.
      operatorDemo: true,
    );
    final isi = hasil.peringatan == null
        ? hasil.pesan
        : '${hasil.pesan}\n\n${hasil.peringatan}';
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          hasil.sukses ? 'Pengambilan terverifikasi' : 'QR tidak bisa diproses',
        ),
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

  Future<void> _bukaFormVerifikasi(
    BuildContext context,
    ProviderRegistry registry,
  ) async {
    final aplikasi = await Navigator.of(context).push<ProviderApplication>(
      MaterialPageRoute(builder: (_) => const _FormVerifikasiScreen()),
    );
    if (aplikasi == null || !context.mounted) return;
    final review = await registry.submit(_demoProviderId, aplikasi);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hasil verifikasi: ${providerStatusLabel(review.status)}'),
        content: Text(
          'Skor bukti: ${review.skor}/100\n\n'
          '${review.catatan.join('\n')}\n\n'
          'Catatan: demo offline memverifikasi otomatis bila bukti lengkap. '
          'Produksi: backend mencocokkan NIB ke sumber resmi dan meninjau '
          'foto/geotag sebelum menyetujui.',
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

  void _showAdd(
    BuildContext context,
    DemoStore store,
    ProviderProfile? profil,
  ) {
    final title = TextEditingController();
    final qty = TextEditingController(text: '10');
    final harga = TextEditingController(text: '0');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tambah penawaran (demo)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Nama makanan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: harga,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp, 0 = gratis)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Penawaran baru memakai kategori "lainnya", satuan porsi, '
                'alamat toko, dan waktu ambil otomatis +1–5 jam (batas demo).',
                style: Theme.of(dialogCtx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final nama = title.text.trim();
              final jumlah = int.tryParse(qty.text) ?? 0;
              final rupiah = int.tryParse(harga.text) ?? 0;
              if (nama.length < 3 || jumlah <= 0) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Nama minimal 3 karakter dan jumlah > 0.'),
                  ),
                );
                return;
              }
              final now = DateTime.now().toUtc();
              store.addListing(
                FoodListing(
                  id: 'demo-listing-${now.millisecondsSinceEpoch}',
                  providerId: _demoProviderId,
                  title: nama,
                  category: 'lainnya',
                  description: 'Penawaran demo dari penyedia terverifikasi.',
                  quantityTotal: jumlah,
                  quantityAvailable: jumlah,
                  unit: 'porsi',
                  priceRupiah: rupiah,
                  isFree: rupiah <= 0,
                  city: profil?.kota ?? 'Bandung',
                  district: '',
                  pickupAddress: profil?.alamat ?? 'Alamat toko demo',
                  pickupNote: 'Tunjukkan kode pesanan.',
                  pickupStart: now.add(const Duration(hours: 1)),
                  pickupEnd: now.add(const Duration(hours: 5)),
                  storageNote: 'Simpan suhu ruang maksimal 4 jam.',
                  allergenInfo: null,
                  status: 'tersedia',
                ),
              );
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

/// Dot warna kategori sebagai widget (untuk list penyedia).
extension on Color {
  Widget dot() => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(shape: BoxShape.circle, color: this),
  );
}

/// Form pengajuan verifikasi toko — semua bukti keberadaan toko wajib.
class _FormVerifikasiScreen extends StatefulWidget {
  const _FormVerifikasiScreen();

  @override
  State<_FormVerifikasiScreen> createState() => _FormVerifikasiScreenState();
}

const _jenisUsaha = [
  'Warung makan',
  'Toko roti / kue',
  'Restoran / katering',
  'Petani / kebun',
  'Toko kelontong',
  'Lainnya',
];

class _FormVerifikasiScreenState extends State<_FormVerifikasiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nomor = TextEditingController();
  final _telepon = TextEditingController();
  final _alamat = TextEditingController();
  final _kota = TextEditingController();
  String _jenis = _jenisUsaha.first;
  bool _adaFoto = false;
  bool _adaLokasi = false;

  @override
  void dispose() {
    _nama.dispose();
    _nomor.dispose();
    _telepon.dispose();
    _alamat.dispose();
    _kota.dispose();
    super.dispose();
  }

  void _kirim() {
    final aplikasi = ProviderApplication(
      namaToko: _nama.text,
      jenisUsaha: _jenis,
      nomorUsaha: _nomor.text,
      telepon: _telepon.text,
      alamat: _alamat.text,
      kota: _kota.text,
      adaFotoToko: _adaFoto,
      adaTitikLokasi: _adaLokasi,
    );
    final validasi = validateProviderApplication(aplikasi);
    if (validasi.valid && _formKey.currentState!.validate()) {
      Navigator.of(context).pop(aplikasi);
      return;
    }
    // Tampilkan error field via validasi murni (sumber aturan sama dengan registry).
    setState(() {}); // rebuild untuk pesan checkbox
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan verifikasi toko')),
      body: AppContentFrame(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.pagePadPhone),
            children: [
              Text(
                'Bukti wajib: identitas usaha, kontak aktif, alamat fisik, foto '
                'depan toko, dan titik lokasi. Pada demo ini bukti berupa '
                'konfirmasi pengguna; data palsu = penolakan permanen.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nama,
                decoration: const InputDecoration(labelText: 'Nama toko'),
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Nama toko minimal 3 karakter.'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _jenis,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis usaha'),
                items: _jenisUsaha
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _jenis = v ?? _jenisUsaha.first),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nomor,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'NIB / NPWP (angka)',
                  helperText:
                      '13–20 digit. Konfirmasi demo, bukan pemeriksaan resmi.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final digit = (v ?? '').replaceAll(RegExp(r'[\s.-]'), '');
                  if (digit.length < 13 || digit.length > 20) {
                    return 'NIB/NPWP harus 13–20 digit angka.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telepon,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor telepon'),
                validator: (v) {
                  final digit = (v ?? '').replaceAll(RegExp(r'[\s+()-]'), '');
                  if (digit.length < 9 || digit.length > 15) {
                    return 'Nomor telepon harus 9–15 digit.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _alamat,
                decoration: const InputDecoration(
                  labelText: 'Alamat toko',
                  helperText: 'Jalan, nomor, RT/RW, patokan.',
                ),
                validator: (v) => (v ?? '').trim().length < 10
                    ? 'Alamat minimal 10 karakter.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _kota,
                decoration: const InputDecoration(
                  labelText: 'Kota / kabupaten',
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 3 ? 'Kota wajib diisi.' : null,
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _adaFoto,
                onChanged: (v) => setState(() => _adaFoto = v ?? false),
                title: const Text(
                  'Foto depan toko sudah saya siapkan dan asli',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Demo: konfirmasi saja. Produksi: unggah foto + verifikasi geotag.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _adaLokasi,
                onChanged: (v) => setState(() => _adaLokasi = v ?? false),
                title: const Text(
                  'Lokasi toko sudah saya siapkan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Demo: konfirmasi saja. Produksi: koordinat GPS wajib.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              if (!_adaFoto || !_adaLokasi)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Lengkapi kedua konfirmasi demo. Ini bukan unggah foto atau pemeriksaan lokasi resmi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: warnFgOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _kirim,
                child: const Text('Kirim pengajuan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Mode produksi — dashboard penyedia
// Data riil dari Firebase: toko + penawaran milik pemilik masuk.
// Verifikasi & geotag tetap hasil proses server (tenant tidak bisa
// memodifikasi sendiri); pesan selalu jujur bila RLS menolak.
// ============================================================================

typedef _Dashboard = ({StoreProfile? toko, List<FoodListing> penawaran});

class _ProviderProduksiView extends StatefulWidget {
  const _ProviderProduksiView();

  @override
  State<_ProviderProduksiView> createState() => _ProviderProduksiViewState();
}

class _ProviderProduksiViewState extends State<_ProviderProduksiView> {
  PanganDataService get _data => ServicesHolder.of(context).data;
  late Future<_Dashboard> _future;

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  Future<_Dashboard> _muat() async {
    final toko = await _data.getMyStore();
    final penawaran = await _data.fetchMyListings();
    return (toko: toko, penawaran: penawaran);
  }

  void _reload() {
    setState(() {
      _future = _muat();
    });
  }

  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  String _statusLabel(String v) => switch (v) {
    'terverifikasi' => 'Terverifikasi',
    'menunggu_review' => 'Menunggu tinjauan',
    'ditolak' => 'Ditolak',
    _ => v,
  };

  FoodListing _denganStatus(FoodListing l, String status) => FoodListing(
    id: l.id,
    providerId: l.providerId,
    title: l.title,
    category: l.category,
    description: l.description,
    imageAsset: l.imageAsset,
    imageUrl: l.imageUrl,
    quantityTotal: l.quantityTotal,
    quantityAvailable: l.quantityAvailable,
    unit: l.unit,
    priceRupiah: l.priceRupiah,
    originalPriceRupiah: l.originalPriceRupiah,
    isFree: l.isFree,
    city: l.city,
    district: l.district,
    pickupAddress: l.pickupAddress,
    pickupNote: l.pickupNote,
    pickupStart: l.pickupStart,
    pickupEnd: l.pickupEnd,
    storageNote: l.storageNote,
    allergenInfo: l.allergenInfo,
    status: status,
  );

  Future<void> _pindaiTiket(StoreProfile? toko) async {
    if (toko == null) {
      _snack('Toko belum terdaftar — tidak ada pesanan yang bisa dinaikkan.');
      return;
    }
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          judul: 'Pindai tiket pembeli',
          petunjuk:
              'Minta pembeli menampilkan kode pengambilan (QR atau ketik '
              'manual di bawah bila kamera tidak tersedia). Server yang '
              'memutus: kode bekas, salah, atau pesanan tertutup ditolak.',
        ),
      ),
    );
    if (raw == null || !mounted) return;

    final token = tokenDariPindai(raw);
    if (token.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Bukan kode PanganPutar'),
          content: const Text(
            'Kode yang dipindai tidak berformat tiket pengambilan '
            'PanganPutar. Minta pembeli membuka Pesanan → tampilkan QR.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final hasil = await _data.claimPickup(storeId: toko.id, token: token);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(hasil.ok ? 'Pengambilan tercatat' : 'Tidak bisa diproses'),
        content: Text(hasil.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _reload();
  }

  Future<void> _tambah(StoreProfile? toko) async {
    if (toko == null) {
      _snack('Toko belum terdaftar. Daftar penyedia lewat tab Akun dulu.');
      return;
    }
    if (toko.verificationStatus != 'terverifikasi') {
      _snack(
        'Toko belum terverifikasi (${_statusLabel(toko.verificationStatus)}). '
        'Terbitkan penawaran hanya setelah toko terverifikasi.',
      );
      return;
    }
    final draft = await Navigator.of(context).push<FoodListing>(
      MaterialPageRoute(builder: (_) => const _FormProduksiListing()),
    );
    if (draft == null || !mounted) return;
    try {
      await _data.createListing(draft);
      _snack('Penawaran diterbitkan.');
      _reload();
    } catch (_) {
      _snack(
        'Penawaran belum dapat diterbitkan. Periksa akses toko atau hubungi pengelola layanan.',
      );
    }
  }

  Future<void> _tutup(FoodListing l) async {
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tutup penawaran?'),
        content: Text(
          '"${l.title}" tidak akan menerima pesanan baru. '
          'Pesanan yang sudah ada tetap harus diselesaikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Ya, tutup'),
          ),
        ],
      ),
    );
    if (lanjut != true) return;
    try {
      await _data.updateListing(_denganStatus(l, 'ditutup'));
      _snack('Penawaran ditutup.');
      _reload();
    } catch (_) {
      _snack(
        'Penawaran belum dapat ditutup. Status tidak diubah di perangkat; coba lagi atau hubungi pengelola layanan.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_Dashboard>(
      future: _future,
      onRetry: _reload,
      isEmpty: (d) => false, // toko kosong ditangani di builder
      emptyTitle: '',
      errorTitle: 'Gagal memuat dashboard penyedia',
      builder: (context, hasil) {
        final toko = hasil.toko;
        final theme = Theme.of(context);
        final terverifikasi = toko?.verificationStatus == 'terverifikasi';

        return ListView(
          padding: const EdgeInsets.all(AppTokens.pagePadPhone),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Mode produksi: data toko dan penawaran dibaca dari server. Antrean serta pengelolaan pesanan produksi belum tersedia di dashboard ini.',
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toko?.namaToko ?? 'Belum ada toko',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      toko == null
                          ? 'Daftar penyedia lewat tab Akun untuk menerbitkan '
                                'penawaran di sini.'
                          : '${toko.kota} • Status: '
                                '${_statusLabel(toko.verificationStatus)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (toko != null && !terverifikasi)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Penawaran hanya bisa diterbitkan setelah toko '
                          'terverifikasi. Koordinat toko di-set saat proses '
                          'verifikasi — tidak dari aplikasi ini.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: warnFgOf(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.gapSection),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Penawaran saya (${hasil.penawaran.length})',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _tambah(toko),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pindaiTiket(toko),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Pindai tiket pembeli'),
            ),
            const SizedBox(height: 16),
            if (toko != null && terverifikasi && hasil.penawaran.isEmpty)
              const EmptyView(
                title: 'Belum ada penawaran',
                description:
                    'Tekan Tambah untuk menerbitkan penawaran '
                    'pertama. Stok berkurang otomatis lewat pesanan.',
              )
            else
              ...hasil.penawaran.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.gapCard),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: dotForCategory(
                        l.category,
                        Theme.of(context).brightness,
                      ).dot(),
                      title: Text(
                        l.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Sisa ${l.quantityAvailable} ${l.unit} • '
                        '${formatRupiah(l.effectivePrice)} • '
                        'Ambil s/d '
                        '${l.pickupEnd.hour.toString().padLeft(2, '0')}:'
                        '${l.pickupEnd.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: l.status == 'tersedia'
                          ? TextButton(
                              onPressed: () => _tutup(l),
                              child: const Text('Tutup'),
                            )
                          : Text(l.status, style: theme.textTheme.labelSmall),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppTokens.gapSection),
            Text(
              'Stok berkurang hanya lewat pesanan yang dibuat lewat server '
              '(create_order) — dashboard ini tidak bisa mengubah angka '
              'stok, jadi feed pembeli tidak bisa dipalsukan.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

/// Form penerbitan penawaran produksi. Semua bidang dibatasi jujur:
/// foto belum didukung (kartu tampil tanpa gambar), kode toko berasal
/// dari profil toko — bukan dari penawaran.
class _FormProduksiListing extends StatefulWidget {
  const _FormProduksiListing();

  @override
  State<_FormProduksiListing> createState() => _FormProduksiListingState();
}

class _FormProduksiListingState extends State<_FormProduksiListing> {
  final _nama = TextEditingController();
  final _jumlah = TextEditingController(text: '1');
  final _harga = TextEditingController(text: '0');
  final _alergen = TextEditingController();
  final _simpan = TextEditingController();
  String _kategori = 'lainnya';
  DateTime _mulai = DateTime.now().add(const Duration(hours: 1));
  DateTime _berakhir = DateTime.now().add(const Duration(hours: 5));

  @override
  void dispose() {
    _nama.dispose();
    _jumlah.dispose();
    _harga.dispose();
    _alergen.dispose();
    _simpan.dispose();
    super.dispose();
  }

  Future<void> _pilihWaktu(bool mulai) async {
    final dasar = mulai ? _mulai : _berakhir;
    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dasar),
    );
    if (jam == null || !mounted) return;
    final hari = DateTime(dasar.year, dasar.month, dasar.day);
    final baru = hari.add(Duration(hours: jam.hour, minutes: jam.minute));
    setState(() {
      if (mulai) {
        _mulai = baru;
      } else {
        _berakhir = baru;
      }
    });
  }

  void _simpanDraft() {
    final nama = _nama.text.trim();
    final jumlah = int.tryParse(_jumlah.text) ?? 0;
    final rupiah = int.tryParse(_harga.text) ?? 0;
    if (nama.length < 3 || jumlah <= 0 || rupiah < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama minimal 3 karakter; jumlah > 0; harga ≥ 0.'),
        ),
      );
      return;
    }
    if (!_berakhir.isAfter(_mulai)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu pengambilan harus berakhir setelah mulai.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      FoodListing(
        id: '',
        providerId: '',
        title: nama,
        category: _kategori,
        quantityTotal: jumlah,
        quantityAvailable: jumlah,
        unit: 'porsi',
        priceRupiah: rupiah,
        isFree: rupiah <= 0,
        city: '',
        district: '',
        pickupAddress: '',
        pickupStart: _mulai.toUtc(),
        pickupEnd: _berakhir.toUtc(),
        storageNote: _simpan.text.trim().isEmpty ? null : _simpan.text.trim(),
        allergenInfo: _alergen.text.trim().isEmpty
            ? null
            : _alergen.text.trim(),
        status: 'tersedia',
      ),
    );
  }

  /// Pola jam HH:mm untuk tampilan waktu ambil.
  String _jam(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Penawaran baru')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        children: [
          TextField(
            controller: _nama,
            decoration: const InputDecoration(labelText: 'Nama makanan'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [
              for (final e in kategoriLabel.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _kategori = v ?? 'lainnya'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _jumlah,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah (porsi)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _harga,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga per porsi (Rp, 0 = gratis)',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pilihWaktu(true),
                  child: Text('Ambil mulai ${_jam(_mulai)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pilihWaktu(false),
                  child: Text('Berakhir ${_jam(_berakhir)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _simpan,
            decoration: const InputDecoration(
              labelText: 'Petunjuk simpan (opsional)',
              hintText: 'mis. simpan suhu ruang maksimal 4 jam',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _alergen,
            decoration: const InputDecoration(
              labelText: 'Informasi alergen (opsional)',
              hintText: 'mis. mengandung kacang',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Alamat ambil, nama toko, dan status verifikasi diambil dari '
            'profil toko di server. Foto belum didukung mode produksi: kartu '
            'tampil tanpa gambar — tidak memakai gambar contoh.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _simpanDraft,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Terbitkan'),
          ),
        ],
      ),
    );
  }
}
