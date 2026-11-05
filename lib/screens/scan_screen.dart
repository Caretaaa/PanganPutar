import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/tokens.dart';

/// Web dan platform native yang menyediakan kamera untuk mobile_scanner.
bool supportsScannerCamera({
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    isWeb ||
    platform == TargetPlatform.android ||
    platform == TargetPlatform.iOS ||
    platform == TargetPlatform.macOS;

/// Layar pemindai QR/barcode dengan jalur cadangan ketik-manual.
///
/// Mengembalikan teks hasil pindai lewat `Navigator.pop<String>` (`null`
/// bila pengguna membatalkan). Di platform tanpa kamera (mis. Linux) atau
/// lingkungan tes, gunakan [gunakanKamera] = false — input manual tetap ada.
class ScanScreen extends StatefulWidget {
  final String judul;
  final String petunjuk;
  final bool gunakanKamera;

  const ScanScreen({
    super.key,
    required this.judul,
    required this.petunjuk,
    this.gunakanKamera = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manual = TextEditingController();
  bool _selesai = false;

  bool get _kameraAktif =>
      widget.gunakanKamera &&
      supportsScannerCamera(isWeb: kIsWeb, platform: defaultTargetPlatform);

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _kembali(String? raw) {
    if (_selesai) return;
    final teks = (raw ?? '').trim();
    if (teks.isEmpty) return;
    _selesai = true;
    Navigator.of(context).pop(teks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.judul)),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.pagePadPhone),
        children: [
          if (_kameraAktif)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              child: SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        for (final b in capture.barcodes) {
                          final raw = b.rawValue;
                          if (raw != null && raw.trim().isNotEmpty) {
                            _kembali(raw);
                            return;
                          }
                        }
                      },
                      errorBuilder: (context, error) =>
                          _kameraTidakTersedia(context),
                      placeholderBuilder: (context) => Container(
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Kamera tidak dipakai di perangkat ini.\n'
                    'Gunakan kode manual di bawah.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            widget.petunjuk,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _manual,
            decoration: const InputDecoration(
              labelText: 'Kode / tautan manual',
              helperText:
                  'Cadangan bila kamera tidak bisa memindai. Tempel isi QR '
                  'atau ketik kode pengambilan.',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: _kembali,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _kembali(_manual.text),
            child: const Text('Proses kode'),
          ),
        ],
      ),
    );
  }

  Widget _kameraTidakTersedia(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 40,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 10),
              Text(
                'Kamera tidak tersedia / izin ditolak.\n'
                'Gunakan kode manual di bawah.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
