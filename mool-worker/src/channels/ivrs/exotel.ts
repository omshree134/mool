import { IvrsCoreEngine, IVRS_PROMPTS } from './core';

/**
 * Exotel Telephony Adapter
 *
 * Exotel uses an HTTP GET/POST webhook model with ExoML (similar to TwiML).
 * This adapter maps Exotel's CallSid, From, Digits, and RecordingUrl directly into IvrsCoreEngine.
 */
export class ExotelAdapter {
  static handleIncomingCall(fromNumber: string, callSid: string, lang: 'hi' | 'en' = 'hi') {
    // Return ExoML or JSON instructions for Exotel flow
    return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Gather action="/ivrs/exotel/answer?lang=${lang}&amp;step=sleep" numDigits="1" timeout="8">
        <Say language="${lang === 'hi' ? 'hi-IN' : 'en-IN'}">
            ${IVRS_PROMPTS.sleep.textHi}
        </Say>
    </Gather>
</Response>`;
  }

  static handleAnswer(step: string, digits: string, callSid: string, lang: 'hi' | 'en' = 'hi') {
    if (step === 'sleep') {
      return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Gather action="/ivrs/exotel/answer?lang=${lang}&amp;step=threat&amp;sleep_val=${digits}" numDigits="1" timeout="8">
        <Say language="${lang === 'hi' ? 'hi-IN' : 'en-IN'}">
            ${IVRS_PROMPTS.threat.textHi}
        </Say>
    </Gather>
</Response>`;
    }

    if (step === 'threat') {
      return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say language="${lang === 'hi' ? 'hi-IN' : 'en-IN'}">
        ${IVRS_PROMPTS.voice.textHi}
    </Say>
    <Record maxLength="45" action="/ivrs/exotel/recording-callback" />
</Response>`;
    }

    return `<?xml version="1.0" encoding="UTF-8"?><Response><Hangup/></Response>`;
  }
}
