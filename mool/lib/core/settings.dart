import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'local_store.dart';

class SettingKeys {
  static const onboarded = 'onboarded';
  static const name = 'profile.name';
  static const memberSince = 'profile.memberSince';
  static const passiveSensing = 'consent.passiveSensing';
  static const followWatch = 'consent.followWatch';
  static const recordAudioOnSos = 'sos.recordAudio';
  static const call112OnSos = 'sos.call112';
  static const shareLocationOnSos = 'sos.shareLocation';
  static const shareNotes = 'share.notes';
  static const shareSafetyPlan = 'share.safetyPlan';
  static const showCaseUpdates = 'case.show';
  static const remindersOn = 'reminder.on';
  static const reminderHour = 'reminder.hour';
  static const pinHash = 'lock.hash';
  static const pinSalt = 'lock.salt';
  static const guardianId = 'guardian.id';
  static const guardianName = 'guardian.name';
}

/// Every choice the person makes about Mool. Defaults lean private:
/// passive sensing, device watching and audio recording are all off until
/// the person turns them on.
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  LocalStore get _s => LocalStore.instance;

  bool get onboarded => _s.getBool(SettingKeys.onboarded);
  String get displayName => _s.getString(SettingKeys.name) ?? '';
  String get guardianId => _s.getString(SettingKeys.guardianId) ?? '';
  String get guardianName => _s.getString(SettingKeys.guardianName) ?? '';
  bool get hasGuardian => guardianId.isNotEmpty;
  DateTime? get memberSince {
    final raw = _s.getString(SettingKeys.memberSince);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool get passiveSensing => _s.getBool(SettingKeys.passiveSensing);
  bool get followWatch => _s.getBool(SettingKeys.followWatch);
  bool get recordAudioOnSos => _s.getBool(SettingKeys.recordAudioOnSos);
  bool get call112OnSos => _s.getBool(SettingKeys.call112OnSos, fallback: true);
  bool get shareLocationOnSos => _s.getBool(SettingKeys.shareLocationOnSos, fallback: true);
  bool get shareNotesByDefault => _s.getBool(SettingKeys.shareNotes, fallback: true);
  bool get shareSafetyPlan => _s.getBool(SettingKeys.shareSafetyPlan);
  bool get showCaseUpdates => _s.getBool(SettingKeys.showCaseUpdates, fallback: true);
  bool get remindersOn => _s.getBool(SettingKeys.remindersOn, fallback: true);
  int get reminderHour => _s.getInt(SettingKeys.reminderHour) ?? 20;
  bool get hasPin => _s.getString(SettingKeys.pinHash) != null;

  Future<void> setBool(String key, bool value) async {
    await _s.setBool(key, value);
    notifyListeners();
  }

  Future<void> setInt(String key, int value) async {
    await _s.setInt(key, value);
    notifyListeners();
  }

  Future<void> setString(String key, String value) async {
    await _s.setString(key, value);
    notifyListeners();
  }

  Future<void> reset() async {
    await _s.clearAll();
    notifyListeners();
  }

  /// Mirrored to Firestore so the counsellor knows which signals exist.
  Map<String, bool> consentMap() => {
        'passiveSensing': passiveSensing,
        'followWatch': followWatch,
        'recordAudioOnSos': recordAudioOnSos,
        'shareLocationOnSos': shareLocationOnSos,
        'shareNotesByDefault': shareNotesByDefault,
        'shareSafetyPlan': shareSafetyPlan,
      };

  // ── App lock ───────────────────────────────────────────────
  // A 4–6 digit PIN protects against someone else opening the app on a shared
  // phone. It is not strong cryptographic security, and isn't claimed to be.

  String _hash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 5000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _s.setString(SettingKeys.pinSalt, salt);
    await _s.setString(SettingKeys.pinHash, _hash(pin, salt));
    notifyListeners();
  }

  bool checkPin(String pin) {
    final salt = _s.getString(SettingKeys.pinSalt);
    final hash = _s.getString(SettingKeys.pinHash);
    if (salt == null || hash == null) return true;
    return _hash(pin, salt) == hash;
  }

  Future<void> removePin() async {
    await _s.remove(SettingKeys.pinHash);
    await _s.remove(SettingKeys.pinSalt);
    notifyListeners();
  }
}
