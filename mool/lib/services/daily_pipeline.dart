import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/settings.dart';
import '../models/distress.dart';
import 'distress_engine.dart';
import 'member_profile.dart';
import 'repository.dart';
import 'sensing/feature_store.dart';

/// Runs the engine after each check-in, screener or report, on app open, and
/// hourly. Saves the result locally and syncs it for the counsellor.
class DailyPipeline {
  DailyPipeline._();
  static final DailyPipeline instance = DailyPipeline._();

  bool _running = false;

  Future<DistressResult?> run() async {
    if (_running) return null;
    _running = true;
    try {
      final now = DateTime.now();
      final repo = Repo.instance;
      final history = repo.localDailyResults();
      final todayKey = dateKey(now);
      final yesterdayKey = dateKey(now.subtract(const Duration(days: 1)));

      final previousScores = <String, double>{
        for (final e in history.entries)
          if (e.key != todayKey && e.value.score != null) e.key: e.value.score!,
      };

      final sensing = Settings.instance.passiveSensing;
      await FeatureStore.instance.flush();

      final result = const DistressEngine().compute(DistressInputs(
        now: now,
        memberSince: Settings.instance.memberSince ?? now,
        checkIns: repo.localCheckIns(),
        screeners: repo.localScreeners(),
        features: sensing ? FeatureStore.instance.all() : const [],
        intimidationReports: repo.localReportTimes(),
        nextHearing: MemberProfile.instance.nextHearing,
        compensationOverdue: MemberProfile.instance.compensationOverdue,
        previousScores: previousScores,
        previousTier: history[yesterdayKey]?.tier,
      ));

      await repo.saveDaily(
        result,
        todayFeatures: sensing ? FeatureStore.instance.existing(todayKey) : null,
        yesterdayFeatures: sensing ? FeatureStore.instance.existing(yesterdayKey) : null,
      );
      return result;
    } catch (e, st) {
      debugPrint('Daily pipeline failed: $e\n$st');
      return null;
    } finally {
      _running = false;
    }
  }
}
