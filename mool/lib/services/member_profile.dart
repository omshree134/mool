import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/local_store.dart';
import 'repository.dart';

class CaseUpdate {
  const CaseUpdate(this.text, this.at);
  final String text;
  final DateTime? at;
}

/// Mirrors members/{uid}. Fields such as the hearing date and case stage are
/// set by the counsellor on the website; the app only reads them.
/// A JSON-safe copy is cached so the engine works offline.
class MemberProfile extends ChangeNotifier {
  MemberProfile._();
  static final MemberProfile instance = MemberProfile._();

  static const _cacheKey = 'cache.member';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Map<String, dynamic> _data = {};

  void listen() {
    _data = LocalStore.instance.getJson(_cacheKey);
    _sub?.cancel();
    _sub = Repo.instance.memberDoc.snapshots().listen((snap) {
      final d = snap.data() ?? {};
      _data = {
        'counsellorId': d['counsellorId'],
        'counsellorName': d['counsellorName'],
        'caseStage': d['caseStage'],
        'nextHearingDate': _toIso(d['nextHearingDate']),
        'compensationOverdue': d['compensationOverdue'] == true,
        'caseUpdates': ((d['caseUpdates'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => {'text': m['text']?.toString() ?? '', 'at': _toIso(m['at'])})
            .toList(),
      };
      unawaited(LocalStore.instance.setJson(_cacheKey, _data));
      notifyListeners();
    }, onError: (Object e) => debugPrint('Profile listener: $e'));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static String? _toIso(Object? v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return null;
  }

  bool get linked => _data['counsellorId'] != null;
  String? get counsellorName => _data['counsellorName'] as String?;
  String? get caseStage => _data['caseStage'] as String?;
  bool get compensationOverdue => _data['compensationOverdue'] == true;

  DateTime? get nextHearing {
    final raw = _data['nextHearingDate'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  List<CaseUpdate> get caseUpdates => ((_data['caseUpdates'] as List?) ?? [])
      .whereType<Map>()
      .map((m) => CaseUpdate(m['text']?.toString() ?? '', DateTime.tryParse(m['at']?.toString() ?? '')))
      .where((u) => u.text.isNotEmpty)
      .toList();
}
