import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';

/// Banner tipis mode demo yang BISA DITUTUP — pengganti chip DEMO besar di
/// appbar. Penjelasan disalin ringkas di satu tempat, bukan berulang per
/// layar. Status tertutup disimpan di perangkat (bukan database).
class DemoBanner extends StatefulWidget {
  final bool active;

  /// Keterangan isi pesan; bisa ditimpa untuk konteks tertentu.
  final String pesan;

  const DemoBanner({
    super.key,
    required this.active,
    this.pesan = 'Mode demo: data contoh • pesanan & sesi hanya di perangkat',
  });

  @override
  State<DemoBanner> createState() => _DemoBannerState();
}

class _DemoBannerState extends State<DemoBanner> {
  static const _key = 'pp_demo_banner_dismissed';
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _dismissed = prefs.getBool(_key) ?? false);
  }

  Future<void> _tutup() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Setingan gagal tersimpan: banner muncul lagi, tidak jatuhkan UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Peringatan kuning rendah-saturnin, kontras teks AA.
    final fg = dark ? AppColors.warnFgDark : AppColors.warnFgLight;
    final bg = dark ? AppColors.warnBgDark : AppColors.warnBgLight;
    return Material(
      color: bg,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.pesan,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Tutup pemberitahuan demo',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _tutup,
              icon: Icon(Icons.close, size: 18, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
