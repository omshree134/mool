import { getFirestore, collection, doc, setDoc, getDoc, getDocs, query, where, orderBy, limit } from 'firebase/firestore';
import { app } from './config';
import { Beneficiary, CheckinEntry, DistressEvent, AuditLogEntry, QrToken } from '../../types';

export const db = getFirestore(app);

// Typed collection reference getters
export const collections = {
  beneficiaries: collection(db, 'beneficiaries'),
  qrTokens: collection(db, 'qrTokens'),
  checkins: collection(db, 'checkins'),
  distressEvents: collection(db, 'distressEvents'),
  responders: collection(db, 'responders'),
  auditLog: collection(db, 'auditLog'),
};

/**
 * Firestore CRUD Operations (Stubbed interface ready for live collection connection)
 */

export async function saveCheckin(entry: Partial<CheckinEntry>): Promise<string> {
  const newRef = doc(collections.checkins);
  const checkinData: CheckinEntry = {
    id: newRef.id,
    beneficiaryId: entry.beneficiaryId || 'anon-survivor-1',
    timestamp: new Date().toISOString(),
    moodScore: entry.moodScore || 3,
    note: entry.note || '',
    voiceUrl: entry.voiceUrl || '',
    tags: entry.tags || [],
  };
  
  // Try saving to firestore if online, fallback to local state gracefully
  try {
    await setDoc(newRef, checkinData);
  } catch (err) {
    console.warn('[Mool Firestore] Operating in local offline-first mode:', err);
  }
  return newRef.id;
}

export async function logAuditEvent(event: Omit<AuditLogEntry, 'id' | 'timestamp'>): Promise<void> {
  try {
    const newRef = doc(collections.auditLog);
    await setDoc(newRef, {
      ...event,
      id: newRef.id,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.warn('[Mool Audit] Local log fallback:', event);
  }
}

