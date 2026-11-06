import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/theme_controller.dart';
import '../core/tokens.dart';
import '../models/models.dart' show ImpactSummary;
import '../services/api_client.dart';
import '../services/contracts.dart';
import '../services/service_holder.dart';
import '../services/session.dart';
import '../widgets/app_holders.dart';
import '../widgets/status_chips.dart';
import 'face_verification_screen.dart';
import 'info_screens.dart';
import 'landing_screen.dart';
import 'provider_screen.dart';

class AccountScreen extends StatefulWidget {
  final SessionState session;
  final ThemeController? themeController;
  final PanganPutarApi? api;
  final bool isProduction;
  final PanganDataService? data;
  final PanganAuthService? auth;
  const AccountScreen({
    super.key,
    required this.session,
    this.themeController,
    this.api,
    this.isProduction = false,
    this.data,
    this.auth,
  });
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'penerima';
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Nama tampilan wajib diisi';
    if (t.length < 3) return 'Minimal 3 karakter';
    if (t.length > 40) return 'Maksimal 40 karakter';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final isProd = widget.isProduction;
    final services = ServicesHolder.of(context);
    final auth = widget.auth ?? services.auth;
    final data = widget.data ?? services.data;

    if (isProd) {
      return _buildProductionAccount(context, auth, data);
    }

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (s.isLoggedIn) {
          return _buildLoggedIn(context, s);
        }
        return _buildNotLoggedIn(context);
      },
    );
  }

  Widget _buildLoggedIn(BuildContext context, SessionState s) {
    final theme = Theme.of(context);
    final services = ServicesHolder.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTokens.pagePadPhone),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 20,
                      color: AppColors.textSecondary(
                        Theme.of(context).brightness,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sesi demo',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    HonestyBadge.demo(context),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.displayName ?? '-',
                  style: theme.textTheme.headlineSmall,
                ),
                Text('Peran: ${s.role}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  'Sesi ini demo lokal, bukan akun produksi — tanpa kata '
                  'sandi, OTP, atau sinkronisasi antarperangkat.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(
                      Theme.of(context).brightness,
                    ),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => s.signOut(),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.gapCard),
        _buildPintuPenyedia(context),
        const SizedBox(height: AppTokens.gapCard),
        _buildPreferensiTema(context),
        const SizedBox(height: AppTokens.gapCard),
        _buildPerangkatCard(context, services),
        const SizedBox(height: AppTokens.gapCard),
        _buildTautan(context),
      ],
    );
  }

  Widget _buildPerangkatCard(BuildContext context, ServicesHolder services) {
    final theme = Theme.of(context);
    final ledger = services.ledger;
    final maxPorsi = ledger.limits.maxPorsiPerHari;
    final maxPesanan = ledger.limits.maxPesananPerHari;
    return ListenableBuilder(
      listenable: Listenable.merge([services.device, ledger]),
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: AppColors.textSecondary(
                      Theme.of(context).brightness,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keamanan perangkat & kuota harian',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _baris(context, 'ID perangkat', services.device.displayId),
              _baris(context, 'Sumber identitas', services.device.sumber),
              _baris(
                context,
                'Kuota hari ini',
                '${ledger.porsiHariIni}/$maxPorsi porsi • '
                    '${ledger.pesananHariIni}/$maxPesanan pesanan',
              ),
              const SizedBox(height: 8),
              Text(
                'Batas harian dikunci per perangkat (ID di atas), bukan per '
                'akun. Membuat banyak akun di HP yang sama tidak menambah '
                'kuota. Aplikasi tidak membaca MAC address (dilarang Android '
                '10+/iOS).',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      await services.ledger.resetForDemo();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kuota demo direset untuk pengujian.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Reset kuota (demo)'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await services.providers.resetAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data verifikasi demo direset.'),
                          ),
                        );
                      }
                    },
                    child: const Text('Reset verifikasi (demo)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPintuPenyedia(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: Text('Mode penyedia', style: theme.textTheme.titleSmall),
        subtitle: const Text(
          'Verifikasi toko, terbitkan penawaran, proses pesanan, dan pajang '
          'QR toko.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProviderHubScreen())),
      ),
    );
  }

  Widget _buildPreferensiTema(BuildContext context) {
    final tc = widget.themeController;
    final theme = Theme.of(context);
    if (tc == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tampilan', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [
                  (ThemeMode.light, 'Terang', Icons.light_mode_outlined),
                  (ThemeMode.dark, 'Gelap', Icons.dark_mode_outlined),
                  (ThemeMode.system, 'Sistem', Icons.settings_suggest_outlined),
                ])
                  ChoiceChip(
                    selected: tc.mode == option.$1,
                    showCheckmark: false,
                    avatar: Icon(
                      option.$3,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                    label: Text(option.$2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    onSelected: (_) => tc.setMode(option.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tc.followsSystem
                  ? 'Mengikuti pengaturan sistem.'
                  : (tc.isDark(context)
                        ? 'Mode gelap aktif.'
                        : 'Mode terang aktif.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(Theme.of(context).brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTautan(BuildContext context) {
    void push(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.eco_outlined),
            title: const Text('Dampak & SDG'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(
              _InfoRoute(
                title: 'Dampak',
                body: ImpactScreen(api: widget.api ?? PanganPutarApi()),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Bantuan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                push(const _InfoRoute(title: 'Bantuan', body: HelpScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Panduan awal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(
              const _InfoRoute(title: 'Panduan awal', body: OnboardingProxy()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Kebijakan privasi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const PrivacyScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Syarat layanan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const TermsScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin'),
            subtitle: const Text('Moderasi lewat aplikasi web /admin.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                push(const _InfoRoute(title: 'Admin', body: AdminScreen())),
          ),
        ],
      ),
    );
  }

  Widget _baris(BuildContext context, String label, String nilai) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    final theme = Theme.of(context);
    final services = ServicesHolder.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.textSecondary(Theme.of(context).brightness),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Masuk / Daftar demo',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              HonestyBadge.demo(context),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih peranmu',
            style: theme.textTheme.headlineMedium?.copyWith(height: 1.05),
          ),
          const SizedBox(height: 4),
          Text(
            'Satu langkah agar kami menampilkan halaman yang tepat. Peran '
            'admin tidak tersedia di pendaftaran publik.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(Theme.of(context).brightness),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                controller: _name,
                validator: _validateName,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Nama tampilan',
                  hintText: 'cth. Sari Rahayu',
                  errorText: _nameError,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.gapCard),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                style: theme.textTheme.bodyMedium,
                selectedItemBuilder: (_) => const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Penerima'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Penyedia'),
                  ),
                ],
                decoration: const InputDecoration(labelText: 'Peran'),
                items: const [
                  DropdownMenuItem(
                    value: 'penerima',
                    child: Text('Penerima — mencari makanan'),
                  ),
                  DropdownMenuItem(
                    value: 'penyedia',
                    child: Text('Penyedia — warung/toko/petani'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'penerima'),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.gapSection),
          ElevatedButton(
            onPressed: () {
              final ok = _formKey.currentState?.validate() ?? false;
              if (!ok) return;
              widget.session.signInDemo(role: _role, name: _name.text.trim());
            },
            child: const Text('Masuk demo'),
          ),
          const SizedBox(height: AppTokens.gapCard),
          Text(
            'Batas harian dihitung per perangkat: ${services.device.displayId}. '
            'Status verifikasi toko & kuota tetap berlaku lintas akun.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(Theme.of(context).brightness),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTokens.gapCard),
          _buildPreferensiTema(context),
          const SizedBox(height: AppTokens.gapCard),
          _buildTautan(context),
        ],
      ),
    );
  }

  /// Production account view - Firebase Google profile + server data.
  Widget _buildProductionAccount(
    BuildContext context,
    PanganAuthService auth,
    PanganDataService data,
  ) {
    final theme = Theme.of(context);
    final services = ServicesHolder.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([auth, services.device, services.ledger]),
      builder: (context, _) {
        if (!auth.isSignedIn) {
          return _buildNotLoggedInProduction(context, auth);
        }

        final name = auth.displayName;
        final email = auth.email;
        final role = auth.role ?? 'penerima';

        return ListView(
          padding: const EdgeInsets.all(AppTokens.pagePadPhone),
          children: [
            // Profil Supabase
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 20,
                          color: AppColors.textSecondary(
                            Theme.of(context).brightness,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Akun Firebase',
                          style: theme.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (auth.busy)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      email ?? 'Akun Google',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    if (name != null)
                      Text('$name • $role', style: theme.textTheme.bodySmall),
                    if (auth.profileError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          auth.profileError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: auth.busy ? null : () => auth.signOut(),
                      child: const Text('Keluar dari akun Google'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.gapCard),

            // Face verification & weekly quota (server enforces)
            _buildFaceCard(context, auth),
            const SizedBox(height: AppTokens.gapCard),

            // Satu akun, dua pengalaman: penerima ↔ penyedia.
            _buildRoleSwitchCard(context, auth, role, name),
            const SizedBox(height: AppTokens.gapCard),

            // My Store (penyedia)
            _buildMyStoreCard(context, data, role),
            const SizedBox(height: AppTokens.gapCard),

            // Impact
            _buildImpactCard(context, data),
            const SizedBox(height: AppTokens.gapCard),

            _buildPreferensiTema(context),
            const SizedBox(height: AppTokens.gapCard),
            _buildTautan(context),
          ],
        );
      },
    );
  }

  Widget _buildNotLoggedInProduction(
    BuildContext context,
    PanganAuthService auth,
  ) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTokens.pagePadPhone),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text('Masuk akun produksi', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Gunakan Google untuk membuat pesanan nyata, menyimpan '
                  'riwayat, dan menghitung kuota mingguan per wajah. Sesi '
                  'demo tetap terpisah dan tidak membuka pesanan atau '
                  'pembayaran nyata.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(
                      Theme.of(context).brightness,
                    ),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!auth.isConfigured) ...[
                  const SizedBox(height: 10),
                  Text(
                    auth.initializationError ??
                        'Firebase belum dikonfigurasi pada build ini.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: auth.busy || !auth.isReady
                      ? null
                      : () async {
                          try {
                            await auth.signInGoogle();
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
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
                    auth.busy ? 'Menghubungi Google…' : 'Masuk dengan Google',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.gapCard),
        _buildPreferensiTema(context),
        const SizedBox(height: AppTokens.gapCard),
        _buildTautan(context),
      ],
    );
  }

  /// Satu akun Google bisa memakai dua pengalaman: penerima dan penyedia.
  /// Perpindahan peran tersimpan di profil Firestore sehingga nav shell
  /// langsung menampilkan Area Penyedia atau feed Beranda.
  Widget _buildRoleSwitchCard(
    BuildContext context,
    PanganAuthService auth,
    String role,
    String? name,
  ) {
    final theme = Theme.of(context);
    final isProvider = role == 'penyedia';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isProvider
                      ? Icons.storefront_outlined
                      : Icons.store_mall_directory_outlined,
                  size: 20,
                  color: AppColors.textSecondary(theme.brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  isProvider ? 'Mode Penyedia' : 'Mulai berjualan',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isProvider
                  ? 'Anda sedang memakai Area Penyedia. Beralih ke mode '
                        'penerima untuk menjelajah dan memesan makanan.'
                  : 'Buka Area Penyedia untuk menerbitkan penawaran, mengelola '
                        'stok, dan memindai QR pengambilan. Akun tetap sama.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: auth.busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await auth.updateProfile(
                          name: (name?.trim().isNotEmpty ?? false)
                              ? name!.trim()
                              : 'Pengguna',
                          role: isProvider ? 'penerima' : 'penyedia',
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isProvider
                                  ? 'Beralih ke mode penerima.'
                                  : 'Area Penyedia terbuka.',
                            ),
                          ),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('$error')),
                        );
                      }
                    },
              child: Text(
                isProvider ? 'Beralih ke Mode Penerima' : 'Buka Area Penyedia',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceCard(BuildContext context, PanganAuthService auth) {
    final theme = Theme.of(context);
    final face = ServicesHolder.of(context).face;
    final porsi = auth.weeklyPorsi ?? 0;
    final pesanan = auth.weeklyPesanan ?? 0;
    final maxPorsi = auth.maxPorsiPerWeek;
    final maxPesanan = auth.maxPesananPerWeek;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
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
                  child: Text(
                    'Verifikasi wajah & kuota mingguan',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (auth.needsFaceVerification)
                  const HonestyBadge(
                    label: 'BELUM',
                    icon: Icons.error_outline,
                    waspada: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              auth.needsFaceVerification
                  ? 'Wajah belum terverifikasi. Satu wajah dibatasi '
                        '$maxPorsi porsi dan $maxPesanan pesanan per minggu '
                        '(server yang menegakkan).'
                  : 'Terpakai minggu ini: $porsi/$maxPorsi porsi • '
                        '$pesanan/$maxPesanan pesanan.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: face == null || auth.busy
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
              label: Text(
                auth.needsFaceVerification
                    ? 'Verifikasi wajah'
                    : 'Perbarui verifikasi wajah',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStoreCard(
    BuildContext context,
    PanganDataService data,
    String role,
  ) {
    final theme = Theme.of(context);
    if (role != 'penyedia') return const SizedBox.shrink();

    return FutureBuilder<StoreProfile?>(
      future: data.getMyStore(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text('Memuat toko...', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Gagal memuat toko: ${snapshot.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          );
        }
        final store = snapshot.data;
        if (store == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(
                'Belum punya toko',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: const Text(
                'Ajukan verifikasi toko untuk mulai menjual.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProviderHubScreen()),
              ),
            ),
          );
        }
        return Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(store.namaToko, style: theme.textTheme.titleSmall),
            subtitle: Text('${store.kota} • ${store.verificationStatus}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProviderHubScreen()),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImpactCard(BuildContext context, PanganDataService data) {
    final theme = Theme.of(context);
    return FutureBuilder<ImpactSummary?>(
      future: data.fetchImpact(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final impact = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 20,
                      color: AppColors.textSecondary(
                        Theme.of(context).brightness,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Dampak pribadi', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ImpactStat(
                        icon: Icons.restaurant,
                        value: '${impact.porsiTersalurkan}',
                        label: 'Porsi diselamatkan',
                      ),
                    ),
                    Expanded(
                      child: _ImpactStat(
                        icon: Icons.scale,
                        value: '${impact.estimasiKg.toStringAsFixed(1)} kg',
                        label: 'Makanan',
                      ),
                    ),
                    Expanded(
                      child: _ImpactStat(
                        icon: Icons.cloud_outlined,
                        value: '${impact.estimasiCo2eKg.toStringAsFixed(1)} kg',
                        label: 'CO₂e dihindari',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Berdasarkan pesanan selesai. Estimasi: 1 porsi = 0.3kg, 1kg = 2.5kg CO₂e.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(
                      Theme.of(context).brightness,
                    ),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _ImpactStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.positiveFgFor(
            Theme.of(context).brightness == Brightness.dark,
          ),
          size: 28,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Scaffold statis berjudul untuk layar bantuan dari Akun.
class _InfoRoute extends StatelessWidget {
  final String title;
  final Widget body;
  const _InfoRoute({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

/// Onboarding ulang dari Akun: panduan 3 langkah tanpa menandai first-run.
class OnboardingProxy extends StatelessWidget {
  const OnboardingProxy({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(onDone: () => Navigator.of(context).pop());
  }
}
