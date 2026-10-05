import 'dart:math';

import '../core/dates.dart';
import '../models/checkin.dart';
import '../models/daily_features.dart';
import '../models/distress.dart';
import '../models/screener.dart';

class DistressInputs {
  DistressInputs({
    required this.now,
    required this.memberSince,
    this.checkIns = const [],
    this.screeners = const [],
    this.features = const [],
    this.intimidationReports = const [],
    this.nextHearing,
    this.compensationOverdue = false,
    this.previousScores = const {},
    this.previousTier,
  });

  final DateTime now;
  final DateTime memberSince;
  final List<CheckIn> checkIns;
  final List<ScreenerResult> screeners;
  final List<DailyFeatures> features;
  final List<DateTime> intimidationReports;
  final DateTime? nextHearing;
  final bool compensationOverdue;

  /// dateKey → score for days before today.
  final Map<String, double> previousScores;

  /// Yesterday's tier, used so tiers don't flicker around a threshold.
  final Tier? previousTier;
}

/// Replaces Abhaya's RiskEngine. Runs on the phone once per check-in and
/// hourly, not every second.
///
/// How the score is built:
///   base (0–100) = weighted mean of the components that have data
///       self-report   60%  daily check-ins + validated screeners
///       behaviour     25%  steps, activity, time outside vs personal baseline
///       language      15%  tone of check-in notes
///   + context       up to +15  hearing soon, intimidation, overdue payment
///   + engagement    up to +10  several missed check-ins
///
/// Context and engagement are modifiers, not components: a court date next
/// week or a quiet week can nudge a borderline score, but can never raise an
/// alert about someone whose own answers say they are fine.
///
/// False-positive guards:
///   * "Okay" answers map to low distress (see CheckIn.answerDistress).
///   * Outreach and urgent tiers need two days of evidence or a large jump.
///   * Tiers only come down with a 5-point margin (no flicker).
///   * No score-based alert without at least 3 check-ins in 7 days or a
///     recent screener.
///   * Behaviour only counts completed days with enough sensor coverage, and
///     only drops that are both 30%+ and more than 1 SD below the person's
///     own usual.
///   * Crisis comes only from the person's own explicit answers.
class DistressEngine {
  const DistressEngine();

  static const double wSelfReport = 0.60;
  static const double wBehaviour = 0.25;
  static const double wLanguage = 0.15;
  static const double contextMaxPoints = 15;
  static const double engagementMaxPoints = 10;

  static const double tWatch = 40;
  static const double tOutreach = 60;
  static const double tUrgent = 80;
  static const double hysteresis = 5;
  static const double bigJump = 8;

