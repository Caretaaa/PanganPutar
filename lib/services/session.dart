import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sesi demo lokal (peran + nama), bukan autentikasi produksi.
// Identitas Supabase disimpan terpisah dan tidak memakai peran demo
// sebagai dasar otorisasi database.
class SessionState extends ChangeNotifier {
  static const _kRole = 'pp_role';
  static const _kName = 'pp_name';

  String? role; // penerima | penyedia | admin
  String? displayName;
  bool loaded = false;

  bool get isLoggedIn => role != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString(_kRole);
    displayName = prefs.getString(_kName);
    loaded = true;
    notifyListeners();
  }

  Future<void> signInDemo({
    required String role,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role);
    await prefs.setString(_kName, name);
    this.role = role;
    displayName = name;
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kName);
    role = null;
    displayName = null;
    notifyListeners();
  }
}
