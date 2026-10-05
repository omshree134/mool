/**
 * Provider-Neutral IVRS Call Flow State Machine
 *
 * Implements the standard 4-step survivor trauma check-in:
 * 1. SLEEP: Keypad question (1 = good, 2 = fair, 3 = restless/anxious)
 * 2. THREAT: Keypad question (1 = YES threat/intimidation reported, 2 = NO)
 *    -> If 1: Immediately registers intimidation milestone & flags high-priority alert!
 * 3. VOICE: 45s open voice reflection recorded for openSMILE / Whisper analysis.
 * 4. CLOSING: Reassurance and emergency helpline numbers.
 */

export interface IvrsCallState {
  callId: string;
  beneficiaryId: string;
  language: 'hi' | 'en' | 'mr';
  currentStep: 'sleep' | 'threat' | 'voice' | 'closing' | 'completed';
  sleepValue?: number;
  threatReported?: boolean;
  recordingUrl?: string;
  startedAt: string;
  completedAt?: string;
}

export interface PromptDefinition {
  step: 'sleep' | 'threat' | 'voice' | 'closing';
  textHi: string;
  textEn: string;
  requiresDtmf: boolean;
  requiresRecording: boolean;
  validDigits?: string[];
}

export const IVRS_PROMPTS: Record<string, PromptDefinition> = {
  sleep: {
    step: 'sleep',
    textHi: 'नमस्कार। मूल में आपका स्वागत है। अपनी नींद के बारे में बताएं। अच्छी नींद के लिए एक दबाएं, सामान्य के लिए दो, बेचैनी या चिंता के लिए तीन दबाएं।',
    textEn: 'Welcome to Mool. How has your sleep been? Press 1 for restful, 2 for moderate, or 3 for restless and troubled.',
    requiresDtmf: true,
    requiresRecording: false,
    validDigits: ['1', '2', '3'],
  },
  threat: {
    step: 'threat',
    textHi: 'क्या पिछले कुछ दिनों में किसी ने आपको या आपके परिवार को डराने, धमकाने या केस वापस लेने का दबाव बनाया है? यदि हाँ, तो तुरंत एक दबाएं। यदि नहीं, तो दो दबाएं।',
    textEn: 'Has anyone threatened, intimidated, or pressured you to withdraw your case recently? Press 1 for Yes, or 2 for No.',
    requiresDtmf: true,
    requiresRecording: false,
    validDigits: ['1', '2'],
  },
  voice: {
    step: 'voice',
    textHi: 'कृपया बीप की आवाज के बाद अपने मन की बात संक्षेप में कहें। आप क्या महसूस कर रहे हैं? रिकॉर्डिंग समाप्त होने पर कोई भी बटन दबाएं।',
    textEn: 'Please speak briefly after the beep about how you are feeling today. Press any key when finished.',
    requiresDtmf: false,
    requiresRecording: true,
  },
  closing: {
    step: 'closing',
    textHi: 'आपकी आवाज और उत्तर सुरक्षित रूप से दर्ज कर लिए गए हैं। याद रखें, आप अकेले नहीं हैं। किसी भी समय सहायता के लिए टेली-मानस 14416 या आपातकालीन 112 डायल करें। धन्यवाद।',
    textEn: 'Your responses have been securely recorded. Remember, you are not alone. For immediate support, call Tele-MANAS at 14416 or 112. Thank you.',
    requiresDtmf: false,
    requiresRecording: false,
  },
};

export class IvrsCoreEngine {
  /**
   * Initializes a new call session
   */
  static startCall(beneficiaryId: string = 'BEN-LKO-001', lang: 'hi' | 'en' | 'mr' = 'hi'): IvrsCallState {
    return {
      callId: `call_${crypto.randomUUID().slice(0, 10)}`,
      beneficiaryId,
      language: lang,
      currentStep: 'sleep',
      startedAt: new Date().toISOString(),
    };
  }

  /**
   * Processes the user's action (DTMF digit or voice recording) and advances the state
   */
  static processStep(
    state: IvrsCallState,
    input: { dtmf?: string; recordingUrl?: string }
  ): {
    nextState: IvrsCallState;
    prompt: PromptDefinition;
    intimidationTriggered: boolean;
    callCompleted: boolean;
  } {
    const nextState = { ...state };
    let intimidationTriggered = false;
    let callCompleted = false;

    if (state.currentStep === 'sleep') {
      const val = parseInt(input.dtmf || '2', 10);
      nextState.sleepValue = isNaN(val) ? 2 : val;
      nextState.currentStep = 'threat';
      return {
        nextState,
        prompt: IVRS_PROMPTS.threat,
        intimidationTriggered: false,
        callCompleted: false,
      };
    }

    if (state.currentStep === 'threat') {
      const isThreat = input.dtmf === '1';
      nextState.threatReported = isThreat;
      nextState.currentStep = 'voice';
      if (isThreat) {
        intimidationTriggered = true;
      }
      return {
        nextState,
        prompt: IVRS_PROMPTS.voice,
        intimidationTriggered,
        callCompleted: false,
      };
    }

    if (state.currentStep === 'voice') {
      nextState.recordingUrl = input.recordingUrl || 'simulated_audio_blob_url';
      nextState.currentStep = 'closing';
      return {
        nextState,
        prompt: IVRS_PROMPTS.closing,
        intimidationTriggered: false,
        callCompleted: false,
      };
    }

    // Closing -> completed
    nextState.currentStep = 'completed';
    nextState.completedAt = new Date().toISOString();
    return {
      nextState,
      prompt: IVRS_PROMPTS.closing,
      intimidationTriggered: false,
      callCompleted: true,
    };
  }
}
