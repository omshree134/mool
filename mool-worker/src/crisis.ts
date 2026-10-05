/**
 * Clinician-reviewed deterministic crisis keywords across English, Hindi, and Hinglish.
 * Evaluated instantly on Cloudflare Worker edge (0ms latency, zero reliance on external LLM availability).
 */

export const CRISIS_LEXICON = {
  suicide_self_harm: [
    "suicide", "kill myself", "end my life", "want to die", "better off dead",
    "hang myself", "cut myself", "take all the pills", "no reason to live",
    "mar jana chahta hoon", "mar jana chahti hoon", "aatmhatya", "jaan de dunga",
    "jeena nahi chahta", "jeena nahi chahti", "marne ka man kar raha hai",
    "zindagi khatam", "suicide karna", "phaasi", "zeher", "sab khatam karna hai"
  ],
  imminent_threat: [
    "they are outside", "they will kill me", "threatened to shoot", "gundey aaye hain",
    "maar dalenge", "ghar pe aaye the", "dhamki di hai", "raaste mein roka",
    "pistol dikhayi", "hathiyar leke", "they have weapons", "they came to my house",
    "case wapas lo nahi toh", "withdraw the case or else", "goli maar denge"
  ]
};

export interface CrisisCheckResult {
  isCrisis: boolean;
  category: "suicide_self_harm" | "imminent_threat" | null;
  matchedSpan: string | null;
}

export function checkCrisisKeywords(text: string): CrisisCheckResult {
  if (!text || text.trim().length === 0) {
    return { isCrisis: false, category: null, matchedSpan: null };
  }

  const normalized = text.toLowerCase();

  for (const phrase of CRISIS_LEXICON.suicide_self_harm) {
    if (normalized.includes(phrase)) {
      return {
        isCrisis: true,
        category: "suicide_self_harm",
        matchedSpan: phrase,
      };
    }
  }

  for (const phrase of CRISIS_LEXICON.imminent_threat) {
    if (normalized.includes(phrase)) {
      return {
        isCrisis: true,
        category: "imminent_threat",
        matchedSpan: phrase,
      };
    }
  }

  return { isCrisis: false, category: null, matchedSpan: null };
}
