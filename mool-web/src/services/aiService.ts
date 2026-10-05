// Groq AI Service for Mool Web Platform
// Uses Groq API (llama-3.3-70b-versatile) for AI chat and analysis
// Endpoint: https://api.groq.com/openai/v1/chat/completions

export interface AiChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface AiChatResponse {
  text: string;
  isAcuteCrisis: boolean;
  category?: string;
  sentiment?: number;     // -1.0 to 1.0
  emotion?: string;       // anger, fear, sadness, anxiety, hope, calm, neutral
  suggestedAction?: string;
}

export interface ExplainableInsight {
  factorName: string;
  contribution: number;   // 0-100 percentage
  explanation: string;
  trend: 'rising' | 'falling' | 'stable';
  severity: 'low' | 'moderate' | 'high' | 'critical';
}

export interface DistressPrediction {
  predictedScore7d: number;
  predictedTier: string;
  confidence: number;
  riskFactors: string[];
  recommendedInterventions: string[];
  reasoning: string;
}

export interface SentimentAnalysis {
  score: number;          // -1.0 (negative) to 1.0 (positive)
  emotion: string;
  distressIndicators: string[];
  hopeIndicators: string[];
}

// Acute crisis keywords — deterministic check, never bypassed
const ACUTE_CRISIS_KEYWORDS = [
  'kill myself', 'want to die', 'suicide', 'end it all', 'no reason to live',
  'harm myself', 'in danger right now', 'someone is hurting me', 'unsafe at home',
  'hurt myself', "can't take this anymore", 'end my life', 'take my life',
  'killing myself', 'unalive', 'self harm', 'cut myself', 'overdose',
];

// Grounded system prompt for trauma-informed AI
const MOOL_SYSTEM_PROMPT = `You are Mool (मूल), a trauma-informed mental health companion for victims of atrocities registered under the SC/ST Prevention of Atrocities Act, 1989 in India.

CORE PRINCIPLES:
- You are warm, patient, and deeply empathetic
- You speak simply and gently, avoiding clinical jargon
- You support in Hindi, English, and Hinglish naturally based on the user's language
- You NEVER diagnose, prescribe medication, or replace professional help
- You are a grounding presence, not a therapist

WHAT YOU DO:
- Help with grounding exercises (5-4-3-2-1, box breathing, body scan)
- Validate feelings without judgment
- Gently explore how they are feeling today
- Recognize signs of distress and suggest connecting with their counsellor
- Support through court hearing anxiety, intimidation fears, isolation
- Offer culturally sensitive coping techniques
- Remind them of their safety plan if they have one

SAFETY RULES:
- If someone expresses thoughts of self-harm or suicide, respond with empathy and immediately recommend connecting with their crisis helpline or counsellor
- Never minimize their experiences of caste-based violence or discrimination
- Always respect their pace — never push them to share more than they want
- Remind them that what happened was NOT their fault

CONTEXT:
- These are victims who may face threats, intimidation, repeated court appearances, social ostracism, economic hardship
- Many are from rural areas with limited access to mental health services

Keep responses concise (2-4 sentences usually). Be human, not robotic.`;

// System prompt for sentiment analysis (fast model)
const SENTIMENT_SYSTEM_PROMPT = `You are a clinical sentiment analyzer for a mental health platform serving victims of atrocities. 
Analyze the user's text and respond ONLY with a JSON object:
{
  "score": <number from -1.0 (very negative/distressed) to 1.0 (very positive/hopeful)>,
  "emotion": "<primary emotion: anger|fear|sadness|anxiety|hope|calm|neutral|distress>",
  "distressIndicators": ["<list of specific distress signals found>"],
  "hopeIndicators": ["<list of positive/resilience signals found>"]
}
Consider cultural context (Indian rural, caste-based discrimination victims). Be precise.`;

// System prompt for explainable AI analysis
const EXPLAINABLE_AI_PROMPT = `You are an explainable AI system for the Mool mental health monitoring platform. 
Given a ward's distress data, provide a clear, non-technical explanation of:
1. Why the distress score is at its current level
2. Which factors contributed most
3. What the predicted trajectory looks like
4. What interventions are recommended

Respond ONLY with a JSON object:
{
  "summary": "<2-3 sentence plain-language summary for the guardian>",
  "topFactors": [
    {"name": "<factor>", "contribution": <0-100>, "explanation": "<why this matters>", "trend": "rising|falling|stable", "severity": "low|moderate|high|critical"}
  ],
  "prediction": {
    "trajectory": "improving|stable|worsening|critical",
    "timeframe": "7 days",
    "confidence": <0-1>,
    "reasoning": "<why this prediction>"
  },
  "interventions": [
    {"type": "<counselling|medical|legal|witness_protection|financial|rehabilitation>", "priority": "immediate|soon|routine", "reason": "<why recommended>"}
  ],
  "alertLevel": "none|monitor|outreach|urgent|crisis"
}`;

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';

