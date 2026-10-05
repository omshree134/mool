// INTEGRATION POINT 3 & 4: Firebase Cloud Functions Stubs
import { getFunctions, httpsCallable } from 'firebase/functions';
import { app } from './config';
import { QrToken, DistressEvent } from '../../types';

export const functions = getFunctions(app, import.meta.env.VITE_FIREBASE_FUNCTIONS_REGION || 'asia-south1');

/**
 * INTEGRATION POINT 2 & 3: QR Token Exchange Cloud Function
 * Validates pairing token against Firestore and mints custom auth token for survivor
 */
export async function exchangeQrToken(token: string): Promise<{ customToken: string; beneficiaryId: string; pseudonym: string }> {
  try {
    const exchangeFn = httpsCallable<{ token: string }, { customToken: string; beneficiaryId: string; pseudonym: string }>(functions, 'exchangeQrToken');
    const result = await exchangeFn({ token });
    return result.data;
  } catch (err) {
    console.warn('[Mool Integration Point] Using mock exchangeQrToken fallback for frontend demo.');
    // Simulated token validation response
    if (token.length > 5) {
      return {
        customToken: 'mock-custom-firebase-token-survivor-882',
        beneficiaryId: 'survivor-882',
        pseudonym: 'Aarav (Pseudonym)',
      };
    }
    throw new Error('Invalid or expired pairing code.');
  }
}

/**
 * INTEGRATION POINT 3: QR Token Generator Cloud Function
 * Web-side caseworker generates a 24h paired QR token for a newly registered beneficiary
 */
export async function generateQrToken(beneficiaryId: string, caseworkerId: string): Promise<QrToken> {
  try {
    const generateFn = httpsCallable<{ beneficiaryId: string; caseworkerId: string }, QrToken>(functions, 'generateQrToken');
    const result = await generateFn({ beneficiaryId, caseworkerId });
    return result.data;
  } catch (err) {
    console.warn('[Mool Integration Point] Using mock generateQrToken fallback for frontend demo.');
    const mockToken = `mool-pair-${Math.random().toString(36).substring(2, 10)}-${Date.now()}`;
    return {
      token: mockToken,
      beneficiaryId,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      used: false,
      caseworkerId,
    };
  }
}

/**
 * INTEGRATION POINT 4: AI Distress Prediction Service Cloud Function
 * Calls the ML model service to compute distress scores and risk flags
 */
export async function predictDistress(beneficiaryId: string, history: any[]): Promise<{
  distressScore: number;
  severity: 'low' | 'moderate' | 'high' | 'critical';
  riskFactors: string[];
  explanation: string;
}> {
  try {
    const predictFn = httpsCallable<{ beneficiaryId: string; history: any[] }, any>(functions, 'predictDistress');
    const result = await predictFn({ beneficiaryId, history });
    return result.data;
  } catch (err) {
    console.warn('[Mool Integration Point] Using mock predictDistress ML model response.');
    return {
      distressScore: 0.74,
      severity: 'high',
      riskFactors: ['Abrupt drop in daily check-ins', 'High frequency of distress keywords in audio notes', 'Disrupted sleep pattern reports'],
      explanation: 'Temporal analysis indicates significant deviation from baseline grounding levels over the last 72 hours.',
    };
  }
}

