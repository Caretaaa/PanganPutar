import 'package:flutter/material.dart';

import '../core/adaptive.dart';
import '../core/app_colors.dart';
import '../core/tokens.dart';
import '../core/theme_controller.dart';
import '../data/sample_data.dart';
import '../services/service_holder.dart' show AppConfig;
import '../widgets/listing_image.dart';
import 'login_screen.dart';
import 'merchant_join_screen.dart';

// Panduan singkat 3 langkah — hanya tampil saat pertama kali membuka aplikasi.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// Fungsi helper teks eyebrow kecil di atas judul slide.
Widget _eyebrow(BuildContext context, String text) => Text(
  text,
  style: TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.textSecondary(Theme.of(context).brightness),
  ),
);

/// State onboarding: PageView 3 slide + indikator titik + tombol.
/// (Perbaikan bug: build sebelumnya mengembalikan OnboardingScreen lagi
/// sehingga terjadi rekursi tanpa akhir.)
class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _halaman = 0;

  static const _slides = <(IconData, String, String, String)>[
    (
      Icons.search,
      'Langkah 1',
      'Temukan makanan berlebih',
      'Warung, toko roti, restoran, dan petani menyalurkan kelebihan stok '
          'dekat lokasimu — harga miring atau gratis.',
    ),
    (
      Icons.verified_user_outlined,
      'Langkah 2',
      'Periksa informasi sebelum memesan',
      'Baca alergen, penyimpanan, dan waktu ambil. Status toko bukan jaminan '
          'keamanan pangan. Demo dibatasi 4 porsi dan 2 pesanan per perangkat per hari.',
    ),
    (
      Icons.qr_code_2,
      'Langkah 3',
      'Pesan, lalu ambil di toko',
      'Pesanan gratis tidak perlu pembayaran. Pembayaran demo bertanda SIMULASI '
          'tidak memakai uang nyata. Tunggu konfirmasi toko sebelum mengambil.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terakhir = _halaman == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Lewati'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _halaman = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return _OnboardingSlide(
                    icon: s.$1,
                    eyebrow: s.$2,
                    title: s.$3,
                    desc: s.$4,
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _halaman ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _halaman
                          ? AppColors.forest
                          : AppColors.grayLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: terakhir
                      ? widget.onDone
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
                    ),
                  ),
                  child: Text(terakhir ? 'Mulai' : 'Lanjut'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Slide onboarding dengan desain minimalis — tanpa gradient, tanpa ambian glow.
class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String desc;
  const _OnboardingSlide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                icon,
                size: 56,
                color: AppColors.positiveFgFor(
                  theme.brightness == Brightness.dark,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(child: _eyebrow(context, eyebrow)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                desc,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Landing page — tampil sebelum pengguna masuk ke aplikasi utama.
class LandingScreen extends StatelessWidget {
  final void Function(int tab) onEnter;
  final ThemeController themeController;
  const LandingScreen({
    super.key,
    required this.onEnter,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: AppContentFrame(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              pagePadding(context).left,
              20,
              pagePadding(context).right,
              32,
            ),
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.forest,
                    ),
                    child: const Icon(
                      Icons.cached_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'PanganPutar',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  // Theme switch sederhana — pakai controller aplikasi.
                  Tooltip(
                    message: 'Ganti mode tampilan',
                    child: IconButton(
                      icon: const Icon(Icons.nightlight_outlined),
                      tooltip: 'Ganti mode tampilan',
                      onPressed: () => themeController.setDark(
                        !themeController.isDark(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LandingIntroduction(onEnter: onEnter),
              const SizedBox(height: 22),
              // Beri setiap manfaat lebar terukur agar deskripsinya membungkus.
              LayoutBuilder(
                builder: (context, constraints) {
                  const benefits = <_LandingStat>[
                    _LandingStat(
                      icon: Icons.eco_outlined,
                      title: 'Cari hemat',
                      desc: 'Roti, nasi kotak, dan paket segar dekat lokasimu.',
                    ),
                    _LandingStat(
                      icon: Icons.storefront_outlined,
                      title: 'Salurkan stok',
                      desc: 'Warung dan petani memposting kelebihan dalam hitungan menit.',
                    ),
                    _LandingStat(
                      icon: Icons.insights_outlined,
                      title: 'Ukur dampak',
                      desc: 'Lihat estimasi dampak saat data tersedia.',
                    ),
                  ];

                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        for (var i = 0; i < benefits.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _LandingStat(
                            icon: benefits[i].icon,
                            title: benefits[i].title,
                            desc: benefits[i].desc,
                            horizontal: true,
                          ),
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < benefits.length; i++) ...[
                        if (i > 0) const SizedBox(width: 20),
                        Expanded(child: benefits[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              // Cara kerja steps — tetap sederhana tanpa BezelCard
              _StepRow(
                number: '1',
                title: 'Cari penawaran',
                desc: 'Filter kategori dan kota di tab Jelajahi.',
              ),
              const SizedBox(height: 12),
              _StepRow(
                number: '2',
                title: 'Pesan & dapat kode',
                desc: 'Jumlah sesuai stok, kode ditunjukkan saat ambil.',
              ),
              const SizedBox(height: 12),
              _StepRow(
                number: '3',
                title: 'Ambil tepat waktu',
                desc: 'Datang sebelum batas, cek kondisi sebelum dibawa.',
              ),
              const SizedBox(height: 18),
              // Penutup jujur. Aksi utama sudah ada di bagian pembuka agar
              // tidak ada dua tombol yang menjanjikan hal sama.
              Divider(
                color: AppColors.cardBorder(
                  theme.brightness == Brightness.dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Data contoh di perangkat ini. Simulasi tanpa uang nyata.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(theme.brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingIntroduction extends StatelessWidget {
  final void Function(int) onEnter;
  const _LandingIntroduction({required this.onEnter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = sampleListings().first;
    final introduction = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Makanan berlebih,\nputaran kebaikan.',
          style: theme.textTheme.headlineLarge?.copyWith(
            height: 1.08,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Temukan penawaran gratis atau berbayar. Periksa informasinya, pesan, lalu ambil langsung di toko.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: AppColors.textSecondary(theme.brightness),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: () => onEnter(1),
              child: const Text('Jelajahi makanan'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MerchantJoinScreen(onEnter: onEnter),
                ),
              ),
              child: const Text('Jadi penyedia'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Bisa menjelajah tanpa masuk.', style: theme.textTheme.bodySmall),
        TextButton(
          onPressed: () {
            if (AppConfig.instance.isProduction) {
              onEnter(3);
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LoginScreen(onSignedIn: () => onEnter(0)),
              ),
            );
          },
          child: Text(
            AppConfig.instance.isProduction
                ? 'Informasi akses akun'
                : 'Masuk demo dengan nama',
          ),
        ),
      ],
    );
    final photo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingImage(item: item, height: 220),
        const SizedBox(height: 8),
        Text(
          'Contoh makanan di katalog demo',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary(theme.brightness),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [introduction, const SizedBox(height: 20), photo],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 6, child: introduction),
            const SizedBox(width: 32),
            Expanded(flex: 5, child: photo),
          ],
        );
      },
    );
  }
}

// Baris langkah — desain sederhana, tanpa BezelCard.
class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  const _StepRow({
    required this.number,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.positiveFgFor(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(desc, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// _LandingStat — widget statis untuk landing page
class _LandingStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool horizontal;
  const _LandingStat({
    required this.icon,
    required this.title,
    required this.desc,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        icon,
        color: AppColors.positiveFgFor(
          Theme.of(context).brightness == Brightness.dark,
        ),
        size: 20,
      ),
    );
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
        ),
        Text(
          desc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
        ),
      ],
    );

    if (horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 12),
          Expanded(child: copy),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [iconWidget, const SizedBox(height: 6), copy],
    );
  }
}
