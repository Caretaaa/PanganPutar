import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';
import '../core/adaptive.dart';
import '../core/format.dart';
import '../core/tokens.dart';
import '../models/payment.dart';
import '../services/demo_store.dart';
import '../services/contracts.dart';
import '../widgets/status_chips.dart';

/// Layar pembayaran dengan Midtrans.
///
/// Dua jalur:
/// 1. Backend terjangkau → buat sesi Snap di backend, lalu tampilkan halaman
///    Snap (WebView di Android/iOS/macOS, atau buka browser di platform lain)
///    sambil memantau status ke backend secara berkala.
/// 2. Backend tidak terjangkau → MODE SIMULASI jelas berlabel "tanpa uang
///    nyata" agar demo tetap berjalan offline.
///
/// Pop dengan `true` bila pembayaran lunas.
class PaymentScreen extends StatefulWidget {
  final DemoOrder order;

  /// Demo: pesanan bertinggal di [DemoStore]. Produksi: status pembayaran
  /// dimiliki SERVER (webhook Midtrans) — [store] boleh null dan tidak ada
  /// tulisan lokal.
  final DemoStore? store;
  final PaymentGateway payments;
  final String? deviceId;
  final String? namaPembeli;
  final bool produksi;

  const PaymentScreen({
    super.key,
    required this.order,
    this.store,
    required this.payments,
    this.deviceId,
    this.namaPembeli,
    this.produksi = false,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _Fase { ringkasan, membuatSesi, snap, simulasi, selesai, gagal }

bool _bisaWebView() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

const _metodeSimulasi = <(String, String)>[
  ('qris', 'QRIS (semua e-wallet)'),
  ('gopay', 'GoPay'),
  ('ovo', 'OVO'),
  ('dana', 'DANA'),
  ('shopeepay', 'ShopeePay'),
  ('va_bca', 'VA BCA'),
  ('va_bni', 'VA BNI'),
];

class _PaymentScreenState extends State<PaymentScreen> {
  _Fase _fase = _Fase.ringkasan;
  SnapSession? _sesi;
  WebViewController? _web;
  Timer? _poll;
  String _metode = 'qris';
  String? _pesanGagal;
  double _progresWeb = 0;
  bool _sedangCek = false;

  int get _total => widget.order.total;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _mulaiPembayaran() async {
    setState(() {
      _fase = _Fase.membuatSesi;
      _pesanGagal = null;
    });
    try {
      final sesi = await widget.payments.createSnap(
        orderId: widget.order.id,
        grossAmount: _total,
        items: [
          PaymentItem(
            id: widget.order.listing.id,
            nama: widget.order.listing.title,
            harga: widget.order.listing.effectivePrice,
            jumlah: widget.order.quantity,
          ),
        ],
        namaPembeli: widget.namaPembeli,
        deviceId: widget.deviceId,
      );
      if (!mounted) return;
      _sesi = sesi;
      if (sesi.simulasi) {
        setState(() => _fase = _Fase.simulasi);
        return;
      }
      if (_bisaWebView()) {
        _web = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (p) {
                if (mounted) setState(() => _progresWeb = p / 100);
              },
              onWebResourceError: (e) {
                debugPrint('WebView error: ${e.description}');
              },
            ),
          )
          ..loadRequest(Uri.parse(sesi.redirectUrl));
      }
      setState(() => _fase = _Fase.snap);
      _startPoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pesanGagal = error.toString();
        _fase = _Fase.gagal;
      });
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _cekStatus());
  }

  Future<void> _cekStatus() async {
    if (_sedangCek) return;
    _sedangCek = true;
    PaymentRecord? rec;
    try {
      rec = await widget.payments.checkStatus(
        widget.order.id,
        grossAmount: _total,
        deviceId: widget.deviceId,
      );
    } catch (_) {
      // Polling is best-effort; the webhook owns the final state.
      rec = null;
    } finally {
      _sedangCek = false;
    }
    if (!mounted || rec == null) return;
    if (rec!.status == PaymentStatus.dibayar) {
      _selesaikan(rec);
    } else if (rec!.status == PaymentStatus.gagal ||
        rec!.status == PaymentStatus.kedaluwarsa) {
      _poll?.cancel();
      setState(() {
        _pesanGagal = paymentStatusLabel[rec!.status];
        _fase = _Fase.gagal;
      });
      // Produksi: status final di server; JANGAN menulis lokal (webhook
      // Midtrans yang memutus — klien hanya memantau).
      if (!widget.produksi) {
        widget.store?.markPayment(widget.order.id, rec);
      }
    }
  }

  void _selesaikan(PaymentRecord rec) {
    _poll?.cancel();
    if (!widget.produksi) {
      widget.store?.markPayment(widget.order.id, rec);
    }
    setState(() => _fase = _Fase.selesai);
  }

  Future<void> _bukaDiBrowser() async {
    final url = _sesi?.redirectUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selesaikan pembayaran di browser, lalu kembali dan cek status.',
          ),
        ),
      );
    }
  }

  void _simulasikan(bool lunas) {
    final now = DateTime.now();
    final rec = PaymentRecord(
      orderId: widget.order.id,
      grossAmount: _total,
      status: lunas ? PaymentStatus.dibayar : PaymentStatus.gagal,
      metode: _metode,
      transaksiId: 'SIM-${now.millisecondsSinceEpoch}',
      dibayarPada: lunas ? now : null,
      simulasi: true,
    );
    if (lunas) {
      _selesaikan(rec);
    } else {
      if (!widget.produksi) {
        widget.store?.markPayment(widget.order.id, rec);
      }
      setState(() {
        _pesanGagal = 'Pembayaran simulasi ditandai gagal.';
        _fase = _Fase.gagal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_fase) {
          _Fase.ringkasan || _Fase.membuatSesi => 'Pembayaran',
          _Fase.snap => 'Midtrans',
          _Fase.simulasi => 'Simulasi pembayaran',
          _Fase.selesai => 'Pembayaran selesai',
          _Fase.gagal => 'Pembayaran gagal',
        }),
      ),
      body: AppContentFrame(
        child: switch (_fase) {
          _Fase.ringkasan => _buildRingkasan(theme),
          _Fase.membuatSesi => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Memeriksa layanan pembayaran…'),
              ],
            ),
          ),
          _Fase.snap => _buildSnap(theme),
          _Fase.simulasi => _buildSimulasi(theme),
          _Fase.selesai => _buildSelesai(theme),
          _Fase.gagal => _buildGagal(theme),
        },
      ),
    );
  }

  Widget _buildRingkasan(ThemeData theme) {
    final o = widget.order;
    return ListView(
      padding: const EdgeInsets.all(AppTokens.pagePadPhone),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ringkasan pesanan', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _baris(
                  theme,
                  '${o.listing.title} × ${o.quantity}',
                  formatRupiah(o.listing.effectivePrice * o.quantity),
                ),
                _baris(theme, 'Kode ambil', o.pickupCode),
                _baris(theme, 'Jalur', 'Diperiksa saat dilanjutkan'),
                const Divider(height: 24),
                _baris(theme, 'Total', formatRupiah(_total), tebal: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Pembayaran diproses Midtrans (QRIS, e-wallet, VA bank, kartu) '
              'bila backend tersedia. PanganPutar tidak menyimpan data kartu '
              'apa pun. Bila server pembayaran tidak terjangkau, aplikasi '
              'beralih ke mode simulasi berlabel "tanpa uang nyata" untuk demo.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _mulaiPembayaran,
          child: Text('Lanjut bayar ${formatRupiah(_total)}'),
        ),
      ],
    );
  }

  Widget _baris(
    ThemeData theme,
    String label,
    String nilai, {
    bool tebal = false,
  }) {
    final gaya = tebal
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: gaya)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(nilai, style: gaya, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildSnap(ThemeData theme) {
    final url = _sesi?.redirectUrl ?? '';
    return Column(
      children: [
        if (_progresWeb < 1)
          LinearProgressIndicator(value: _progresWeb, minHeight: 2),
        Expanded(
          child: _web != null
              ? WebViewWidget(controller: _web!)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'WebView tidak tersedia di perangkat ini. '
                          'Lanjutkan pembayaran di browser.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _bukaDiBrowser,
                          child: const Text('Buka di browser'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  'Setelah membayar, status diperbarui otomatis dari server.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _cekStatus,
                      child: const Text('Cek status'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
                if (!_bisaWebView() && url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _bukaDiBrowser,
                    child: const Text('Buka halaman pembayaran'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulasi(ThemeData theme) {
    final va = '8808 ${widget.order.pickupCode.replaceAll('PP-', '')}';
    final dark = theme.brightness == Brightness.dark;
    final warnBg = dark ? AppColors.warnBgDark : AppColors.warnBgLight;
    final warnFg = dark ? AppColors.warnFgDark : AppColors.warnFgLight;
    return ListView(
      padding: const EdgeInsets.all(AppTokens.pagePadPhone),
      children: [
        // Tanda kejujuran: simulasi ≠ transaksi nyata.
        Card(
          color: warnBg,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODE SIMULASI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: warnFg,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                HonestyBadge.simulasi(context),
                const SizedBox(height: 8),
                Text(
                  'Server pembayaran tidak terjangkau. Tidak ada uang nyata '
                  'yang berpindah; nomor/QR di bawah hanya ilustrasi, bukan '
                  'instruksi transfer. Di produksi, halaman Snap Midtrans '
                  'akan terbuka di sini.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: warnFg,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih metode (simulasi)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _metode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Metode simulasi',
                  ),
                  items: [
                    for (final m in _metodeSimulasi)
                      DropdownMenuItem(value: m.$1, child: Text(m.$2)),
                  ],
                  onChanged: (v) => setState(() => _metode = v ?? 'qris'),
                ),
                const Divider(height: 24),
                if (_metode == 'qris')
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_2, size: 120),
                        SizedBox(height: 6),
                        Text(
                          'QR ilustrasi, bukan kode pembayaran. Gunakan tombol simulasi di bawah.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _metode.startsWith('va')
                            ? 'Nomor Virtual Account (simulasi)'
                            : 'Kode bayar (simulasi)',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        va,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                HonestyBadge.simulasi(context),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _simulasikan(false),
                      child: const Text('Simulasikan gagal'),
                    ),
                    ElevatedButton(
                      onPressed: () => _simulasikan(true),
                      child: Text('Bayar ${formatRupiah(_total)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelesai(ThemeData theme) {
    final p = widget.order.payment;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 72,
                color: AppColors.positiveFgFor(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pembayaran lunas',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(formatRupiah(_total), style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              if (p?.simulasi == true) ...[
                HonestyBadge.simulasi(context),
                const SizedBox(height: 10),
              ],
              Text(
                'Metode: ${p?.metode ?? '-'}\n'
                'Ref: ${p?.transaksiId ?? '-'}\n\n'
                'Tunjukkan kode ${widget.order.pickupCode} saat mengambil '
                'makanan.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Selesai'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGagal(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 72,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _pesanGagal ?? 'Pembayaran gagal.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Tutup'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _fase = _Fase.ringkasan);
                    },
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
