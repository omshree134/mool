import { IvrsCoreEngine, IvrsCallState, IVRS_PROMPTS } from './core';
import { saveFirestoreDoc } from '../../firestore';

export interface SimulatorStartResponse {
  callId: string;
  state: IvrsCallState;
  prompt: {
    step: string;
    textHi: string;
    textEn: string;
    requiresDtmf: boolean;
    requiresRecording: boolean;
  };
}

export interface SimulatorInputPayload {
  state: IvrsCallState;
  dtmf?: string;
  recordingUrl?: string;
}

export class SimulatorAdapter {
  static handleStart(beneficiaryId: string, lang: 'hi' | 'en' | 'mr'): SimulatorStartResponse {
    const state = IvrsCoreEngine.startCall(beneficiaryId, lang);
    return {
      callId: state.callId,
      state,
      prompt: IVRS_PROMPTS.sleep,
    };
  }

  static async handleInput(
    payload: SimulatorInputPayload,
    env: {
      FIREBASE_PROJECT_ID: string;
      FIREBASE_SA_JSON?: string;
      RENDER_URL: string;
    },
    ctx: { waitUntil(promise: Promise<any>): void }
  ) {
    const { nextState, prompt, intimidationTriggered, callCompleted } =
      IvrsCoreEngine.processStep(payload.state, {
        dtmf: payload.dtmf,
        recordingUrl: payload.recordingUrl,
      });

    // 1. If threat/intimidation was reported (DTMF 1 on threat step)
    if (intimidationTriggered) {
      ctx.waitUntil(
        saveFirestoreDoc(
          env.FIREBASE_PROJECT_ID,
          'cases',
          `threat_${Date.now()}`,
          {
            beneficiary_id: payload.state.beneficiaryId,
            event_type: 'intimidation',
            source: 'ivrs_simulator_dtmf_1',
            severity: 'critical',
            createdAt: new Date().toISOString(),
          },
          env.FIREBASE_SA_JSON
        )
      );

      // Trigger Render background forecast recalculation
      ctx.waitUntil(
        fetch(`${env.RENDER_URL}/jobs/run`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            job_type: 'threat_escalation',
            bid: payload.state.beneficiaryId,
          }),
        }).catch(() => {})
      );
    }

    // 2. If call completed (or recording received), save final check-in observation
    if (nextState.currentStep === 'closing' || callCompleted) {
      const sleepScore = nextState.sleepValue === 3 ? 75 : nextState.sleepValue === 2 ? 45 : 20;
      const finalScore = nextState.threatReported ? Math.min(100, sleepScore + 25) : sleepScore;

      const oid = `obs_sim_${crypto.randomUUID().slice(0, 10)}`;
      ctx.waitUntil(
        saveFirestoreDoc(
          env.FIREBASE_PROJECT_ID,
          'observations',
          oid,
          {
            oid,
            bid: payload.state.beneficiaryId,
            channel: 'ivrs_simulator',
            kind: 'voice_checkin',
            sleep_value: nextState.sleepValue,
            threat_reported: nextState.threatReported,
            recording_url: nextState.recordingUrl,
            score: finalScore,
            tier: finalScore >= 80 ? 'urgent' : finalScore >= 60 ? 'outreach' : 'stable',
            createdAt: new Date().toISOString(),
          },
          env.FIREBASE_SA_JSON
        )
      );

      // If audio was submitted, trigger Render voice analysis
      if (nextState.recordingUrl) {
        ctx.waitUntil(
          fetch(`${env.RENDER_URL}/jobs/run`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              job_type: 'voice_recording_process',
              bid: payload.state.beneficiaryId,
              recording_url: nextState.recordingUrl,
            }),
          }).catch(() => {})
        );
      }
    }

    return {
      state: nextState,
      prompt,
      intimidationTriggered,
      callCompleted,
    };
  }
}
