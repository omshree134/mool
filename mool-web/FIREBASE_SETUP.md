# Firebase & Cloud Functions Handoff Guide — Mool Platform

This document outlines the setup steps and security configuration for backend engineers connecting Firebase services to the **Mool** frontend.

---

## 1. Environment Setup

Create a `.env.local` file in the project root based on `.env.example`:

```bash
cp .env.example .env.local
```

Fill in the Firebase web app credentials generated from your Firebase Console under:
`Project Settings` -> `General` -> `Your apps` -> `SDK setup and configuration`.

---

## 2. Firestore Database Collections & Schema

Scaffolded collection references are available in `src/lib/firebase/firestore.ts`.

### `beneficiaries`
- `id` (string): Primary beneficiary UUID / pseudonymous identifier
- `pseudonym` (string, optional): Self-chosen or caseworker-assigned pseudonym
- `consentStatus` ("granted" | "paused" | "revoked"): Consent state
- `language` ("en" | "hi" | "mr" | "bn" | "ta"): Preferred language code
- `createdAt` (Timestamp): Date of initial QR pairing
- `linkedCaseworker` (string): Responders ID assigned to this beneficiary

### `qrTokens`
- `token` (string): Unique 64-char cryptographically generated pairing token
- `beneficiaryId` (string): Linked beneficiary record
- `expiresAt` (Timestamp): Token expiry (default: 24h)
- `used` (boolean): Flag indicating single-use consumption

### `checkins`
- `id` (string): Check-in entry UUID
- `beneficiaryId` (string): Linked beneficiary
- `timestamp` (Timestamp): Submission timestamp
- `moodScore` (number 1–5): Grounding / mood scale rating
- `note` (string, optional): Free-text reflection journal entry
- `voiceUrl` (string, optional): Firebase Storage URI for voice audio recording

### `distressEvents`
- `id` (string): Alert UUID
- `beneficiaryId` (string): Target beneficiary
- `timestamp` (Timestamp): Flagged timestamp
- `severity` ("low" | "moderate" | "high" | "critical"): AI/self-report risk level
- `source` ("prediction" | "selfreport"): Origin of alert
- `status` ("open" | "acknowledged" | "escalated" | "closed"): Triage status
- `notes` (array): Caseworker intervention notes

### `responders`
- `id` (string): Responder auth UID
- `name` (string): Official name or badge ID
- `role` ("admin" | "caseworker" | "analyst"): RBAC role
- `assignedRegion` (string): Geographic monitoring zone

### `auditLog`
- `id` (string): Audit entry UUID
- `actorId` (string): User ID accessing sensitive record
- `action` (string): Action description (e.g. "VIEW_CASE_RECORD", "EXPORT_REPORT")
- `targetId` (string): Target beneficiary or case ID
- `timestamp` (Timestamp): Log timestamp

---

## 3. Recommended Firestore Security Rules

Given the sensitive nature of survivors' data, rules **must default-deny** and scope access to authenticated roles only.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Default deny all access
    match /{document=**} {
      allow read, write: if false;
    }
    
    // Beneficiaries can only read & write their own check-ins
    match /checkins/{checkinId} {
      allow create: if request.auth != null && request.auth.uid == request.resource.data.beneficiaryId;
      allow read: if request.auth != null && (
        request.auth.uid == resource.data.beneficiaryId ||
        request.auth.token.role in ['admin', 'caseworker']
      );
    }
    
    // Beneficiary profile records
    match /beneficiaries/{id} {
      allow read: if request.auth != null && (
        request.auth.uid == id ||
        request.auth.token.role in ['admin', 'caseworker', 'analyst']
      );
      allow write: if request.auth != null && request.auth.token.role == 'admin';
    }

    // Distress Events (Responder Portal)
    match /distressEvents/{eventId} {
      allow read, update: if request.auth != null && request.auth.token.role in ['admin', 'caseworker'];
    }

    // Audit Log (Append-only for authorized actors)
    match /auditLog/{logId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null && request.auth.token.role == 'admin';
    }
  }
}
```

---

## 4. Integration Point Seams (`// INTEGRATION POINT:`)

1. **`src/lib/firebase/config.ts`**: Replace placeholder config object with Firebase initializations.
2. **`src/lib/firebase/auth.ts`**: Wire `signInWithCustomToken` for QR-paired survivors and `signInWithEmailAndPassword` for credentialed responders.
3. **`src/lib/firebase/functions.ts`**: Connect callable functions `exchangeQrToken`, `generateQrToken`, and `predictDistress`.
4. **`src/services/mhqaService.ts`**: Wire `getSupportResponse()` to Cloud Function / LLM pipeline over `/data/mhqa/mhqa.csv`.

