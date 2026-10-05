/**
 * Mool Cloud Functions (Node 20, Firebase Functions v2, region asia-south1).
 *
 *  redeemPairingCode   callable   links a member to a counsellor with a one-time code
 *  onDailyWritten      firestore  opens an alert when a member's tier rises to outreach or above
 *  onSosCreated        firestore  opens an SOS alert
 *  onRequestCreated    firestore  opens a callback alert ("ask my counsellor to call me")
 *  onReportCreated     firestore  opens an intimidation alert
 *  escalateAlerts      schedule   every 10 min: unacknowledged alerts climb
 *                                 counsellor -> district officer -> state officer
 *
 * Notifications to staff never contain the member's name or details, only that
 * an alert needs attention. The dashboard shows details after login.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

const TIER_RANK = { insufficientData: 0, stable: 1, watch: 2, outreach: 3, urgent: 4, crisis: 5 };

// Minutes before an unacknowledged alert moves up one level.
const SLA_MINUTES = {
  sos: 10,
  crisis: 30,
  urgent: 240,
  callback: 240,
  intimidation: 720,
  outreach: 1440,
};

const LEVEL_ROLES = ['counsellor', 'district', 'state'];

async function staffTokensForLevel(member, level) {
  let snap;
  if (level === 0) {
    if (!member.counsellorId) return [];
    const doc = await db.doc(`staff/${member.counsellorId}`).get();
    return (doc.data()?.fcmTokens) || [];
  }
  const role = LEVEL_ROLES[Math.min(level, LEVEL_ROLES.length - 1)];
  let q = db.collection('staff').where('role', '==', role);
  if (role === 'district' && member.district) q = q.where('district', '==', member.district);
  if (role === 'state' && member.state) q = q.where('state', '==', member.state);
  snap = await q.limit(20).get();
  return snap.docs.flatMap((d) => d.data().fcmTokens || []);
}

async function notify(member, level, type) {
  const tokens = [...new Set(await staffTokensForLevel(member, level))];
  if (tokens.length === 0) {
    logger.warn('No staff tokens for alert', { level, type });
    return;
  }
  const urgent = ['sos', 'crisis'].includes(type);
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: urgent ? 'Urgent: an alert needs attention now' : 'An alert needs attention',
      body: level > 0 ? 'This alert has not been acknowledged in time.' : 'Open the Mool dashboard to review.',
    },
    data: { type, level: String(level) },
    webpush: { fcmOptions: { link: '/alerts' } },
  });
  logger.info('Alert notifications sent', { success: res.successCount, failure: res.failureCount });
}

async function openAlert(memberId, type, reason, sourcePath) {
  // One open alert per member per type: avoids repeat pages for the same thing.
  const existing = await db
    .collection('alerts')
    .where('memberId', '==', memberId)
    .where('type', '==', type)
    .where('status', '==', 'open')
    .limit(1)
    .get();
  if (!existing.empty) {
    await existing.docs[0].ref.update({ lastSeenAt: FieldValue.serverTimestamp(), reason });
    return;
  }

  const memberSnap = await db.doc(`members/${memberId}`).get();
  const member = memberSnap.data() || {};
  const now = Timestamp.now();
  const sla = SLA_MINUTES[type] ?? 1440;

  await db.collection('alerts').add({
    memberId,
    counsellorId: member.counsellorId || null,
    district: member.district || null,
    state: member.state || null,
    type,
    reason,
    sourcePath,
    status: 'open',
    level: 0,
    createdAt: now,
    escalateAt: Timestamp.fromMillis(now.toMillis() + sla * 60 * 1000),
  });
  await notify(member, 0, type);
}

// ── Pairing ────────────────────────────────────────────────────────
exports.redeemPairingCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const code = String(request.data?.code || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (code.length !== 8) throw new HttpsError('invalid-argument', 'Bad code.');

  return db.runTransaction(async (tx) => {
    const ref = db.doc(`pairingCodes/${code}`);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Code not found.');
    const c = snap.data();
    if (c.used || c.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError('failed-precondition', 'Code expired or used.');
    }
    tx.update(ref, { used: true, usedBy: uid, usedAt: FieldValue.serverTimestamp() });
    tx.set(
      db.doc(`members/${uid}`),
      {
        counsellorId: c.counsellorId,
        counsellorName: c.counsellorName || null,
        caseId: c.caseId || null,
        district: c.district || null,
        state: c.state || null,
        linkedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(db.collection('auditLogs').doc(), {
      actor: uid,
      action: 'member.linked',
      target: `members/${uid}`,
      counsellorId: c.counsellorId,
      at: FieldValue.serverTimestamp(),
    });
    return { counsellorName: c.counsellorName || 'your counsellor' };
  });
});

// ── Alert sources ─────────────────────────────────────────────────
exports.onDailyWritten = onDocumentWritten('members/{uid}/daily/{day}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) return;
  const newRank = TIER_RANK[after.tier] ?? 0;
  const oldRank = TIER_RANK[before?.tier] ?? 0;
  if (newRank < TIER_RANK.outreach || newRank <= oldRank) return;

  const reason =
    after.crisisReason ||
    (after.drivers || [])
      .slice(0, 3)
      .map((d) => d.text)
      .join('; ') ||
    after.tierLabel;
  await openAlert(event.params.uid, after.tier, reason, event.document);
});

exports.onSosCreated = onDocumentCreated('members/{uid}/sos/{id}', async (event) => {
  await openAlert(event.params.uid, 'sos', 'Pressed "I\'m in danger"', event.document);
});

exports.onRequestCreated = onDocumentCreated('members/{uid}/requests/{id}', async (event) => {
  const data = event.data?.data() || {};
  const type = data.reason === 'crisis-support' ? 'crisis' : 'callback';
  await openAlert(event.params.uid, type, 'Asked their counsellor to call them', event.document);
});

exports.onReportCreated = onDocumentCreated('members/{uid}/reports/{id}', async (event) => {
  await openAlert(event.params.uid, 'intimidation', 'Reported intimidation or being followed', event.document);
});

// ── Escalation ladder ─────────────────────────────────────────────
exports.escalateAlerts = onSchedule('every 10 minutes', async () => {
  const due = await db
    .collection('alerts')
    .where('status', '==', 'open')
    .where('escalateAt', '<=', Timestamp.now())
    .limit(100)
    .get();

  for (const doc of due.docs) {
    const a = doc.data();
    const nextLevel = Math.min((a.level || 0) + 1, LEVEL_ROLES.length - 1);
    const sla = SLA_MINUTES[a.type] ?? 1440;
    const memberSnap = await db.doc(`members/${a.memberId}`).get();
    await doc.ref.update({
      level: nextLevel,
      escalatedAt: FieldValue.serverTimestamp(),
      // At the top level, keep reminding on the same cadence.
      escalateAt: Timestamp.fromMillis(Date.now() + sla * 60 * 1000),
    });
    await db.collection('auditLogs').add({
      actor: 'system',
      action: 'alert.escalated',
      target: doc.ref.path,
      level: nextLevel,
      at: FieldValue.serverTimestamp(),
    });
    await notify(memberSnap.data() || {}, nextLevel, a.type);
  }
  logger.info(`Escalated ${due.size} alerts`);
});
