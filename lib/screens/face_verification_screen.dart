import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_colors.dart';
import '../core/tokens.dart';
import '../services/contracts.dart';
import '../widgets/app_holders.dart';
import '../widgets/status_chips.dart';

/// Selfie check used by the weekly face quota.
///
/// Honesty notes shown to the user:
/// - the selfie is sent to the server only for the check;
/// - the server keeps a face reference/template, not the photo;
/// - this build does not yet include certified liveness detection.
class FaceVerificationScreen extends StatefulWidget {
  final FaceVerificationGateway? gateway;
  final VoidCallback? onVerified;

  const FaceVerificationScreen({super.key, this.gateway, this.onVerified});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  final _picker = ImagePicker();
  bool _consent = false;
  bool _busy = false;
  Uint8List? _preview;
  String? _error;
  FaceVerificationResult? _result;

  FaceVerificationGateway? get _gateway =>
      widget.gateway ?? ServicesHolder.of(context).face;

  Future<void> _pick(ImageSource source) async {
    if (!_consent) {
      setState(
        () => _error = 'Setujui pemrosesan data wajah dulu sebelum selfie.',
      );
      return;
    }
    setState(() => _error = null);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _preview = bytes);
      await _submit(bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Kamera/galeri tidak dapat dibuka. Periksa izin aplikasi. '
            '(${error.runtimeType})';
      });
    }
  }

  Future<void> _submit(Uint8List bytes) async {
    final gateway = _gateway;
    if (gateway == null) {
      setState(() {
        _error =
            'Verifikasi wajah belum tersedia. Jalur Firebase belum '
            'dikonfigurasi pada build ini.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await gateway.verifyFace(bytes);
      if (!mounted) return;
      setState(() => _result = result);
      await ServicesHolder.of(context).auth.refreshProfile();
      widget.onVerified?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi wajah')),
      body: ListView(
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
                      const Icon(Icons.face_retouching_natural, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Satu wajah, kuota mingguan',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const HonestyBadge(
                        label: 'SERVER',
                        icon: Icons.cloud_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Kuota dihitung per wajah yang diverifikasi server, bukan '
                    'per perangkat. Satu wajah hanya dapat mengambil beberapa '
                    'porsi dan pesanan dalam satu minggu. Membuat akun baru '
                    'tidak menambah kuota.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  _baris(
                    theme,
                    'Batas bawaan',
                    '4 porsi • 2 pesanan / minggu',
                  ),
                  _baris(
                    theme,
                    'Zona waktu',
                    'Asia/Jakarta (Senin–Minggu)',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.gapCard),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Persetujuan', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _consent = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Saya menyetujui selfie diproses untuk verifikasi '
                      'identitas dan penegakan kuota mingguan.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Foto tidak disimpan sebagai gambar. Server menyimpan '
                    'referensi wajah (template) dan menghapusnya saat akun '
                    'dihapus atau persetujuan ditarik. Deteksi liveness '
                    'tersertifikasi belum aktif pada build ini; jangan gunakan '
                    'untuk verifikasi identitas resmi.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(
                        Theme.of(context).brightness,
                      ),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_preview != null) ...[
            const SizedBox(height: AppTokens.gapCard),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusPhoto),
              child: Image.memory(
                _preview!,
                height: 180,
                fit: BoxFit.cover,
                semanticLabel: 'Pratinjau selfie',
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
          const SizedBox(height: AppTokens.gapSection),
          if (_result != null)
            _HasilVerifikasi(result: _result!)
          else ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_front_outlined),
              label: Text(_busy ? 'Memeriksa wajah…' : 'Ambil selfie'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pilih dari galeri'),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
          if (_result != null) ...[
            const SizedBox(height: AppTokens.gapCard),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_result),
              child: const Text('Selesai'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _baris(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
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

class _HasilVerifikasi extends StatelessWidget {
  final FaceVerificationResult result;
  const _HasilVerifikasi({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.existingFace
                        ? 'Wajah dikenali'
                        : 'Wajah terdaftar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Kuota minggu ini: ${result.weeklyPorsi}/'
              '${result.maxPorsiPerWeek} porsi • '
              '${result.weeklyPesanan}/${result.maxPesananPerWeek} pesanan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.5,
              ),
            ),
            if (result.matchScore != null) ...[
              const SizedBox(height: 4),
              Text(
                'Skor kecocokan: ${(result.matchScore! * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
