import re

# Regex patterns for identifying sensitive personally identifiable information (PII)
# Protects victim identities under Section 72 of Bharatiya Nyaya Sanhita (BNS) & SC/ST (PoA) Act.
PHONE_PATTERN = re.compile(r"\b(?:\+?91[\-\s]?)?[6-9]\d{4}[\-\s]?\d{5}\b")
AADHAAR_PATTERN = re.compile(r"\b\d{4}\s\d{4}\s\d{4}\b")
FIR_PATTERN = re.compile(r"\b(?:FIR|Crime)\s*(?:No\.?|Number)?\s*[\w\d\/\-]+\b", re.IGNORECASE)
LOCATION_PATTERN = re.compile(r"\b(?:village|gaaon|gram|ps|police station|thana|tehsil|taluka)\s+([A-Za-z\u0900-\u097F]+)\b", re.IGNORECASE)
NAME_HONORIFICS = re.compile(r"\b(?:Mr\.|Mrs\.|Ms\.|Shri|Smt\.|Kumari|Advocate|Adv\.)\s+([A-Za-z\u0900-\u097F]+(?:\s+[A-Za-z\u0900-\u097F]+)?)\b")


def pseudonymise_text(text: str) -> str:
    """
    Strips survivor names, village locations, telephone numbers, and FIR IDs
    before sending text to external LLMs or third-party inference endpoints.
    """
    if not text:
        return ""

    result = PHONE_PATTERN.sub("[PHONE]", text)
    result = AADHAAR_PATTERN.sub("[ID_NUMBER]", result)
    result = FIR_PATTERN.sub("[FIR_REFERENCE]", result)
    result = LOCATION_PATTERN.sub("[LOCATION]", result)
    result = NAME_HONORIFICS.sub("[NAME]", result)

    return result
