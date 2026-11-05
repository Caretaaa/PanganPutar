import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/tokens.dart';
import '../services/contracts.dart';
import '../widgets/app_holders.dart';
import '../widgets/status_chips.dart';

/// Google sign-in for the production path (Firebase Auth).
///
/// The demo session is separate and never satisfies this screen: demo data
/// must not be presented as a real account, order, or payment.
class ProductionLoginScreen extends StatefulWidget {
  final PanganAuthService? auth;
  final String? reason;

  const ProductionLoginScreen({super.key, this.auth, this.reason});

  @override
  State<ProductionLoginScreen> createState() => _ProductionLoginScreenState();
}

class _ProductionLoginScreenState extends State<ProductionLoginScreen> {
  String? _error;

  PanganAuthService get _auth =>
      widget.auth ?? ServicesHolder.of(context).auth;

  Future<void> _signIn() async {
    setState(() => _error = null);
    try {
      final ok = await _auth.signInGoogle();
      if (!mounted) return;
      if (ok && _auth.isSignedIn) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Masuk dengan Google belum selesai.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = _auth;
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk akun')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Akun produksi',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const HonestyBadge(
                        label: 'FIREBASE',
                        icon: Icons.cloud_outlined,
                        positif: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.reason ??
                        'Masuk dengan Google untuk membuat pesanan nyata, '
                            'menyimpan riwayat, dan memverifikasi wajah untuk '
                            'kuota mingguan.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (!auth.isConfigured) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.initializationError ??
                          'Firebase belum dikonfigurasi pada build ini. '
                              'Mode demo tetap dapat dipakai.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: auth.busy || !auth.isReady ? null : _signIn,
                    icon: auth.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      auth.busy
                          ? 'Menghubungi Google…'
                          : 'Masuk dengan Google',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kami tidak menerima kata sandi. Google mengembalikan '
                    'identitas akun; PanganPutar hanya menyimpan nama, email, '
                    'foto profil, peran, dan status verifikasi wajah.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(theme.brightness),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.gapCard),
          Card(
            child: ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Ingin mencoba tanpa akun?'),
              subtitle: const Text(
                'Tutup layar ini lalu gunakan sesi demo di tab Akun. '
                'Pesanan demo tidak pernah dianggap pesanan nyata.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
