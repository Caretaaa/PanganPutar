import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_colors.dart';

/// Bingkai QR siap pindai.
///
/// Latar selalu putih (kamera butuh kontras terang, termasuk saat mode gelap),
/// dengan sudut membulat dan pesan galat yang ramah bila data tidak bisa
/// dirender. [redup] = QR sudah tidak berlaku (pesanan selesai/dibatalkan).
class QrPanel extends StatelessWidget {
  final String data;
  final double size;
  final bool redup;
  final String semanticLabel;

  const QrPanel({
    super.key,
    required this.data,
    this.size = 220,
    this.redup = false,
    this.semanticLabel = 'Kode QR pengambilan',
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: redup ? 0.22 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.cardBorder(
              Theme.of(context).brightness == Brightness.dark,
            ),
            width: 1,
          ),
        ),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: size,
          gapless: true,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          semanticsLabel: semanticLabel,
          errorStateBuilder: (context, error) => SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(
                'QR gagal dimuat.\nMuat ulang layar ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary(Theme.of(context).brightness),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
