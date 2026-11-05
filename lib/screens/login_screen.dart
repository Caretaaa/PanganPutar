import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/tokens.dart';
import '../services/session.dart';
import '../widgets/app_holders.dart';

/// Layar masuk lokal — SEMENTARA tanpa database.
/// Cukup nama (dan peran untuk menampilkan halaman yang tepat). Sesi
/// disimpan di perangkat ini saja melalui [SessionState]; tidak ada akun
/// yang dikirim/dibuat di server. Tanpa verifikasi email/OTP/Google.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onSignedIn;
  final String initialRole;
  const LoginScreen({
    super.key,
    this.onSignedIn,
    this.initialRole = 'penerima',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  late String _role;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _signIn(SessionState session) async {
    final name = _name.text.trim();
    if (name.length < 3 || name.length > 40) {
      setState(() => _error = 'Nama harus berisi 3–40 karakter.');
      return;
    }
    setState(() => _error = null);
    await session.signInDemo(role: _role, name: name);
    if (!mounted) return;
    _finish();
  }

  void _finish() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    widget.onSignedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = SessionHolder.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masuk / Daftar'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (session.isLoggedIn && session.role != _role) {
            return _buildRoleSwitch(theme, session);
          }
          if (session.isLoggedIn) return _buildSignedIn(theme, session);
          return _buildForm(theme, session);
        },
      ),
    );
  }

  Widget _buildForm(ThemeData theme, SessionState session) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.pagePadPhone,
            16,
            AppTokens.pagePadPhone,
            32,
          ),
          children: [
            Icon(
              Icons.cached_rounded,
              size: 56,
              color: AppColors.positiveFgFor(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Masuk ke PanganPutar',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Cukup nama — tanpa kata sandi, email, atau OTP. Sesi hanya '
              'tersimpan di perangkat ini dan tidak dikirim ke database.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(theme.brightness),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              _Banner(text: _error!, color: theme.colorScheme.error),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(session),
              decoration: const InputDecoration(
                labelText: 'Nama tampilan',
                hintText: 'cth. Sari Rahayu',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pilih peran', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'penerima',
                  label: Text('Penerima'),
                  icon: Icon(Icons.shopping_basket_outlined),
                ),
                ButtonSegment(
                  value: 'penyedia',
                  label: Text('Penyedia'),
                  icon: Icon(Icons.storefront_outlined),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _signIn(session),
                child: const Text('Masuk'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Riwayat pesanan disimpan di perangkat ini dan bertahan saat '
              'aplikasi ditutup. Verifikasi toko untuk penyedia masih '
              'ditinjau secara demo.',
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
  }

  Widget _buildSignedIn(ThemeData theme, SessionState session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.positiveFgFor(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            const SizedBox(height: 16),
            Text('Sudah masuk', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(session.displayName ?? '-', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Peran: ${session.role}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _finish,
              child: const Text('Lanjutkan ke aplikasi'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => session.signOut(),
              child: const Text('Masuk dengan nama lain'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSwitch(ThemeData theme, SessionState session) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ganti peran demo?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Anda masuk sebagai ${session.role}. Untuk membuka halaman ini, gunakan peran $_role. Kuota dan pesanan perangkat tidak direset.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text('Gunakan peran $_role?'),
                    content: const Text(
                      'Ini hanya mengganti peran sesi demo. Kuota perangkat tetap berlaku.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Ganti peran'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                await session.signInDemo(
                  role: _role,
                  name: session.displayName ?? 'Pengguna demo',
                );
                if (mounted) _finish();
              },
              child: Text('Lanjut sebagai $_role'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Kembali tanpa mengganti'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