  DistressResult compute(DistressInputs inp) {
    final today = startOfDay(inp.now);
    int ageDays(DateTime t) => calendarDaysBetween(t, today);
    final raw = <_RawDriver>[];

    // ── 1. Explicit crisis signals (always override) ────────────────
    String? crisisReason;
    var crisisUnclear = false;
    for (final c in inp.checkIns) {
      if (inp.now.difference(c.at).inHours > 72) continue;
      if (c.crisisConfirmed) {
        crisisReason = 'Said in a check-in that they are having thoughts of ending their life';
        break;
      }
      if (c.crisisUnclear) crisisUnclear = true;
    }
    if (crisisReason == null) {
      for (final s in inp.screeners) {
        if (inp.now.difference(s.at).inHours > 72) continue;
        if (s.selfHarmPositive) {
          crisisReason = 'PHQ-9 question 9 (thoughts of death or self-harm) answered above "not at all"';
          break;
        }
      }
    }

    // ── 2. Self-report ──────────────────────────────────────────────
    final recent = inp.checkIns.where((c) {
      final a = ageDays(c.at);
      return !c.skipped && a >= 0 && a <= 6;
    }).toList();

    double? daily;
    final itemSum = <String, double>{};
    final itemW = <String, double>{};
    var wSum = 0.0;
    var dSum = 0.0;
    for (final c in recent) {
      final d = c.distress;
      if (d == null) continue;
      final w = pow(0.8, ageDays(c.at)).toDouble();
      dSum += w * d;
      wSum += w;
      void item(String key, int? answer) {
        final x = CheckIn.itemDistress(answer);
        if (x == null) return;
        itemSum[key] = (itemSum[key] ?? 0) + w * x;
        itemW[key] = (itemW[key] ?? 0) + w;
      }

      item('mood', c.mood);
      item('sleep', c.sleep);
      item('safety', c.safety);
      item('coping', c.coping);
    }
    if (wSum > 0) daily = dSum / wSum;

    ScreenerResult? latestOf(ScreenerType t, int maxAge) {
      ScreenerResult? best;
      for (final s in inp.screeners) {
        if (s.type != t || s.severity == null || ageDays(s.at) > maxAge) continue;
        if (best == null || s.at.isAfter(best.at)) best = s;
      }
      return best;
    }

    final screens = [
      latestOf(ScreenerType.phq9, 21),
      latestOf(ScreenerType.gad7, 21),
      latestOf(ScreenerType.pcptsd5, 45),
    ].whereType<ScreenerResult>().toList();

    double? screenerSev;
    if (screens.isNotEmpty) {
      final sev = screens.map((s) => s.severity!).toList();
      final mx = sev.reduce(max);
      final mean = sev.reduce((a, b) => a + b) / sev.length;
      screenerSev = 0.7 * mx + 0.3 * mean;
    }

    double? selfReport;
    var dailyShare = 1.0;
    if (daily != null && screenerSev != null) {
      selfReport = 0.6 * daily + 0.4 * screenerSev;
      dailyShare = 0.6;
    } else {
      selfReport = daily ?? screenerSev;
    }

    if (daily != null) {
      const itemText = {
        'mood': 'Low mood in recent check-ins',
        'sleep': 'Poor sleep reported',
        'safety': 'Feeling unsafe',
        'coping': 'Struggling to manage day-to-day',
      };
      final n = itemSum.length;
      for (final k in itemSum.keys) {
        final mean = itemSum[k]! / itemW[k]!;
        if (mean >= 0.45) raw.add(_RawDriver(itemText[k]!, 'self', dailyShare * mean / n));
      }
    }
    if (screenerSev != null) {
      final share = daily != null ? 0.4 : 1.0;
      for (final s in screens) {
        if ((s.severity ?? 0) < 0.5) continue;
        final name = switch (s.type) {
          ScreenerType.phq9 => 'PHQ-9',
          ScreenerType.gad7 => 'GAD-7',
          ScreenerType.pcptsd5 => 'PC-PTSD-5',
        };
        raw.add(_RawDriver('$name: ${s.band} (${s.total!.round()}), ${friendlyDate(s.at)}', 'self',
            share * s.severity! / screens.length));
      }
    }

    // ── 3. Language ─────────────────────────────────────────────────
    final notes = inp.checkIns.where((c) => ageDays(c.at) <= 6 && c.noteNegativity != null).toList();
    double? language;
    if (notes.length >= 2) {
      final m = notes.map((c) => c.noteNegativity!).reduce((a, b) => a + b) / notes.length;
      language = ((m - 0.2) / 0.6).clamp(0.0, 1.0);
      if (language >= 0.4) raw.add(_RawDriver('Notes have had a heavy tone this week', 'language', language));
    }

    // ── 4. Behaviour against the person's own baseline ─────────────
    final pastDays = <int, DailyFeatures>{};
    for (final f in inp.features) {
      final a = calendarDaysBetween(parseDateKey(f.dateKey), today);
      if (a >= 1 && a <= 28) pastDays[a] = f; // completed days only
    }
    final behaviourScores = <double>[];
    void feature(String label, double? Function(DailyFeatures f) value) {
      final recentVals = <double>[];
      final baseVals = <double>[];
      pastDays.forEach((age, f) {
        final v = value(f);
        if (v == null) return;
        if (age <= 3) {
          recentVals.add(v);
        } else {
          baseVals.add(v);
        }
      });
      if (recentVals.length < 2 || baseVals.length < 7) return;
      final bm = _mean(baseVals);
      if (bm <= 0) return;
      final r = _mean(recentVals);
      final drop = (bm - r) / bm;
      var adverse = 0.0;
      if (drop >= 0.3) {
        final sd = max(_sd(baseVals), 0.15 * bm);
        final z = (bm - r) / sd;
        adverse = ((z - 1.0) / 1.5).clamp(0.0, 1.0);
      }
      behaviourScores.add(adverse);
      if (adverse > 0) {
        raw.add(_RawDriver('$label about ${(drop * 100).round()}% below their usual', 'behaviour', adverse));
      }
    }

    feature('Steps', (f) => f.stepsValid ? f.steps!.toDouble() : null);
    feature('Active time', (f) => f.activityValid ? f.activeMinutes.toDouble() : null);
    feature('Time outside home', (f) => f.mobilityValid ? f.awayMinutes.toDouble() : null);

    double? behaviour;
    if (behaviourScores.isNotEmpty) {
      final mx = behaviourScores.reduce(max);
      behaviour = 0.6 * mx + 0.4 * _mean(behaviourScores);
    }

    // ── 5. Base score from available components ────────────────────
    final comps = <String, double?>{
      'selfReport': selfReport,
      'behaviour': behaviour,
      'language': language,
    };
    const weights = {'selfReport': wSelfReport, 'behaviour': wBehaviour, 'language': wLanguage};
    var totalW = 0.0;
    var base = 0.0;
    comps.forEach((k, v) {
      if (v == null) return;
      totalW += weights[k]!;
      base += weights[k]! * v;
    });

    // ── 6. Modifiers ────────────────────────────────────────────────
    final reports14 = inp.intimidationReports.where((t) => ageDays(t) <= 14).length;
    final threat = reports14 == 0 ? 0.0 : min(1.0, 0.5 + 0.25 * (reports14 - 1));
    var hearing = 0.0;
    int? hearingIn;
    if (inp.nextHearing != null) {
      hearingIn = calendarDaysBetween(today, inp.nextHearing!);
      if (hearingIn >= 0 && hearingIn <= 7) {
        hearing = 0.6;
      } else if (hearingIn > 7 && hearingIn <= 14) {
        hearing = 0.3;
      }
    }
    final compensation = inp.compensationOverdue ? 0.4 : 0.0;
    final context = 1 - (1 - threat) * (1 - hearing) * (1 - compensation);

    var engagement = 0.0;
    var missed = 0;
    if (calendarDaysBetween(inp.memberSince, today) >= 8) {
      final touched = <String>{};
      for (final c in inp.checkIns) {
        final a = ageDays(c.at);
        if (a >= 1 && a <= 7) touched.add(dateKey(c.at)); // "Not today" counts as touching base
      }
      missed = 7 - touched.length;
      engagement = ((missed - 2) / 4).clamp(0.0, 1.0);
    }

    double? score;
    if (totalW > 0) {
      score = (base / totalW * 100 + context * contextMaxPoints + engagement * engagementMaxPoints)
          .clamp(0.0, 100.0);
    }

    // ── 7. Drivers with approximate points ─────────────────────────
    final drivers = <DistressDriver>[];
    if (totalW > 0) {
      for (final d in raw) {
        final w = switch (d.component) {
          'self' => wSelfReport,
          'behaviour' => wBehaviour,
          _ => wLanguage,
        };
        final compValue = switch (d.component) {
          'self' => 1.0,
          'behaviour' => behaviourScores.isEmpty ? 0.0 : (behaviour! / behaviourScores.reduce(max)),
          _ => 1.0,
        };
        drivers.add(DistressDriver(d.text, w / totalW * 100 * d.share * compValue));
      }
    }
    if (hearingIn != null && hearing > 0) {
      drivers.add(DistressDriver(
          hearingIn == 0 ? 'Court hearing today' : 'Court hearing in $hearingIn day${hearingIn == 1 ? '' : 's'}',
          hearing * contextMaxPoints));
    }
    if (threat > 0) {
      drivers.add(DistressDriver(
          '$reports14 intimidation report${reports14 == 1 ? '' : 's'} in the last 14 days', threat * contextMaxPoints));
    }
    if (compensation > 0) drivers.add(DistressDriver('Compensation payment overdue', compensation * contextMaxPoints));
    if (engagement > 0) {
      drivers.add(DistressDriver('No check-in on $missed of the last 7 days', engagement * engagementMaxPoints));
    }

    // ── 8. Data sufficiency and confidence ─────────────────────────
    final recentCount = recent.where((c) => c.distress != null).length;
    final screenerRecent = screens.any((s) => ageDays(s.at) <= 14);
    final sufficient = recentCount >= 3 || screenerRecent;
    final confidence = (0.6 * min(1.0, recentCount / 4) +
            0.2 * (screens.isNotEmpty ? 1 : 0) +
            0.2 * (behaviour != null ? 1 : 0))
        .clamp(0.0, 1.0);

    // ── 9. Trend (least squares over the last 7 days) ──────────────
    double? trend;
    final pts = <Point<double>>[];
    for (var a = 6; a >= 1; a--) {
      final s = inp.previousScores[dateKey(today.subtract(Duration(days: a)))];
      if (s != null) pts.add(Point(-a.toDouble(), s));
    }
    if (score != null) pts.add(Point(0.0, score));
    if (pts.length >= 4) trend = _slope(pts);

    // ── 10. Tier ────────────────────────────────────────────────────
    Tier tier;
    if (crisisReason != null) {
      tier = Tier.crisis;
    } else if (score == null) {
      tier = Tier.insufficientData;
    } else {
      final yesterday = inp.previousScores[dateKey(today.subtract(const Duration(days: 1)))];
      tier = _withHysteresis(score, yesterday, inp.previousTier);
      if (!sufficient) {
        tier = (score >= tUrgent && recentCount >= 2) ? Tier.outreach : Tier.insufficientData;
      }
      if (tier == Tier.stable && trend != null && trend >= 4 && score >= 30) {
        tier = Tier.watch;
        drivers.add(const DistressDriver('Rising steadily over the past week', 0));
      }
      if (crisisUnclear && tier.rank < Tier.outreach.rank) {
        tier = Tier.outreach;
        drivers.add(const DistressDriver(
            'A note may have mentioned self-harm; they preferred not to say when asked', 0));
      }
    }

    drivers.sort((a, b) => b.points.compareTo(a.points));
    final shown = drivers.where((d) => d.points >= 3 || d.points == 0).take(6).toList();

    return DistressResult(
      dateKey: dateKey(today),
      score: score,
      tier: tier,
      confidence: confidence,
      trendPerDay: trend,
      components: {...comps, 'context': context, 'engagement': engagement},
      drivers: shown,
      crisisReason: crisisReason,
      computedAt: inp.now,
    );
  }

