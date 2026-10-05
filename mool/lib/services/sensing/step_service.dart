import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';

import '../../core/dates.dart';
import '../../core/local_store.dart';
import 'feature_store.dart';

/// Uses the phone's hardware step counter. It keeps counting in low-power
/// hardware even when Mool isn't running, so it's the most reliable and
/// battery-friendly activity signal available.
class StepService {
  StepService._();
  static final StepService instance = StepService._();

  StreamSubscription<StepCount>? _sub;

  void start() {
    _sub ??= Pedometer.stepCountStream.listen(
      _onCount,
      onError: (Object e) => debugPrint('Step counter unavailable: $e'),
      cancelOnError: false,
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onCount(StepCount event) {
    final s = LocalStore.instance;
    final now = DateTime.now();
    final key = dateKey(now);
    final lastCount = s.getInt('steps.lastCount');
    final lastKey = s.getString('steps.lastKey');
    final lastHour = s.getInt('steps.lastHour') ?? 0;

    var today = lastKey == key ? (s.getInt('steps.today') ?? 0) : 0;

    if (lastKey != null && lastKey != key) {
      // Close the previous day. It only counts as complete if the last
      // reading came in the evening; otherwise part of the day is missing.
      FeatureStore.instance.update(lastKey, (f) => f.stepsComplete = lastHour >= 20);
    }

    if (lastCount != null) {
      final delta = event.steps - lastCount;
      // A negative delta means the phone rebooted and the counter reset.
      if (delta > 0 && delta < 60000) today += delta;
    }

    s.setInt('steps.lastCount', event.steps);
    s.setString('steps.lastKey', key);
    s.setInt('steps.lastHour', now.hour);
    s.setInt('steps.today', today);
    FeatureStore.instance.update(key, (f) => f.steps = today);
  }
}
