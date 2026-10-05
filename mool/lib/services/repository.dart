import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Settings;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import '../core/local_store.dart';
import '../core/settings.dart';
import '../models/checkin.dart';
import '../models/daily_features.dart';
import '../models/distress.dart';
import '../models/screener.dart';

/// Local-first storage. Everything is written to the phone first and to
/// Firestore in the background.
///
/// Firestore writes are never awaited in user-facing flows. Offline, a
/// Firestore write future doesn't complete until the phone is back online.
/// Abhaya awaited its Firestore SOS write before sending SMS, so with no data
/// connection the SMS step was never reached.
class Repo extends ChangeNotifier {
  Repo._();
  static final Repo instance = Repo._();

  final _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  String get uid {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) return authUid;
    var local = LocalStore.instance.getString('local_uid');
    if (local == null || local.isEmpty) {
      local = 'ward_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${_uuid.v4().substring(0, 6)}';
      LocalStore.instance.setString('local_uid', local);
    }
    return local;
  }

  DocumentReference<Map<String, dynamic>> get memberDoc => _db.collection('members').doc(uid);

  CollectionReference<Map<String, dynamic>> _sub(String name) => memberDoc.collection(name);

  String newId() => _uuid.v4();

  /// Fire-and-forget with logging. Firestore queues the write offline.
  void _background(Future<void> Function() op, String what) {
    unawaited(op().then((_) {}, onError: (Object e) => debugPrint('Firestore $what failed: $e')));
  }

  /// Awaits a write for at most [limit]. Returns true if the server confirmed
  /// it, false if it is still queued (it will still be sent later).
  Future<bool> _writeWithin(Future<void> write, Duration limit) async {
    try {
      await write.timeout(limit);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  // ── Member profile ──────────────────────────────────────────
  Future<void> upsertProfile() async {
    final s = Settings.instance;
    final emergency = LocalStore.instance.getString('emergency.contact') ?? '';
    _background(
      () => memberDoc.set({
        'id': uid,
        'displayName': s.displayName.isEmpty ? 'Ward (${uid.substring(0, 8)})' : s.displayName,
        'guardianId': s.guardianId,
        'guardianName': s.guardianName,
        'emergencyContact': emergency,
        'consent': s.consentMap(),
        'memberSince': s.memberSince?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'linkedAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'profile',
    );
  }

  Future<void> linkGuardian({required String guardianId, required String guardianName}) async {
    await LocalStore.instance.setString(SettingKeys.guardianId, guardianId);
    await LocalStore.instance.setString(SettingKeys.guardianName, guardianName);
    await upsertProfile();
    notifyListeners();
  }

  /// Restores user profile and recent check-ins from Firestore when logging in
  /// with Google or on app re-install / reset.
  Future<bool> restoreFromCloud(User user) async {
    try {
      final doc = await _db.collection('members').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final displayName = (data['displayName'] as String?) ?? user.displayName ?? 'Friend';
        final guardianId = (data['guardianId'] as String?) ?? '';
        final guardianName = (data['guardianName'] as String?) ?? '';
        final emergency = (data['emergencyContact'] as String?) ?? '';
        final memberSince = (data['memberSince'] as String?) ?? DateTime.now().toIso8601String();

        await LocalStore.instance.setString(SettingKeys.name, displayName);
        await LocalStore.instance.setString(SettingKeys.memberSince, memberSince);
        if (guardianId.isNotEmpty) {
          await LocalStore.instance.setString(SettingKeys.guardianId, guardianId);
          await LocalStore.instance.setString(SettingKeys.guardianName, guardianName);
        }
        if (emergency.isNotEmpty) {
          await LocalStore.instance.setString('emergency.contact', emergency);
        }

        // Restore check-ins
        try {
          final checkinSnap = await _db
              .collection('members')
              .doc(user.uid)
              .collection('checkins')
              .orderBy('at', descending: true)
              .limit(50)
              .get();

          if (checkinSnap.docs.isNotEmpty) {
            final checkinMaps = checkinSnap.docs.map((d) {
              final m = d.data();
              return {
                'id': d.id,
                'at': m['at'] ?? DateTime.now().toIso8601String(),
                'mood': m['mood'] ?? 3,
                'note': m['note'] ?? '',
                'sleep': m['sleep'] ?? 3,
                'safety': m['safety'] ?? 3,
                'coping': m['coping'] ?? 3,
                'skipped': m['skipped'] ?? false,
              };
            }).toList();
            await LocalStore.instance.setJsonList(_checkinsKey, checkinMaps);
          }
        } catch (e) {
          debugPrint('Error restoring check-ins: $e');
        }

        await LocalStore.instance.setBool(SettingKeys.onboarded, true);
        notifyListeners();
        return true;
      } else {
        // First-time user with this Google account
        final name = (user.displayName != null && user.displayName!.isNotEmpty) ? user.displayName! : 'Friend';
        await LocalStore.instance.setString(SettingKeys.name, name);
        if (user.email != null && user.email!.isNotEmpty) {
          await LocalStore.instance.setString('google.email', user.email!);
        }
        await LocalStore.instance.setString(SettingKeys.memberSince, DateTime.now().toIso8601String());
        await upsertProfile();
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error in restoreFromCloud: $e');
      return false;
    }
  }

  // ── Check-ins ───────────────────────────────────────────────
  static const _checkinsKey = 'cache.checkins';

  List<CheckIn> localCheckIns() =>
      LocalStore.instance.getJsonList(_checkinsKey).map(CheckIn.fromMap).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  CheckIn? todaysCheckIn() {
    final key = dateKey(DateTime.now());
    final today = localCheckIns().where((c) => dateKey(c.at) == key).toList();
    return today.isEmpty ? null : today.last;
  }

  Future<void> saveCheckIn(CheckIn c) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final list = localCheckIns().where((x) => x.id != c.id && x.at.isAfter(cutoff)).toList()..add(c);
    await LocalStore.instance.setJsonList(_checkinsKey, list.map((x) => x.toMap()).toList());
    await LocalStore.instance.setString('cache.lastCheckInAt', c.at.toIso8601String());
    notifyListeners();
    _background(
      () => _sub('checkins').doc(c.id).set({...c.toFirestore(), 'createdAt': FieldValue.serverTimestamp()}),
      'check-in',
    );
    _background(
      () => memberDoc.set({
        'lastCheckInAt': c.at.toIso8601String(),
        'latestMood': c.mood,
        'latestNote': c.note ?? '',
        'latestSleep': c.sleep,
        'latestSafety': c.safety,
        'latestCoping': c.coping,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'profile',
    );
  }

  // ── Screeners ───────────────────────────────────────────────
  static const _screenersKey = 'cache.screeners';

  List<ScreenerResult> localScreeners() =>
      LocalStore.instance.getJsonList(_screenersKey).map(ScreenerResult.fromMap).toList();

  Future<void> saveScreener(ScreenerResult r) async {
    final list = localScreeners().where((x) => x.id != r.id).toList()..add(r);
    await LocalStore.instance.setJsonList(_screenersKey, list.map((x) => x.toMap()).toList());
    notifyListeners();
    _background(
      () => _sub('screeners').doc(r.id).set({...r.toMap(), 'createdAt': FieldValue.serverTimestamp()}),
      'screener',
    );
    _background(
      () => memberDoc.set({
        'latestScreenerId': r.type.name,
        'latestScreenerScore': r.total,
        'latestScreenerSeverity': r.band,
        'latestScreenerAt': r.at.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'screener on memberDoc',
    );
  }

  /// The screener that is due, or null. Shown from day 2 so the first day
  /// isn't overwhelming, one at a time, and snoozable.
  ScreenerDefinition? dueScreener() {
    final since = Settings.instance.memberSince;
    if (since == null || calendarDaysBetween(since, DateTime.now()) < 1) return null;
    final snoozeUntil = DateTime.tryParse(LocalStore.instance.getString('screener.snoozeUntil') ?? '');
    if (snoozeUntil != null && DateTime.now().isBefore(snoozeUntil)) return null;
    final done = localScreeners();
    for (final def in ScreenerDefinition.all) {
      final last = done.where((r) => r.type == def.type).fold<DateTime?>(
          null, (latest, r) => latest == null || r.at.isAfter(latest) ? r.at : latest);
      if (last == null || calendarDaysBetween(last, DateTime.now()) >= def.intervalDays) return def;
    }
    return null;
  }

  Future<void> snoozeScreener() async {
    await LocalStore.instance
        .setString('screener.snoozeUntil', DateTime.now().add(const Duration(days: 2)).toIso8601String());
    notifyListeners();
  }

  // ── Daily results ───────────────────────────────────────────
  static const _dailyKey = 'cache.daily';

  Map<String, DistressResult> localDailyResults() {
    final out = <String, DistressResult>{};
    for (final m in LocalStore.instance.getJsonList(_dailyKey)) {
      try {
        final r = DistressResult.fromMap(m);
        out[r.dateKey] = r;
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveDaily(DistressResult r, {DailyFeatures? todayFeatures, DailyFeatures? yesterdayFeatures}) async {
    final all = localDailyResults()..[r.dateKey] = r;
    final keys = all.keys.toList()..sort();
    final keep = keys.length > 60 ? keys.sublist(keys.length - 60) : keys;
    await LocalStore.instance.setJsonList(_dailyKey, keep.map((k) => all[k]!.toMap()).toList());

    _background(
      () => _sub('daily').doc(r.dateKey).set({
        ...r.toMap(),
        if (todayFeatures != null) 'features': todayFeatures.toSummary(),
        'featuresPartial': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'daily',
    );
    if (yesterdayFeatures != null) {
      _background(
        () => _sub('daily').doc(yesterdayFeatures.dateKey).set({
          'features': yesterdayFeatures.toSummary(),
          'featuresPartial': false,
        }, SetOptions(merge: true)),
        'daily features',
      );
    }
    _background(
      () => memberDoc.set({
        'latest': {'tier': r.tier.name, 'score': r.score, 'dateKey': r.dateKey, 'confidence': r.confidence},
      }, SetOptions(merge: true)),
      'latest',
    );
  }

  // ── SOS ─────────────────────────────────────────────────────
  /// Returns true if the server confirmed within 5 s; false if queued.
  Future<bool> createSos(String id, {required String reason, double? lat, double? lng, double? accuracy}) async {
    final write = _sub('sos').doc(id).set({
      'id': id,
      'reason': reason,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'deviceTime': DateTime.now().toIso8601String(),
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng, 'accuracyM': accuracy},
    });
    unawaited(write.then((_) {}, onError: (Object e) => debugPrint('SOS write failed: $e')));
    _background(
      () => memberDoc.set({
        'sosActive': true,
        'lastSosAt': DateTime.now().toIso8601String(),
        'lastSosReason': reason,
        if (lat != null && lng != null) 'lastSosLocation': {'lat': lat, 'lng': lng},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'sos status in memberDoc',
    );
    return _writeWithin(write, const Duration(seconds: 5));
  }

  void resolveSos(String id) {
    _background(
      () => _sub('sos').doc(id).set({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'SOS resolve',
    );
    _background(
      () => memberDoc.set({
        'sosActive': false,
        'lastSosResolvedAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'sos resolved in memberDoc',
    );
  }

  void syncTrustedContacts(List<Map<String, dynamic>> contacts) {
    _background(
      () => memberDoc.set({
        'trustedContacts': contacts,
        'trustedContactsCount': contacts.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'trusted contacts in memberDoc',
    );
  }

  // ── Reports, requests, evidence ─────────────────────────────
  static const _reportsKey = 'cache.reportTimes';

  List<DateTime> localReportTimes() => LocalStore.instance
      .getJsonList(_reportsKey)
      .map((m) => DateTime.tryParse(m['at'] as String? ?? ''))
      .whereType<DateTime>()
      .toList();

  Future<void> addReport(String id, Map<String, dynamic> data) async {
    final list = LocalStore.instance.getJsonList(_reportsKey)..add({'id': id, 'at': DateTime.now().toIso8601String()});
    await LocalStore.instance.setJsonList(_reportsKey, list);
    notifyListeners();
    _background(
      () => _sub('reports').doc(id).set({...data, 'id': id, 'createdAt': FieldValue.serverTimestamp()}),
      'report',
    );
    _background(
      () => memberDoc.set({
        'latestReport': {...data, 'id': id},
        'latestReportAt': DateTime.now().toIso8601String(),
        if (data['audioUrl'] != null) 'latestReportAudioUrl': data['audioUrl'],
        if (data['hasAudio'] == true) 'hasReportAudio': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      'latestReport in memberDoc',
    );
  }

  void requestCallback({required String reason}) {
    final id = newId();
    _background(
      () => _sub('requests').doc(id).set({
        'id': id,
        'type': 'callback',
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      'callback request',
    );
  }

  void addEvidence(String id, Map<String, dynamic> data) {
    _background(() => _sub('evidence').doc(id).set({...data, 'createdAt': FieldValue.serverTimestamp()}), 'evidence');
  }

  void markEvidenceUploaded(
    String id,
    String storagePath, {
    String? downloadUrl,
    String? kind,
    String? linkedTo,
  }) {
    final data = <String, dynamic>{
      'uploaded': true,
      'storagePath': storagePath,
      'uploadedAt': FieldValue.serverTimestamp(),
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (kind != null) 'kind': kind,
      if (linkedTo != null) 'linkedTo': linkedTo,
    };
    _background(
      () => _sub('evidence').doc(id).set(data, SetOptions(merge: true)),
      'evidence upload',
    );

    // If linked to a report: update the report document with audioUrl
    if (linkedTo != null && linkedTo.startsWith('reports/')) {
      final reportId = linkedTo.replaceFirst('reports/', '');
      _background(
        () => _sub('reports').doc(reportId).set({
          if (downloadUrl != null) 'audioUrl': downloadUrl,
          'audioEvidenceId': id,
          'hasAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'link audio to report',
      );
      _background(
        () => memberDoc.set({
          if (downloadUrl != null) 'latestReportAudioUrl': downloadUrl,
          'hasReportAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'latestReportAudioUrl in memberDoc',
      );
    }

    // If linked to an SOS: update the SOS document with audioUrl
    if (linkedTo != null && linkedTo.startsWith('sos/')) {
      final sosId = linkedTo.replaceFirst('sos/', '');
      _background(
        () => _sub('sos').doc(sosId).set({
          if (downloadUrl != null) 'audioUrl': downloadUrl,
          'audioEvidenceId': id,
          'hasAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'link audio to sos',
      );
      _background(
        () => memberDoc.set({
          if (downloadUrl != null) 'latestSosAudioUrl': downloadUrl,
          'hasSosAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'latestSosAudioUrl in memberDoc',
      );
    }
  }

  void linkDirectAudio({
    required String linkedTo,
    required String evidenceId,
    required String audioUrl,
    required String kind,
  }) {
    if (linkedTo.startsWith('reports/')) {
      final reportId = linkedTo.replaceFirst('reports/', '');
      _background(
        () => _sub('reports').doc(reportId).set({
          'audioUrl': audioUrl,
          'audioEvidenceId': evidenceId,
          'hasAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'direct audio to report',
      );
      _background(
        () => memberDoc.set({
          'latestReportAudioUrl': audioUrl,
          'hasReportAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'latestReportAudioUrl in memberDoc',
      );
    } else if (linkedTo.startsWith('sos/')) {
      final sosId = linkedTo.replaceFirst('sos/', '');
      _background(
        () => _sub('sos').doc(sosId).set({
          'audioUrl': audioUrl,
          'audioEvidenceId': evidenceId,
          'hasAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'direct audio to sos',
      );
      _background(
        () => memberDoc.set({
          'latestSosAudioUrl': audioUrl,
          'hasSosAudio': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'latestSosAudioUrl in memberDoc',
      );
    }
  }

  void saveSharedSafetyPlan(Map<String, dynamic>? plan) {
    _background(
      () => plan == null
          ? _sub('shared').doc('safetyPlan').delete()
          : _sub('shared').doc('safetyPlan').set({...plan, 'updatedAt': FieldValue.serverTimestamp()}),
      'safety plan',
    );
  }
}
