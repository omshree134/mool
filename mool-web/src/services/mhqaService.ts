// INTEGRATION POINT 5: MHQA Dataset — Now powered by Groq AI
// This file re-exports from the new aiService for backward compatibility.
// The original keyword-matching logic has been replaced with Groq API calls.

import { getAiChatResponse } from './aiService';

export interface SupportResponse {
  text: string;
  isAcuteCrisis: boolean;
  category?: string;
  suggestedAction?: string;
}

/**
 * INTEGRATION POINT 5: getSupportResponse
 * Now powered by Groq AI (llama-3.3-70b-versatile) through aiService.
 * Falls back to grounded static responses if the API is unavailable.
 */
export async function getSupportResponse(userInput: string): Promise<SupportResponse> {
  const response = await getAiChatResponse(userInput);
  return {
    text: response.text,
    isAcuteCrisis: response.isAcuteCrisis,
    category: response.category,
    suggestedAction: response.suggestedAction,
  };
}