/**
 * Get the Groq API key from environment.
 * In production, this should be proxied through a backend/cloud function.
 */
function getApiKey(): string {
  return import.meta.env.VITE_GROQ_API_KEY || '';
}

// Active Groq models available on this account:
// 1. 'qwen/qwen3.8-27b' (fastest, high empathy, multilingual Hindi/English, structured JSON)
// 2. 'openai/gpt-oss-120b' (deep conversational reasoning)
// 3. 'openai/gpt-oss-20b' (lightweight fast conversation)
export const DEFAULT_GROQ_CHAT_MODEL = 'qwen/qwen3.8-27b';
export const DEFAULT_GROQ_FAST_MODEL = 'qwen/qwen3.8-27b';

/**
 * Raw Groq API call with automatic multi-model fallback.
 */
async function callGroq(
  messages: AiChatMessage[],
  primaryModel: string = DEFAULT_GROQ_CHAT_MODEL,
  temperature: number = 0.7,
  maxTokens: number = 512,
): Promise<string> {
  const apiKey = getApiKey();
  if (!apiKey) {
    throw new Error('GROQ_API_KEY not configured');
  }

  const candidateModels = Array.from(new Set([
    primaryModel,
    'qwen/qwen3.8-27b',
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
  ]));

  let lastError: Error | null = null;
  for (const model of candidateModels) {
    try {
      const response = await fetch(GROQ_API_URL, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messages,
          model,
          temperature,
          max_tokens: maxTokens,
          stream: false,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const content = data.choices?.[0]?.message?.content;
        if (content && content.trim().length > 0) {
          return content;
        }
      } else {
        const errText = await response.text();
        console.warn(`Groq model ${model} failed (${response.status}):`, errText);
        lastError = new Error(`Groq API error ${response.status} on ${model}: ${errText}`);
      }
    } catch (err: any) {
      console.warn(`Groq request error on ${model}:`, err);
      lastError = err;
    }
  }

  throw lastError || new Error('All Groq models failed');
}

/**
 * Send a chat message and get a grounded AI response.
 * Uses llama-3.3-70b-versatile for high-quality conversation.
 */
export async function getAiChatResponse(
  userInput: string,
  conversationHistory: AiChatMessage[] = [],
): Promise<AiChatResponse> {
  const lower = userInput.toLowerCase().trim();

  // 1. Deterministic crisis check (non-negotiable, never relies on AI)
  const containsAcuteCrisis = ACUTE_CRISIS_KEYWORDS.some(kw => lower.includes(kw));
  if (containsAcuteCrisis) {
    return {
      text: "I hear how much pain and distress you are in right now. Your safety and wellbeing are the most important thing. Please connect immediately with a trusted responder or crisis specialist who is ready to support you without judgment.",
      isAcuteCrisis: true,
      category: 'Crisis Safety',
      sentiment: -0.9,
      emotion: 'distress',
      suggestedAction: 'OPEN_CRISIS_OVERLAY',
    };
  }

  // 2. Build message context
  const messages: AiChatMessage[] = [
    { role: 'system', content: MOOL_SYSTEM_PROMPT },
    ...conversationHistory.slice(-10),
    { role: 'user', content: userInput },
  ];

  try {
    const reply = await callGroq(messages, DEFAULT_GROQ_CHAT_MODEL, 0.7, 512);

    // 3. Quick sentiment analysis in parallel (fast model)
    let sentiment: number | undefined;
    let emotion: string | undefined;
    try {
      const sentimentResult = await analyzeSentiment(userInput);
      sentiment = sentimentResult.score;
      emotion = sentimentResult.emotion;
    } catch {
      // Sentiment analysis is optional, don't block the response
    }

    // 4. Categorize the response
    const category = categorizeMessage(lower);

    return {
      text: reply,
      isAcuteCrisis: false,
      category,
      sentiment,
      emotion,
    };
  } catch (err) {
    console.warn('Groq chat error:', err);
    // Fallback to grounded static response
    return {
      text: "I am here listening quietly. Whatever you are feeling right now is valid and understandable. You are safe in this space, and you can take all the time you need. Would you like to share a bit more about how your body or mind feels today?",
      isAcuteCrisis: false,
      category: 'General Grounding',
    };
  }
}

