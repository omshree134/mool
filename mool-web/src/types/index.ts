export type UserRole = 'survivor' | 'caseworker' | 'analyst' | 'admin';

export type ConsentStatus = 'granted' | 'paused' | 'revoked';

export interface Beneficiary {
  id: string;
  pseudonym: string;
  consentStatus: ConsentStatus;
  language: string;
  createdAt: string;
  linkedCaseworker: string;
  emergencyContact?: string;
  region: string;
  lastCheckinDaysAgo?: number;
  currentRiskLevel: 'low' | 'moderate' | 'high' | 'critical';
}

export interface QrToken {
  token: string;
  beneficiaryId: string;
  expiresAt: string;
  used: boolean;
  caseworkerId: string;
}

export interface CheckinEntry {
  id: string;
  beneficiaryId: string;
  timestamp: string;
  moodScore: number; // 1 (struggling) to 5 (grounded)
  note?: string;
  voiceUrl?: string;
  voiceDurationSeconds?: number;
  tags?: string[];
}

export type AlertSeverity = 'low' | 'moderate' | 'high' | 'critical';
export type AlertStatus = 'open' | 'acknowledged' | 'escalated' | 'closed';

export interface DistressEvent {
  id: string;
  beneficiaryId: string;
  beneficiaryPseudonym: string;
  timestamp: string;
  severity: AlertSeverity;
  source: 'prediction' | 'selfreport';
  status: AlertStatus;
  riskFactors: string[];
  explanation: string;
  assignedCaseworker: string;
  region: string;
  forecastProbability?: number;
  shapDrivers?: string[];
  slaDeadline?: string;
  slaEscalationLevel?: string;
  recommendedIntervention?: string;
  statutoryMilestone?: string;
  notes?: Array<{
    id: string;
    author: string;
    text: string;
    timestamp: string;
  }>;
}

export interface AuditLogEntry {
  id: string;
  actorId: string;
  actorName: string;
  actorRole: UserRole;
  action: string;
  targetId: string;
  targetType: 'beneficiary' | 'distress_event' | 'system';
  timestamp: string;
  ipAddress: string;
  justification: string;
}

export interface MHQAQAItem {
  id: string;
  question: string;
  answer: string;
  category: string;
}

