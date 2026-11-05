import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/tokens.dart';
import '../widgets/app_holders.dart';
import 'login_screen.dart';
import 'provider_screen.dart';

/// Jalur khusus bergabung sebagai pedagang — dipisah dari login penerima
/// agar kedua alur tidak menumpuk di satu layar.
///
/// Kejujuran (DESIGN.md §4a dan §7): login saat ini lokal tanpa database.
/// Verifikasi toko ditinjau secara demo; akun tidak otomatis mendapat
/// peran atau status toko terverifikasi.
class MerchantJoinScreen extends StatelessWidget {
  final void Function(int tab)? onEnter;

  const MerchantJoinScreen({super.key, this.onEnter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = SessionHolder.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bergabung sebagai pedagang')),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final signedIn = session.isLoggedIn;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.pagePadPhone),
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: AppColors.positiveFgFor(
                      Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Salurkan kelebihan makanan dari toko Anda',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tiga langkah untuk menjadi penyedia. Alur ini terpisah '
                    'dari pendaftaran pembeli.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(theme.brightness),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _JoinStep(
                    nomor: '1',
                    judul: 'Masuk dengan nama',
                    isi: signedIn
                        ? 'Sesi Anda aktif: ${session.displayName}. Lanjut ke pengajuan toko.'
                        : 'Cukup nama — tanpa kata sandi atau email. Sesi '
                              'tersimpan di perangkat ini, bukan di database.',
                    tombolLabel: signedIn ? null : 'Masuk dengan nama',
                    onTekan: signedIn
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(
                                initialRole: 'penyedia',
                                onSignedIn: () {
                                  if (onEnter == null) return;
                                  Navigator.of(context).pop();
                                  onEnter!(0);
                                },
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _JoinStep(
                    nomor: '2',
                    judul: 'Ajukan verifikasi toko',
                    isi:
                        'Isi identitas usaha di Area Penyedia: nama toko, '
                        'jenis usaha, nomor usaha, telepon, alamat, dan kota.',
                    tombolLabel: 'Buka Area Penyedia',
                    onTekan: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProviderHubScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _JoinStep(
                    nomor: '3',
                    judul: 'Tunggu peninjauan',
                    isi:
                        'Status verifikasi ditinjau secara demo dan '
                        'tercatat lokal — bukan izin untuk transaksi '
                        'produksi.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Masuk tidak otomatis menjadi penyedia terverifikasi. '
                    'Penawaran hanya bisa diterbitkan setelah toko lolos '
                    'verifikasi.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(theme.brightness),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Satu langkah bergabung — kartu flat Riset Minimalis, tanpa shadow.
class _JoinStep extends StatelessWidget {
  final String nomor;
  final String judul;
  final String isi;
  final String? tombolLabel;
  final VoidCallback? onTekan;

  const _JoinStep({
    required this.nomor,
    required this.judul,
    required this.isi,
    this.tombolLabel,
    this.onTekan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.espresso,
                  ),
                  child: Text(
                    nomor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(judul, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                isi,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
            if (tombolLabel != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: FilledButton(
                  onPressed: onTekan,
                  child: Text(tombolLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