/**
 * Analyze sentiment of text using the fast model.
 */
export async function analyzeSentiment(text: string): Promise<SentimentAnalysis> {
  try {
    const messages: AiChatMessage[] = [
      { role: 'system', content: SENTIMENT_SYSTEM_PROMPT },
      { role: 'user', content: text },
    ];

    const reply = await callGroq(messages, DEFAULT_GROQ_FAST_MODEL, 0.1, 256);

    // Parse JSON from the response
    const jsonMatch = reply.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        score: typeof parsed.score === 'number' ? parsed.score : 0,
        emotion: parsed.emotion || 'neutral',
        distressIndicators: Array.isArray(parsed.distressIndicators) ? parsed.distressIndicators : [],
        hopeIndicators: Array.isArray(parsed.hopeIndicators) ? parsed.hopeIndicators : [],
      };
    }
  } catch (err) {
    console.warn('Sentiment analysis error:', err);
  }

  // Fallback
  return { score: 0, emotion: 'neutral', distressIndicators: [], hopeIndicators: [] };
}

/**
 * Generate explainable AI insights for a ward's distress data.
 * Used by the Guardian portal to explain "why this score?"
 */
export async function getExplainableInsights(wardData: {
  displayName?: string;
  latestScore?: number;
  latestTier?: string;
  latestMood?: number;
  latestSleep?: number;
  latestSafety?: number;
  latestCoping?: number;
  latestNote?: string;
  recentCheckins?: any[];
  nextHearing?: string;
  intimidationReports?: number;
  compensationOverdue?: boolean;
  trendPerDay?: number;
  confidence?: number;
  drivers?: { text: string; points: number }[];
}): Promise<{
  summary: string;
  topFactors: ExplainableInsight[];
  prediction: DistressPrediction;
  interventions: { type: string; priority: string; reason: string }[];
  alertLevel: string;
}> {
  const dataDescription = `
Ward: ${wardData.displayName || 'Anonymous'}
Current Distress Score: ${wardData.latestScore ?? 'N/A'} / 100
Tier: ${wardData.latestTier || 'unknown'}
Confidence: ${wardData.confidence != null ? (wardData.confidence * 100).toFixed(0) + '%' : 'N/A'}

Latest Check-in:
- Mood: ${wardData.latestMood ?? 'N/A'} / 5
- Sleep: ${wardData.latestSleep ?? 'N/A'} / 5
- Safety: ${wardData.latestSafety ?? 'N/A'} / 5
- Coping: ${wardData.latestCoping ?? 'N/A'} / 5
${wardData.latestNote ? `- Note: "${wardData.latestNote}"` : ''}

Trend: ${wardData.trendPerDay != null ? (wardData.trendPerDay > 0 ? `Rising ${wardData.trendPerDay.toFixed(1)} pts/day` : `Falling ${Math.abs(wardData.trendPerDay).toFixed(1)} pts/day`) : 'Stable'}
${wardData.nextHearing ? `Next court hearing: ${wardData.nextHearing}` : ''}
${wardData.intimidationReports ? `Recent intimidation reports: ${wardData.intimidationReports}` : ''}
${wardData.compensationOverdue ? 'Compensation payment is overdue' : ''}

Key Drivers:
${wardData.drivers?.map(d => `- ${d.text} (+${d.points.toFixed(0)} pts)`).join('\n') || 'None identified'}

Recent Check-in Count: ${wardData.recentCheckins?.length ?? 0}
`;

  try {
    const messages: AiChatMessage[] = [
      { role: 'system', content: EXPLAINABLE_AI_PROMPT },
      { role: 'user', content: dataDescription },
    ];

    const reply = await callGroq(messages, DEFAULT_GROQ_FAST_MODEL, 0.3, 1024);

    const jsonMatch = reply.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        summary: parsed.summary || 'Unable to generate summary.',
        topFactors: (parsed.topFactors || []).map((f: any) => ({
          factorName: f.name || f.factorName || 'Unknown',
          contribution: f.contribution || 0,
          explanation: f.explanation || '',
          trend: f.trend || 'stable',
          severity: f.severity || 'low',
        })),
        prediction: {
          predictedScore7d: parsed.prediction?.predictedScore7d || wardData.latestScore || 0,
          predictedTier: parsed.prediction?.trajectory || wardData.latestTier || 'stable',
          confidence: parsed.prediction?.confidence || 0.5,
          riskFactors: parsed.prediction?.riskFactors || [],
          recommendedInterventions: [],
          reasoning: parsed.prediction?.reasoning || '',
        },
        interventions: parsed.interventions || [],
        alertLevel: parsed.alertLevel || 'monitor',
      };
    }
  } catch (err) {
    console.warn('Explainable AI error:', err);
  }

  // Fallback based on deterministic analysis
  return generateFallbackInsights(wardData);
}

