# Mool (मूल) — AI-Powered Grounded Mental Health Platform

**Built by Team Origin**

Mool ("root" in Hindi/Sanskrit) is an AI-powered dynamic mental health monitoring and distress prediction platform designed specifically for survivors of atrocities. Mool provides quiet, private, trauma-informed monitoring that connects individuals with human responders before crises escalate — without feeling surveillant, clinical, or cold.

---

## 1. Dual Front-Door Architecture

Mool provides two distinct, purpose-built interfaces sharing a unified design token system:

1. **Survivor / Beneficiary App (`/app/*`)**
   - **Target**: Survivors of violence, displacement, or persecution.
   - **Platform**: Responsive mobile-first PWA frontend.
   - **Key Features**: QR code zero-friction onboarding, plain-language consent screen, gentle daily check-ins (mood, free text, voice note), private journal, "Talk to Mool" conversational assistant grounded in the AIKosh MHQA dataset, personal sentiment trend view, and instant 1-tap crisis escalation.

2. **Government / Responder Portal (`/portal/*`)**
   - **Target**: Credentialed caseworkers, clinical supervisors, and agency administrators.
   - **Platform**: Responsive desktop-first dashboard.
   - **Key Features**: Role-based credential login, population wellbeing aggregate trends (Recharts), beneficiary QR pairing generator, AI distress prediction queue with triage actions (Acknowledge, Escalate, Dispatch, Close), individual case detail view, and immutable audit logs.

---

## 2. Design System & Palette

Inspired by **roots, soil, and quiet daylight**, Mool shuns generic SaaS and AI tropes (neon accents, sharp dark mode, aggressive card shadows) in favor of a grounding, calming environment.

| Token | Hex | Role |
|---|---|---|
| `--mool-linen` | `#F6F3EC` | Base warm off-white background |
| `--mool-moss` | `#5F7A5E` | Primary brand accent — survivor app controls & growth elements |
| `--mool-dusk` | `#2E4452` | Deep indigo-teal — responder portal primary & authority context |
| `--mool-sandrose` | `#C98B76` | Empathetic secondary accent (human warmth, used sparingly) |
| `--mool-ink` | `#2B2B28` | Soft charcoal text (never harsh pure black) |
| `--mool-mist` | `#E4E0D5` | Card surfaces and organic border dividers |
| `--mool-signal` | `#B3543F` | Muted, desaturated distress indicators (non-triggering) |

**Typography**:
- **Display**: *Fraunces* (humanist variable soft serif) for hero headers & grounding statements.
- **Body & UI**: *Inter* (clean grotesk sans) for forms, nav, copy, and data visualizers.

---

## 3. MHQA Dataset Integration (AIKosh Bharat)

The project references the **Mental Health Question-Answering dataset** (AIKosh, India context) located at `/data/mhqa/mhqa.csv`.
- Grounded responses are surfaced via `src/services/mhqaService.ts`.
- Input is evaluated for acute distress keywords to trigger immediate safety overlays.

---

## 4. Integration Points Seams (`// INTEGRATION POINT:`)

Every backend & ML integration seam is clearly commented in code with `// INTEGRATION POINT:`:

1. `src/lib/firebase/config.ts` — Firebase credentials
2. `src/lib/firebase/auth.ts` — Survivor QR custom token auth & Responder email auth
3. `src/lib/firebase/functions.ts` — Cloud Function stubs (`exchangeQrToken`, `generateQrToken`, `predictDistress`)
4. `src/services/mhqaService.ts` — Grounded MHQA RAG query pipeline
5. `src/routes/PortalRoutes.tsx` — Claims-based role-based access control (RBAC)

---

## 5. Development & Build

```bash
# Install dependencies
npm install

# Start local dev server
npm run dev

# Production build
npm run build
```

See `FIREBASE_SETUP.md` for backend setup instructions.

