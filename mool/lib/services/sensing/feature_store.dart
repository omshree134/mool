import 'dart:async';

import '../../core/dates.dart';
import '../../core/local_store.dart';
import '../../models/daily_features.dart';

/// Daily behaviour totals, kept on the phone for 35 days.
/// Writes are batched: the step counter fires on every step, and writing
/// preferences that often causes jank and drains the battery.
class FeatureStore {
  FeatureStore._();
  static final FeatureStore instance = FeatureStore._();

  static const _key = 'features.v1';
  final Map<String, DailyFeatures> _days = {};
  Timer? _flushTimer;
  bool _loaded = false;

  void load() {
    if (_loaded) return;
    for (final m in LocalStore.instance.getJsonList(_key)) {
      try {
        final f = DailyFeatures.fromMap(m);
        _days[f.dateKey] = f;
      } catch (_) {}
    }
    _loaded = true;
  }

  DailyFeatures forDate(String key) {
    load();
    return _days.putIfAbsent(key, () => DailyFeatures(dateKey: key));
  }

  DailyFeatures today() => forDate(dateKey(DateTime.now()));

  DailyFeatures? existing(String key) {
    load();
    return _days[key];
  }

  List<DailyFeatures> all() {
    load();
    return _days.values.toList();
  }

  void update(String key, void Function(DailyFeatures f) change) {
    change(forDate(key));
    _flushTimer ??= Timer(const Duration(seconds: 60), flush);
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final cutoff = dateKey(DateTime.now().subtract(const Duration(days: 35)));
    _days.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    await LocalStore.instance.setJsonList(_key, _days.values.map((f) => f.toMap()).toList());
  }
}
