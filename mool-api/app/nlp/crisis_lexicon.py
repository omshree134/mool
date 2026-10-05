import re
from typing import Tuple, Optional

# Clinician-reviewed crisis and self-harm keywords across English, Hindi, and Hinglish.
# Deterministic match triggers immediate crisis path without waiting for LLM inference.
CRISIS_PATTERNS = [
    # English explicit self-harm / crisis
    r"\b(want to die|kill myself|end my life|commit suicide|better off dead|no reason to live)\b",
    r"\b(hang myself|cut my wrists|overdose|take all pills)\b",
    r"\b(threatened to murder|going to kill me|will shoot us)\b",

    # Hindi Devanagari explicit crisis
    r"(मरना चाहता हूँ|मरना चाहती हूँ|आत्महत्या|जान दे दूंगा|जान दे दूंगी)",
    r"(जीने की कोई वजह नहीं|सब खत्म करना चाहता हूँ|सब खत्म करना चाहती हूँ)",
    r"(जान से मारने की धमकी|मार डालेंगे|गोली मार देंगे|जिंदा जला देंगे)",

    # Hinglish / Romanized Hindi explicit crisis
    r"\b(mar jaana chahta|mar jana chahti|khatam kar dunga|khatam kar dungi)\b",
    r"\b(aatmhatya|suicide kar|apni jaan le|jeena nahi chahta|jeena nahi chahti)\b",
    r"\b(sab khatam kar|jaan se maar|maar dalenge|goli maar denge)\b",
]

_COMPILED_PATTERNS = [re.compile(p, re.IGNORECASE) for p in CRISIS_PATTERNS]


def check_crisis_lexicon(text: str) -> Tuple[bool, Optional[str]]:
    """
    Deterministic check for self-harm or imminent danger.
    Runs instantaneously on CPU; never fails due to API timeouts or rate limits.
    Returns: (is_crisis, matched_phrase)
    """
    if not text:
        return False, None

    normalized = " ".join(text.split()).strip()
    for pattern in _COMPILED_PATTERNS:
        match = pattern.search(normalized)
        if match:
            return True, match.group(0)

    return False, None
