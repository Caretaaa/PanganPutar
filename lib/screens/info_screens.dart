import 'package:flutter/material.dart';

import '../core/business_rules.dart';
import '../core/tokens.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/async_view.dart';

class ImpactScreen extends StatefulWidget {
  final PanganPutarApi api;
  const ImpactScreen({super.key, required this.api});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  late Future<ImpactSummary?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ImpactSummary?> _load() => widget.api.fetchImpact();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AsyncView<ImpactSummary?>(
      future: _future,
      onRetry: () {
        setState(() {
          _future = _load();
        });
      },
      isEmpty: (v) => v == null,
      emptyTitle: 'Data dampak belum tersedia',
      emptyDescription:
          'Butuh server produksi untuk metrik tersalurkan. Nilai tampil '
          'nol sementara.',
      errorTitle: 'Gagal memuat dampak',
      builder: (context, impact) {
        final porsi = impact?.porsiTersalurkan ?? 0;
        final est = estimateImpact(porsi);
        return ListView(
          padding: const EdgeInsets.all(AppTokens.pagePadPhone),
          children: [
            Text(
              'DAMPAK • SDG 2 • 12 • 13',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dampak yang bisa dihitung.',
              style: theme.textTheme.headlineMedium?.copyWith(height: 1.05),
            ),
            const SizedBox(height: 4),
            Text(
              'Metrik dari data aplikasi. Estimasi selalu berlabel jelas.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('$porsi', 'Porsi'),
                    _stat('${impact?.pesananSelesai ?? 0}', 'Selesai'),
                    _stat('${impact?.penyediaAktif ?? 0}', 'Penyedia'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.gapCard),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimasi lingkungan (bukan klaim resmi)',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${est.estimasiKg.toStringAsFixed(1)} kg makanan • '
                      '${est.estimasiCo2eKg.toStringAsFixed(1)} kg CO2e',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rumus: kg = porsi × 0,4; CO2e = kg × 2,5. '
                      'Asumsi internal kasar — bukan sertifikasi emisi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.gapCard),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'SDG 2 Tanpa Kelaparan • SDG 12 Konsumsi Bertanggung Jawab • '
                  'SDG 13 Iklim: makanan berlebih disalurkan cepat, kurangi '
                  'sampah dan metana.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTokens.pagePadPhone),
      children: [
        Text(
          'PANDUAN',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Bantuan & keamanan pangan.',
          style: theme.textTheme.headlineMedium?.copyWith(height: 1.05),
        ),
        const SizedBox(height: 14),
        _bagian(
          context,
          'Cara memesan',
          '1. Cari di Jelajahi, cek lencana "Toko terverifikasi"\n'
              '2. Buka detail, cek keamanan & kuota harianmu\n'
              '3. Pesan, lalu bayar via Midtrans (QRIS, e-wallet, VA bank) '
              'bila berbayar — bila server tidak tersedia, aplikasi memakai '
              'simulasi berlabel tanpa uang nyata\n'
              '4. Buka Pesanan → Tampilkan QR, tunjukkan ke penyedia saat mengambil',
        ),
        _bagian(
          context,
          'QR pengambilan (dua arah)',
          '• PEMBELI punya QR tiket di Pesanan → Tampilkan QR\n'
              '• PEMILIK TOKO memindai QR tiket itu saat menyerahkan makanan → '
              'pesanan ditandai selesai & terverifikasi\n'
              '• Saat tiba, pembeli bisa memindai QR toko yang dipajang di '
              'kasir/pintu untuk memastikan lokasi pengambilan benar\n'
              '• QR bekas/dobel ditolak; tiket hanya berlaku untuk toko penerima '
              'pesanan\n'
              '• Kamera tidak tersedia? Selalu ada input kode manual',
        ),
        _bagian(
          context,
          'Keamanan & keadilan',
          '• Penyedia wajib lolos validasi toko (NIB/NPWP, alamat, foto, '
              'titik lokasi)\n'
              '• Batas harian: maks 4 porsi & 2 pesanan per hari, dikunci PER '
              'PERANGKAT — bikin banyak akun tidak menambah kuota\n'
              '• Kuota hangus saat pesanan dibatalkan\n'
              '• Pembayaran diproses Midtrans bila backend tersedia; aplikasi '
              'tidak menyimpan data kartu\n'
              '• Penyedia ditolak verifikasi = pesanannya diblokir',
        ),
        _bagian(
          context,
          'Keamanan pangan',
          '• Cek aroma/warna/kemasan\n'
              '• Perhatikan catatan simpan & alergen\n'
              '• Hangatkan sebelum makan\n'
              '• Jangan ambil bila lewat batas\n\n'
              'PanganPutar tidak menyatakan makanan aman hanya karena terdaftar.',
        ),
      ],
    );
  }

  Widget _bagian(BuildContext context, String judul, String isi) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.gapCard),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(judul, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                isi,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADMIN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text('Moderasi di web.', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Tinjau laporan & sembunyikan penawaran bermasalah lewat '
              'aplikasi web /admin. Moderasi tidak tersedia di aplikasi '
              'mobile ini.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Halaman statis: privasi & syarat ----------

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan privasi')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        children: [
          Text(
            _privacyText,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Syarat layanan')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        children: [
          Text(
            _termsText,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

const _privacyText =
    'PanganPutar menyimpan peran, nama tampilan demo, ID perangkat (hash), '
    'kuota harian, dan status verifikasi toko hanya di perangkat ini '
    '(SharedPreferences). ID perangkat dipakai untuk menegakkan batas harian '
    'per perangkat dan tidak dipakai untuk melacak iklan. MAC address tidak '
    'dibaca karena dilarang Android 10+ dan iOS. Pembayaran diproses Midtrans '
    'bila backend tersedia; aplikasi tidak menyimpan data kartu/e-wallet apa '
    'pun. Backend menerima data yang kamu kirim saat memesan (termasuk ID '
    'perangkat untuk kuota).';

const _termsText =
    'Makanan berlebih disalurkan apa adanya oleh penyedia. Selalu cek aroma, '
    'warna, kemasan, dan batas waktu ambil. PanganPutar tidak menyatakan '
    'makanan aman hanya karena terdaftar. Ambil tepat waktu dan patuhi '
    'catatan penyimpanan.\n\n'
    'Batas harian per perangkat: maksimal 4 porsi dan 2 pesanan per hari; '
    'kuota hangus saat pesanan dibatalkan (anti-penyalahgunaan). Penyedia '
    'wajib lolos validasi toko (NIB/NPWP, alamat, foto, lokasi); data palsu '
    'ditolak permanen.\n\n'
    'Pembayaran nyata hanya melalui backend Midtrans yang terkonfigurasi. '
    'Mode simulasi tidak memindahkan uang dan tidak mengikat.';
