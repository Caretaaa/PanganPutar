import 'package:shared_preferences/shared_preferences.dart';

/// Penanda onboarding sekali-tampil.
class FirstRunStore {
  static const _kDone = 'pp_onboarding_done';

  Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDone) ?? false;
  }

  Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDone, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDone);
  }
}
