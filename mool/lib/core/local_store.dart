import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper around SharedPreferences. Everything that never leaves the
/// phone (home location, safety plan, raw sensor totals) lives here.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getString(String k) => _prefs.getString(k);
  Future<void> setString(String k, String v) => _prefs.setString(k, v);
  bool getBool(String k, {bool fallback = false}) => _prefs.getBool(k) ?? fallback;
  Future<void> setBool(String k, bool v) => _prefs.setBool(k, v);
  int? getInt(String k) => _prefs.getInt(k);
  Future<void> setInt(String k, int v) => _prefs.setInt(k, v);
  Future<void> remove(String k) => _prefs.remove(k);

  List<String> getStringList(String k) => _prefs.getStringList(k) ?? [];
  Future<void> setStringList(String k, List<String> v) => _prefs.setStringList(k, v);

  List<Map<String, dynamic>> getJsonList(String k) {
    final raw = _prefs.getString(k);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> setJsonList(String k, List<Map<String, dynamic>> list) =>
      _prefs.setString(k, jsonEncode(list));

  Map<String, dynamic> getJson(String k) {
    final raw = _prefs.getString(k);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  Future<void> setJson(String k, Map<String, dynamic> v) => _prefs.setString(k, jsonEncode(v));

  Future<void> clearAll() => _prefs.clear();
}
