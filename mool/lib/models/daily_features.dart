/// Daily totals computed on the phone. Raw sensor data and coordinates never
/// leave the device; only these numbers do, and only if the person opted in.
///
/// Each feature has a coverage rule. A day where the phone was switched off or
/// left on a table must not look like "stayed in bed all day", or Mool would
/// raise alarms about people who are fine.
class DailyFeatures {
  DailyFeatures({
    required this.dateKey,
    this.steps,
    this.stepsComplete = false,
    this.activeBlocks = 0,
    this.inactiveBlocks = 0,
    this.notCarriedBlocks = 0,
    this.awayMinutes = 0,
    this.locationCoverageMinutes = 0,
    this.maxDistanceKm = 0,
    this.homeKnown = false,
  });

  final String dateKey;

  int? steps;

  /// True once the day is over and the last reading came late enough that
  /// the count covers the whole day.
  bool stepsComplete;

  /// 5-minute blocks classified by the gait model.
  int activeBlocks;
  int inactiveBlocks;
  int notCarriedBlocks;

  int awayMinutes;
  int locationCoverageMinutes;
  double maxDistanceKm;
  bool homeKnown;

  static const blockMinutes = 5;

  int get activeMinutes => activeBlocks * blockMinutes;
  int get carriedBlocks => activeBlocks + inactiveBlocks;

  bool get stepsValid => steps != null && stepsComplete;

  /// At least 4 hours of the phone actually being carried.
  bool get activityValid => carriedBlocks >= 48;

  /// At least 12 hours of location coverage and a learned home.
  bool get mobilityValid => homeKnown && locationCoverageMinutes >= 720;

  /// What is synced for the counsellor dashboard. Invalid values are left out
  /// rather than sent as zeros.
  Map<String, dynamic> toSummary() => {
        if (stepsValid) 'steps': steps,
        if (activityValid) 'activeMinutes': activeMinutes,
        if (mobilityValid) 'hoursAwayFromHome': double.parse((awayMinutes / 60).toStringAsFixed(1)),
        if (mobilityValid) 'furthestKm': double.parse(maxDistanceKm.toStringAsFixed(1)),
      };

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'steps': steps,
        'stepsComplete': stepsComplete,
        'activeBlocks': activeBlocks,
        'inactiveBlocks': inactiveBlocks,
        'notCarriedBlocks': notCarriedBlocks,
        'awayMinutes': awayMinutes,
        'locationCoverageMinutes': locationCoverageMinutes,
        'maxDistanceKm': maxDistanceKm,
        'homeKnown': homeKnown,
      };

  factory DailyFeatures.fromMap(Map<String, dynamic> m) => DailyFeatures(
        dateKey: m['dateKey'] as String,
        steps: (m['steps'] as num?)?.toInt(),
        stepsComplete: m['stepsComplete'] as bool? ?? false,
        activeBlocks: (m['activeBlocks'] as num?)?.toInt() ?? 0,
        inactiveBlocks: (m['inactiveBlocks'] as num?)?.toInt() ?? 0,
        notCarriedBlocks: (m['notCarriedBlocks'] as num?)?.toInt() ?? 0,
        awayMinutes: (m['awayMinutes'] as num?)?.toInt() ?? 0,
        locationCoverageMinutes: (m['locationCoverageMinutes'] as num?)?.toInt() ?? 0,
        maxDistanceKm: (m['maxDistanceKm'] as num?)?.toDouble() ?? 0,
        homeKnown: m['homeKnown'] as bool? ?? false,
      );
}
