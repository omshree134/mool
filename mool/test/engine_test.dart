import 'package:flutter_test/flutter_test.dart';
import 'package:mool/core/dates.dart';
import 'package:mool/models/checkin.dart';
import 'package:mool/models/daily_features.dart';
import 'package:mool/models/distress.dart';
import 'package:mool/models/screener.dart';
import 'package:mool/services/distress_engine.dart';
import 'package:mool/services/text_signals.dart';

final now = DateTime(2026, 9, 20, 18);
const engine = DistressEngine();

List<CheckIn> week(int answer, {int days = 7}) => [
      for (var a = 0; a < days; a++)
        CheckIn(
          id: 'c$a',
          at: now.subtract(Duration(days: a)),
          mood: answer,
          sleep: answer,
          safety: answer,
          coping: answer,
        ),
    ];

DistressResult run(List<CheckIn> c,
    {Map<String, double> prev = const {}, Tier? prevTier, List<DailyFeatures> f = const [], List<ScreenerResult> s = const []}) {
  return engine.compute(DistressInputs(
    now: now,
    memberSince: now.subtract(const Duration(days: 60)),
    checkIns: c,
    features: f,
    screeners: s,
    previousScores: prev,
    previousTier: prevTier,
  ));
}

String key(int daysAgo) => dateKey(now.subtract(Duration(days: daysAgo)));

void main() {
  group('No false alarms', () {
    test('answering "Okay" every day is stable', () {
      final r = run(week(3));
      expect(r.score, closeTo(30, 0.5));
      expect(r.tier, Tier.stable);
    });

    test('one terrible day after a good week stays stable', () {
      final c = [
        CheckIn(id: 'bad', at: now, mood: 1, sleep: 1, safety: 1, coping: 1),
        ...week(4, days: 7).skip(1),
      ];
      expect(run(c).tier, Tier.stable);
    });

    test('high score on a single day does not jump to outreach without a second day', () {
      final r = run(week(2), prev: {key(1): 20}, prevTier: Tier.stable);
      expect(r.score, greaterThan(60));
      expect(r.tier, Tier.watch);
    });

    test('too few check-ins gives insufficientData, not an alert', () {
      final r = run(week(2, days: 2));
      expect(r.tier, Tier.insufficientData);
    });

    test('crisis words that were denied do not raise crisis', () {
      final c = [
        CheckIn(id: 'n', at: now, mood: 3, sleep: 3, safety: 3, coping: 3, possibleCrisisLanguage: true),
        ...week(3).skip(1),
      ];
      expect(run(c).tier, isNot(Tier.crisis));
    });

    test('a phone left on a table is not a drop in activity', () {
      final features = <DailyFeatures>[
        for (var a = 4; a <= 20; a++)
          DailyFeatures(dateKey: key(a), activeBlocks: 24, inactiveBlocks: 60),
        // Recent days: phone not carried, so activity is invalid and ignored.
        for (var a = 1; a <= 3; a++) DailyFeatures(dateKey: key(a), notCarriedBlocks: 200),
      ];
      final r = run(week(3), f: features);
      expect(r.components['behaviour'], isNull);
      expect(r.tier, Tier.stable);
    });
  });

  group('Real distress is caught', () {
    test('a week of low answers with yesterday also high reaches outreach', () {
      final r = run(week(2), prev: {key(1): 64}, prevTier: Tier.watch);
      expect(r.tier, Tier.outreach);
    });

    test('confirmed crisis overrides everything', () {
      final c = [
        CheckIn(id: 'x', at: now, mood: 4, sleep: 4, safety: 4, coping: 4, crisisConfirmed: true),
        ...week(4).skip(1),
      ];
      final r = run(c);
      expect(r.tier, Tier.crisis);
      expect(r.crisisReason, isNotNull);
    });

    test('PHQ-9 item 9 above zero is crisis', () {
      final s = ScreenerResult(id: 'p', type: ScreenerType.phq9, at: now, answers: [0, 0, 0, 0, 0, 0, 0, 0, 1]);
      expect(run(week(4), s: [s]).tier, Tier.crisis);
    });

    test('a big steps drop versus the personal baseline adds a driver', () {
      final features = <DailyFeatures>[
        for (var a = 4; a <= 20; a++) DailyFeatures(dateKey: key(a), steps: 6000 + (a % 3) * 300, stepsComplete: true),
        for (var a = 1; a <= 3; a++) DailyFeatures(dateKey: key(a), steps: 900, stepsComplete: true),
      ];
      final r = run(week(3), f: features);
      expect(r.components['behaviour'], greaterThan(0.5));
      expect(r.drivers.any((d) => d.text.startsWith('Steps')), isTrue);
    });
  });

  group('Text signals', () {
    test('asks about clear statements', () {
      expect(TextSignals.mightExpressCrisis('I just want to die'), isTrue);
      expect(TextSignals.mightExpressCrisis("I don't know why I want to die"), isTrue);
    });

    test('negated statements do not trigger', () {
      expect(TextSignals.mightExpressCrisis('I would never kill myself'), isFalse);
      expect(TextSignals.mightExpressCrisis("I don't want to die"), isFalse);
      expect(TextSignals.mightExpressCrisis('Went to the market with my sister'), isFalse);
    });

    test('negativity is low for a calm note', () {
      expect(TextSignals.negativity('Felt calm today and slept well, good day'), lessThan(0.2));
    });
  });

  group('Screeners', () {
    test('PHQ-9 prorates one missing item', () {
      final r = ScreenerResult(id: 'a', type: ScreenerType.phq9, at: now, answers: [2, 2, 2, 2, 2, 2, 2, 2, null]);
      expect(r.total, closeTo(18, 0.01));
      expect(r.band, 'moderately severe');
    });

    test('two missing items cannot be scored', () {
      final r = ScreenerResult(id: 'b', type: ScreenerType.gad7, at: now, answers: [1, 1, 1, 1, 1, null, null]);
      expect(r.total, isNull);
    });
  });
}
