/// Tiers in ascending order. The index doubles as the rank.
/// Counsellor-facing only: the person using Mool never sees a score or tier.
enum Tier {
  insufficientData,
  stable,
  watch,
  outreach,
  urgent,
  crisis;

  int get rank => index;

  String get counsellorLabel => switch (this) {
        Tier.insufficientData => 'Not enough recent check-ins',
        Tier.stable => 'Stable',
        Tier.watch => 'Keep an eye on',
        Tier.outreach => 'Reach out within 24 hours',
        Tier.urgent => 'Reach out within 4 hours',
        Tier.crisis => 'Contact now',
      };
}

class DistressDriver {
  const DistressDriver(this.text, this.points);

  /// Plain-language reason, written for a counsellor.
  final String text;

  /// Approximate points this reason added to the score.
  final double points;

  Map<String, dynamic> toMap() => {'text': text, 'points': double.parse(points.toStringAsFixed(1))};

  factory DistressDriver.fromMap(Map<String, dynamic> m) =>
      DistressDriver(m['text'] as String, (m['points'] as num).toDouble());
}

class DistressResult {
  const DistressResult({
    required this.dateKey,
    required this.score,
    required this.tier,
    required this.confidence,
    required this.trendPerDay,
    required this.components,
    required this.drivers,
    required this.crisisReason,
    required this.computedAt,
  });

  final String dateKey;
  final double? score;
  final Tier tier;

  /// 0–1: how much data the score is based on.
  final double confidence;

  /// Score points per day over the past week (positive = getting worse).
  final double? trendPerDay;
  final Map<String, double?> components;
  final List<DistressDriver> drivers;
  final String? crisisReason;
  final DateTime computedAt;

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'score': score == null ? null : double.parse(score!.toStringAsFixed(1)),
        'tier': tier.name,
        'tierLabel': tier.counsellorLabel,
        'confidence': double.parse(confidence.toStringAsFixed(2)),
        'trendPerDay': trendPerDay == null ? null : double.parse(trendPerDay!.toStringAsFixed(2)),
        'components': components.map((k, v) => MapEntry(k, v == null ? null : double.parse(v.toStringAsFixed(3)))),
        'drivers': drivers.map((d) => d.toMap()).toList(),
        'crisisReason': crisisReason,
        'computedAt': computedAt.toIso8601String(),
        'engineVersion': 1,
      };

  factory DistressResult.fromMap(Map<String, dynamic> m) => DistressResult(
        dateKey: m['dateKey'] as String,
        score: (m['score'] as num?)?.toDouble(),
        tier: Tier.values.byName(m['tier'] as String),
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
        trendPerDay: (m['trendPerDay'] as num?)?.toDouble(),
        components: ((m['components'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num?)?.toDouble())),
        drivers: ((m['drivers'] as List?) ?? [])
            .map((d) => DistressDriver.fromMap(Map<String, dynamic>.from(d as Map)))
            .toList(),
        crisisReason: m['crisisReason'] as String?,
        computedAt: DateTime.parse(m['computedAt'] as String),
      );
}
