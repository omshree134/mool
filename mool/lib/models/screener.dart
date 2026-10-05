/// PHQ-9 and GAD-7 are free to reproduce and use. PC-PTSD-5 is in the public
/// domain (US National Center for PTSD). Wording is kept exactly as validated.
enum ScreenerType { phq9, gad7, pcptsd5 }

class ScreenerOption {
  const ScreenerOption(this.label, this.value);
  final String label;
  final int value;
}

class ScreenerDefinition {
  const ScreenerDefinition({
    required this.type,
    required this.friendlyTitle,
    required this.intro,
    required this.stem,
    required this.items,
    required this.options,
    required this.intervalDays,
  });

  final ScreenerType type;
  final String friendlyTitle;
  final String intro;
  final String stem;
  final List<String> items;
  final List<ScreenerOption> options;
  final int intervalDays;

  static const _frequency = [
    ScreenerOption('Not at all', 0),
    ScreenerOption('Several days', 1),
    ScreenerOption('More than half the days', 2),
    ScreenerOption('Nearly every day', 3),
  ];

  static const _yesNo = [
    ScreenerOption('No', 0),
    ScreenerOption('Yes', 1),
  ];

  static const phq9 = ScreenerDefinition(
    type: ScreenerType.phq9,
    friendlyTitle: 'How the last two weeks have felt',
    intro: 'Nine short questions that counsellors use everywhere. There are no right or wrong answers, '
        'and you can skip any question.',
    stem: 'Over the last 2 weeks, how often have you been bothered by:',
    items: [
      'Little interest or pleasure in doing things',
      'Feeling down, depressed, or hopeless',
      'Trouble falling or staying asleep, or sleeping too much',
      'Feeling tired or having little energy',
      'Poor appetite or overeating',
      'Feeling bad about yourself, or that you are a failure or have let yourself or your family down',
      'Trouble concentrating on things, such as reading the newspaper or watching television',
      'Moving or speaking so slowly that other people could have noticed, or the opposite: being so '
          'fidgety or restless that you have been moving around a lot more than usual',
      'Thoughts that you would be better off dead, or of hurting yourself in some way',
    ],
    options: _frequency,
    intervalDays: 14,
  );

  static const gad7 = ScreenerDefinition(
    type: ScreenerType.gad7,
    friendlyTitle: 'Worry and feeling on edge',
    intro: 'Seven short questions about worry over the last two weeks. You can skip any question.',
    stem: 'Over the last 2 weeks, how often have you been bothered by:',
    items: [
      'Feeling nervous, anxious, or on edge',
      'Not being able to stop or control worrying',
      'Worrying too much about different things',
      'Trouble relaxing',
      'Being so restless that it is hard to sit still',
      'Becoming easily annoyed or irritable',
      'Feeling afraid, as if something awful might happen',
    ],
    options: _frequency,
    intervalDays: 14,
  );

  static const pcptsd5 = ScreenerDefinition(
    type: ScreenerType.pcptsd5,
    friendlyTitle: 'After what happened',
    intro: 'Five yes-or-no questions about how what happened may still be affecting you. '
        'Take your time, and skip anything you like.',
    stem: 'In the past month, have you:',
    items: [
      'Had nightmares about the event(s) or thought about the event(s) when you did not want to?',
      'Tried hard not to think about the event(s) or went out of your way to avoid situations that '
          'reminded you of the event(s)?',
      'Been constantly on guard, watchful, or easily startled?',
      'Felt numb or detached from people, activities, or your surroundings?',
      'Felt guilty or unable to stop blaming yourself or others for the event(s) or any problems the '
          'event(s) may have caused?',
    ],
    options: _yesNo,
    intervalDays: 30,
  );

  static const all = [phq9, gad7, pcptsd5];

  static ScreenerDefinition of(ScreenerType t) => all.firstWhere((d) => d.type == t);
}

class ScreenerResult {
  ScreenerResult({required this.id, required this.type, required this.at, required this.answers});

  final String id;
  final ScreenerType type;
  final DateTime at;

  /// Null means "prefer not to answer".
  final List<int?> answers;

  int get answered => answers.whereType<int>().length;
  int get rawTotal => answers.whereType<int>().fold(0, (a, b) => a + b);

  /// Total prorated when exactly one item was skipped (standard practice).
  /// Null when too much is missing to score.
  double? get total {
    final n = answers.length;
    if (answered == n) return rawTotal.toDouble();
    if (answered == n - 1 && answered > 0) return rawTotal * n / answered;
    return null;
  }

  /// PHQ-9 item 9 (thoughts of death or self-harm) answered above zero.
  bool get selfHarmPositive => type == ScreenerType.phq9 && answers.length == 9 && (answers[8] ?? 0) > 0;

  /// 0–1 severity from published clinical bands, not raw fraction of maximum.
  /// A PHQ-9 of 10 (moderate) is 37% of the maximum but is clinically meaningful.
  double? get severity {
    final t = total;
    if (t == null) return null;
    switch (type) {
      case ScreenerType.phq9:
        if (t >= 20) return 0.95;
        if (t >= 15) return 0.75;
        if (t >= 10) return 0.55;
        if (t >= 5) return 0.3;
        return 0.05;
      case ScreenerType.gad7:
        if (t >= 15) return 0.9;
        if (t >= 10) return 0.6;
        if (t >= 5) return 0.3;
        return 0.05;
      case ScreenerType.pcptsd5:
        if (t >= 5) return 0.9;
        if (t >= 4) return 0.75;
        if (t >= 3) return 0.6;
        return t * 0.15;
    }
  }

  /// Band name for the counsellor dashboard. Not shown to the person.
  String get band {
    final t = total;
    if (t == null) return 'incomplete';
    switch (type) {
      case ScreenerType.phq9:
        if (t >= 20) return 'severe';
        if (t >= 15) return 'moderately severe';
        if (t >= 10) return 'moderate';
        if (t >= 5) return 'mild';
        return 'minimal';
      case ScreenerType.gad7:
        if (t >= 15) return 'severe';
        if (t >= 10) return 'moderate';
        if (t >= 5) return 'mild';
        return 'minimal';
      case ScreenerType.pcptsd5:
        return t >= 3 ? 'positive screen' : 'negative screen';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'at': at.toIso8601String(),
        'answers': answers,
        'total': total,
        'band': band,
        'severity': severity,
        'selfHarmPositive': selfHarmPositive,
      };

  factory ScreenerResult.fromMap(Map<String, dynamic> m) => ScreenerResult(
        id: m['id'] as String,
        type: ScreenerType.values.byName(m['type'] as String),
        at: DateTime.parse(m['at'] as String),
        answers: (m['answers'] as List).map((v) => (v as num?)?.toInt()).toList(),
      );
}