  Tier _raw(double s) {
    if (s >= tUrgent) return Tier.urgent;
    if (s >= tOutreach) return Tier.outreach;
    if (s >= tWatch) return Tier.watch;
    return Tier.stable;
  }

  double _threshold(Tier t) => switch (t) {
        Tier.urgent => tUrgent,
        Tier.outreach => tOutreach,
        Tier.watch => tWatch,
        _ => 0,
      };

  Tier _withHysteresis(double score, double? yesterday, Tier? prev) {
    var t = _raw(score);
    // Going up into outreach/urgent needs the signal to hold for two days, or
    // a large jump. One bad day shouldn't page a counsellor.
    while (t.rank >= Tier.outreach.rank) {
      final th = _threshold(t);
      final held = yesterday != null && yesterday >= th - hysteresis;
      final jumped = score >= th + bigJump;
      final alreadyThere = prev != null && prev != Tier.crisis && prev.rank >= t.rank;
      if (held || jumped || alreadyThere) break;
      t = Tier.values[t.index - 1];
    }
    // Coming down needs a clear margin so the tier doesn't flicker.
    if (prev != null &&
        prev != Tier.crisis &&
        prev != Tier.insufficientData &&
        prev.rank > t.rank &&
        score > _threshold(prev) - hysteresis) {
      t = prev;
    }
    return t;
  }

  static double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

  static double _sd(List<double> v) {
    if (v.length < 2) return 0;
    final m = _mean(v);
    return sqrt(v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (v.length - 1));
  }

  static double _slope(List<Point<double>> pts) {
    final n = pts.length;
    final mx = pts.map((p) => p.x).reduce((a, b) => a + b) / n;
    final my = pts.map((p) => p.y).reduce((a, b) => a + b) / n;
    var num = 0.0;
    var den = 0.0;
    for (final p in pts) {
      num += (p.x - mx) * (p.y - my);
      den += (p.x - mx) * (p.x - mx);
    }
    return den == 0 ? 0 : num / den;
  }
}

class _RawDriver {
  _RawDriver(this.text, this.component, this.share);
  final String text;
  final String component;
  final double share;
}
