import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengatur tema terang/gelap dengan persistensi lokal.
///
/// - Default: [ThemeMode.light] (tema terang sesuai arah desain baru).
/// - Switch hari/malam memanggil [setDark] untuk override eksplisit.
/// - [isDark] menyelesaikan system -> brightness aktual.
class ThemeController extends ChangeNotifier {
  static const _kKey = 'pp_theme_mode'; // system | light | dark

  ThemeMode _mode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get loaded => _loaded;
  bool get followsSystem => _mode == ThemeMode.system;

  bool isDark(BuildContext context) {
    switch (_mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  /// Untuk pemakaian di luar BuildContext (mis. toggle cepat).
  bool isDarkOf(Brightness platform) {
    switch (_mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return platform == Brightness.dark;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    switch (raw) {
      case 'light':
        _mode = ThemeMode.light;
        break;
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      default:
        // Sesuai keputusan redesign: tema TERANG default; gelap tetap
        // tersedia lewat pengaturan tema (tema mengikuti sistem dihapus).
        _mode = ThemeMode.light;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      switch (_mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> setDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);

  Future<void> toggle(BuildContext context) =>
      setDark(!isDark(context));

  /// Dipakai saat pertama kali butuh brightness tanpa context.
  bool get initialDark => _mode == ThemeMode.dark;
}
