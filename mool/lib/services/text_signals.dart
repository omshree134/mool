/// On-device reading of check-in notes. Nothing here sends text anywhere.
///
/// Crisis phrases are a gate, not an alarm: a match makes Mool ask the person
/// directly ("Are you having thoughts of ending your life?"). Only a "yes"
/// reaches the counsellor as a crisis. Asking directly is what clinicians do,
/// it does not increase risk, and it removes false positives such as
/// "my cousin attempted suicide" or "I would never hurt myself".
class TextSignals {
  static final _wordRe = RegExp(r"[a-z']+");

  static List<String> tokens(String text) => _wordRe
      .allMatches(text.toLowerCase().replaceAll('\u2019', "'"))
      .map((m) => m.group(0)!)
      .toList();

  static const _negators = {
    'not', 'never', 'no', "don't", 'dont', "didn't", 'didnt', "won't", 'wont',
    "wouldn't", 'wouldnt', "isn't", 'isnt', "wasn't", 'wasnt', 'nobody',
  };

  static const _crisisPhrases = [
    'kill myself', 'killing myself', 'kms', 'unalive', 'unalive myself',
    'end my life', 'ending my life', 'take my life', 'take my own life',
    'want to die', 'wanna die', 'wish i was dead', 'wish i were dead',
    'better off dead', 'better off without me', 'suicide', 'suicidal',
    'hurt myself', 'hurting myself', 'harm myself', 'self harm', 'cut myself',
    'no reason to live', 'nothing to live for', "can't go on", 'cant go on',
    'cannot go on', "don't want to live", 'dont want to live', 'do not want to live',
    "don't want to be alive", 'end it all', 'overdose', 'not be here anymore',
  ];

  static final List<List<String>> _crisisTokens = _crisisPhrases.map(tokens).toList();

  /// True when [text] might express thoughts of suicide or self-harm.
  static bool mightExpressCrisis(String text) {
    final t = tokens(text);
    for (final phrase in _crisisTokens) {
      if (phrase.isEmpty) continue;
      for (var i = 0; i + phrase.length <= t.length; i++) {
        var match = true;
        for (var j = 0; j < phrase.length; j++) {
          if (t[i + j] != phrase[j]) {
            match = false;
            break;
          }
        }
        if (!match) continue;
        // "I would never kill myself", "I don't want to die"
        final before = t.sublist((i - 3).clamp(0, t.length), i);
        if (before.any(_negators.contains)) continue;
        return true;
      }
    }
    return false;
  }

  static const _negativeWords = {
    'hopeless', 'worthless', 'useless', 'alone', 'lonely', 'scared', 'afraid',
    'frightened', 'terrified', 'tired', 'exhausted', 'cry', 'cried', 'crying',
    'hurt', 'pain', 'angry', 'trapped', 'ashamed', 'shame', 'guilty', 'numb',
    'empty', 'panic', 'anxious', 'worried', 'worry', 'nightmare', 'nightmares',
    'threat', 'threatened', 'unsafe', 'helpless', 'lost', 'broken', 'sad',
    'miserable', 'hate', 'awful', 'terrible', 'bad', 'worse', 'worst', 'stressed',
    'overwhelmed', 'humiliated', 'insulted', 'harassed', 'beaten', 'sick',
  };

  static const _positiveWords = {
    'better', 'calm', 'okay', 'ok', 'fine', 'good', 'happy', 'safe', 'hope',
    'hopeful', 'relieved', 'grateful', 'strong', 'rested', 'peaceful', 'glad',
    'supported', 'helped', 'laughed', 'enjoyed', 'proud', 'great',
  };

  /// 0–1 share of negative tone. Returns null for very short notes.
  /// This is a simple lexicon, weighted lightly in the engine; a proper NLP
  /// model can replace it later without changing the engine.
  static double? negativity(String text) {
    final t = tokens(text);
    if (t.length < 3) return null;
    var neg = 0.0;
    var pos = 0.0;
    for (var i = 0; i < t.length; i++) {
      final w = t[i];
      final negated = (i > 0 && _negators.contains(t[i - 1])) || (i > 1 && _negators.contains(t[i - 2]));
      if (_negativeWords.contains(w)) {
        if (negated) {
          pos += 0.5;
        } else {
          neg += 1;
        }
      } else if (_positiveWords.contains(w)) {
        if (negated) {
          neg += 1;
        } else {
          pos += 1;
        }
      }
    }
    if (neg + pos == 0) return 0.2;
    return neg / (neg + pos);
  }
}
