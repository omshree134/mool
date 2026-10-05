import '../core/dates.dart';

/// One daily check-in. Every answer is 1–5 where 5 is the best.
class CheckIn {
  CheckIn({
    required this.id,
    required this.at,
    this.mood,
    this.sleep,
    this.safety,
    this.coping,
    this.note,
    this.noteShared = true,
    this.noteNegativity,
    this.possibleCrisisLanguage = false,
    this.crisisConfirmed = false,
    this.crisisUnclear = false,
    this.skipped = false,
  });

  factory CheckIn.skipped(String id, DateTime at) => CheckIn(id: id, at: at, skipped: true);

  final String id;
  final DateTime at;
  final int? mood;
  final int? sleep;
  final int? safety;
  final int? coping;
  final String? note;
  final bool noteShared;

  /// 0–1 tone of the note, computed on the phone. Null when no usable note.
  final double? noteNegativity;

  /// The note matched a self-harm phrase. On its own this never alerts
  /// anyone: it only makes the app ask the person directly.
  final bool possibleCrisisLanguage;

  /// The person answered "yes" when asked about thoughts of ending their life.
  final bool crisisConfirmed;

  /// The person chose "I'd rather not say" to that question.
  final bool crisisUnclear;

  /// "Not today". Counts as staying in touch, never as a missed check-in.
  final bool skipped;

  /// Answer → distress. Non-linear on purpose: "Okay" (3) is low distress.
  /// A straight (5 - x) / 4 mapping would score someone answering "Okay" to
  /// everything at 50/100, which would page counsellors about people who are
  /// fine. That was the single biggest false-positive risk in the design.
  static const Map<int, double> answerDistress = {
    5: 0.0,
    4: 0.1,
    3: 0.3,
    2: 0.65,
    1: 1.0,
  };

  static double? itemDistress(int? answer) => answer == null ? null : answerDistress[answer];

  /// Mean distress across answered items, or null if nothing was answered.
  double? get distress {
    if (skipped) return null;
    final values = [mood, sleep, safety, coping].map(itemDistress).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at.toIso8601String(),
        'dateKey': dateKey(at),
        'mood': mood,
        'sleep': sleep,
        'safety': safety,
        'coping': coping,
        'note': note,
        'noteShared': noteShared,
        'noteNegativity': noteNegativity,
        'possibleCrisisLanguage': possibleCrisisLanguage,
        'crisisConfirmed': crisisConfirmed,
        'crisisUnclear': crisisUnclear,
        'skipped': skipped,
      };

  /// What the counsellor sees. Private notes stay on the phone.
  Map<String, dynamic> toFirestore() {
    final m = toMap();
    if (!noteShared) m.remove('note');
    return m;
  }

  factory CheckIn.fromMap(Map<String, dynamic> m) => CheckIn(
        id: m['id'] as String,
        at: DateTime.parse(m['at'] as String),
        mood: (m['mood'] as num?)?.toInt(),
        sleep: (m['sleep'] as num?)?.toInt(),
        safety: (m['safety'] as num?)?.toInt(),
        coping: (m['coping'] as num?)?.toInt(),
        note: m['note'] as String?,
        noteShared: m['noteShared'] as bool? ?? true,
        noteNegativity: (m['noteNegativity'] as num?)?.toDouble(),
        possibleCrisisLanguage: m['possibleCrisisLanguage'] as bool? ?? false,
        crisisConfirmed: m['crisisConfirmed'] as bool? ?? false,
        crisisUnclear: m['crisisUnclear'] as bool? ?? false,
        skipped: m['skipped'] as bool? ?? false,
      );
}
