import 'dart:async';

import '../../core/dates.dart';
import '../../core/local_store.dart';
import '../../core/notifier.dart';
import '../../core/settings.dart';
import '../daily_pipeline.dart';
import '../repository.dart';
import '../safety/intimidation_watch.dart';
import 'feature_store.dart';
import 'gait_classifier.dart';
import 'mobility_service.dart';
import 'step_service.dart';

/// Starts and stops everything according to the person's choices.
/// Safe to call [apply] as often as needed.
class SensingCoordinator {
  SensingCoordinator._();
  static final SensingCoordinator instance = SensingCoordinator._();

  final GaitClassifier _gait = GaitClassifier();
  Timer? _gaitTimer;
  Timer? _housekeeping;
  bool _gaitBusy = false;
  bool _applying = false;

  Future<void> apply() async {
    if (_applying) return;
    _applying = true;
    try {
      final s = Settings.instance;

      if (s.passiveSensing) {
        StepService.instance.start();
        await MobilityService.instance.start();
        await _startGait();
      } else {
        StepService.instance.stop();
        MobilityService.instance.stop();
        _stopGait();
      }

      if (s.followWatch) {
        await IntimidationWatch.instance.start();
      } else {
        IntimidationWatch.instance.stop();
      }

      _housekeeping ??= Timer.periodic(const Duration(minutes: 15), (_) => _housekeep());
    } finally {
      _applying = false;
    }
  }

  Future<void> _startGait() async {
    if (_gaitTimer != null) return;
    final ok = await _gait.load();
    if (!ok) return; // steps still give an activity signal
    _gaitTimer = Timer.periodic(const Duration(minutes: 5), (_) => _gaitBurst());
  }

  void _stopGait() {
    _gaitTimer?.cancel();
    _gaitTimer = null;
  }

  Future<void> _gaitBurst() async {
    if (_gaitBusy) return;
    _gaitBusy = true;
    try {
      final sample = await _gait.sample();
      final key = dateKey(DateTime.now());
      FeatureStore.instance.update(key, (f) {
        switch (sample.state) {
          case ActivityState.active:
            f.activeBlocks++;
          case ActivityState.inactive:
            f.inactiveBlocks++;
          case ActivityState.notCarried:
            f.notCarriedBlocks++;
          case ActivityState.uncertain:
            break;
        }
      });
    } finally {
      _gaitBusy = false;
    }
  }

  /// Stops everything, e.g. on sign-out.
  void stopAll() {
    StepService.instance.stop();
    MobilityService.instance.stop();
    _stopGait();
    IntimidationWatch.instance.stop();
    _housekeeping?.cancel();
    _housekeeping = null;
  }

  int _lastPipelineHour = -1;

  Future<void> _housekeep() async {
    final now = DateTime.now();
    if (now.hour != _lastPipelineHour) {
      _lastPipelineHour = now.hour;
      unawaited(DailyPipeline.instance.run());
    }
    await _maybeRemind(now);
  }

  /// A gentle reminder at the chosen hour, at most once a day, only if the
  /// person hasn't checked in. Wording is neutral in case others see it.
  Future<void> _maybeRemind(DateTime now) async {
    final s = Settings.instance;
    if (!s.remindersOn || now.hour != s.reminderHour) return;
    final today = dateKey(now);
    if (LocalStore.instance.getString('reminder.lastDay') == today) return;
    if (Repo.instance.todaysCheckIn() != null) return;
    await LocalStore.instance.setString('reminder.lastDay', today);
    await Notifier.show(Notifier.reminderId, "A quiet moment for you, whenever you're ready.");
  }
}