/**
 * Deterministic fallback when the AI call fails.
 * Ensures guardians always see some explanation.
 */
function generateFallbackInsights(wardData: any) {
  const score = wardData.latestScore ?? 0;
  const tier = wardData.latestTier || 'stable';
  const factors: ExplainableInsight[] = [];

  if (wardData.latestMood != null && wardData.latestMood <= 2) {
    factors.push({
      factorName: 'Low Mood',
      contribution: 30,
      explanation: 'Recent check-ins indicate low mood, which contributes significantly to distress.',
      trend: 'stable',
      severity: wardData.latestMood === 1 ? 'high' : 'moderate',
    });
  }
  if (wardData.latestSafety != null && wardData.latestSafety <= 2) {
    factors.push({
      factorName: 'Safety Concerns',
      contribution: 25,
      explanation: 'Ward has reported feeling unsafe, suggesting potential threats or intimidation.',
      trend: 'stable',
      severity: 'high',
    });
  }
  if (wardData.latestSleep != null && wardData.latestSleep <= 2) {
    factors.push({
      factorName: 'Poor Sleep',
      contribution: 15,
      explanation: 'Sleep disturbance is common after trauma and is contributing to overall distress.',
      trend: 'stable',
      severity: 'moderate',
    });
  }
  if (wardData.intimidationReports && wardData.intimidationReports > 0) {
    factors.push({
      factorName: 'Intimidation',
      contribution: 20,
      explanation: `${wardData.intimidationReports} intimidation report(s) in recent weeks.`,
      trend: 'rising',
      severity: 'critical',
    });
  }

  return {
    summary: score >= 60
      ? 'This ward shows elevated distress levels that require attention. Multiple factors are contributing to their current state.'
      : score >= 40
        ? 'This ward shows moderate distress. Continue regular check-ins and monitor for changes.'
        : 'This ward appears relatively stable. Maintain regular monitoring.',
    topFactors: factors,
    prediction: {
      predictedScore7d: score,
      predictedTier: tier,
      confidence: 0.3,
      riskFactors: factors.filter(f => f.severity === 'high' || f.severity === 'critical').map(f => f.factorName),
      recommendedInterventions: [],
      reasoning: 'Based on available check-in data and contextual factors.',
    },
    interventions: score >= 60
      ? [{ type: 'counselling', priority: 'soon', reason: 'Elevated distress requires professional support.' }]
      : [],
    alertLevel: tier === 'urgent' || tier === 'crisis' ? 'urgent' : tier === 'outreach' ? 'outreach' : 'monitor',
  };
}

/**
 * Categorize a message into a support category.
 */
function categorizeMessage(lower: string): string {
  if (/flashback|nightmare|memory|trauma|remind|ptsd|past/.test(lower)) return 'Trauma & Grounding';
  if (/anxious|panic|heart racing|fear|terrified|worry|overwhelm/.test(lower)) return 'Anxiety & Grounding';
  if (/sad|lonely|isolated|empty|heavy|crying|hopeless|numb/.test(lower)) return 'Emotional Coping';
  if (/sleep|insomnia|can't sleep|night|tired|rest/.test(lower)) return 'Sleep & Wellbeing';
  if (/guilt|blame|ashamed|my fault|why me|shame/.test(lower)) return 'Self-Compassion';
  if (/court|hearing|judge|lawyer|case|trial|justice/.test(lower)) return 'Legal Support';
  if (/threat|intimidat|follow|stalk|unsafe|danger/.test(lower)) return 'Safety & Protection';
  if (/breath|ground|calm|exercise|meditat|relax/.test(lower)) return 'Grounding Exercise';
  if (/money|job|work|financial|payment|compensat/.test(lower)) return 'Economic Support';
  return 'General Grounding';
}
