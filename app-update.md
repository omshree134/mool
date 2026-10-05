# Mool: Implementation Plan for the Missing Core Features

The plan rests on one decision: **all heavy AI runs on a free server, not on the phone.** The app only collects check-ins and displays results, so its size barely grows. Everything below uses free tiers. The one exception is real phone calls in production, which no provider offers for free; for building and demoing, trial credit is enough.

## The free stack

| Need | Free option | Limits to know |
|---|---|---|
| Backend API (Python) | **Hugging Face Spaces** (Docker, CPU Basic) | 2 vCPU and 16 GB RAM. Sleeps after 48 h idle, which a keep-warm ping fixes. Disk is temporary, so keep all state in Firestore |
| Database and auth | **Firebase Spark plan** (what you already have) | About 50k reads and 20k writes per day, 1 GB storage. No Cloud Functions on Spark, which is why the backend lives on HF |
| Scheduled jobs | **cron-job.org** | Free, runs every minute if needed. It also keeps the HF Space awake |
| IVRS and SMS | **Twilio trial credit** | Calls and texts only to phone numbers you've verified. Calls start with a short "trial account" message. Fine for a demo |
| WhatsApp chatbot | **Twilio WhatsApp Sandbox** | Free two-way testing. Each user sends a join code once |
| Speech-to-text | **Groq Whisper** (you already have a Groq key), later **Bhashini** | Groq's free tier is rate-limited. Bhashini is free after registration and much better for Indic languages beyond Hindi |
| Voice stress features | **openSMILE** (`pip install opensmile`) | Runs on CPU, no GPU needed |
| Emotion and crisis NLP | Groq LLM returning structured JSON, plus a deterministic keyword list | No model training required |
| Forecasting | **LightGBM + SHAP** | The trained model file is under 1 MB |
| Push notifications | **Firebase Cloud Messaging** | Free |
| Email alerts | Gmail SMTP with an app password, or Brevo | A few hundred emails per day |
| Maps | Simplified district boundary file, loaded only on state and national pages | Must use Survey of India-compliant boundaries (see Phase 6) |

Before you start, check your Firestore location. It is fixed at creation and can't be changed. If it isn't `asia-south1` (Mumbai), create a new Firebase project in that region now, before you have real data.

## Target architecture

```
 Flutter app ─┐
 Web portal  ─┤──HTTPS + Firebase ID token──┐
 Twilio IVRS ─┤──signed webhooks────────────┤
 WhatsApp/SMS ┘                             ▼
                              ┌──────── mool-api (FastAPI on HF Spaces) ────────┐
                              │ /ai      Groq proxy (key never leaves server)   │
                              │ /ingest  all channels → "observations"          │
                              │ /ivrs    call flow + recording pipeline         │
                              │ /cron    scheduler, SLA escalation, aggregates  │
                              │ engine/  scoring · forecast · alerts · recs     │
                              └───────────────┬─────────────────────────────────┘
                                              ▼
                                  Firestore (asia-south1)
                                              ▼
                     District ▸ State ▸ National dashboards (mool-web)
```

Suggested backend folder layout:

```
mool-api/
├── app/
│   ├── main.py
│   ├── deps.py                 # auth, firebase-admin init
│   ├── routers/  ai.py  ingest.py  ivrs.py  whatsapp.py  cron.py  cases.py
│   ├── engine/   scoring.py  trends.py  forecast.py  escalation.py  recommend.py
│   ├── nlp/      emotion.py  crisis_lexicon.py  pseudonymise.py
│   └── voice/    asr.py  prosody.py
├── config/  escalation.yaml  interventions.yaml  ivrs_prompts.yaml
├── models/  forecast.lgb
├── scripts/ synth_cohort.py  train_forecast.py  seed_demo.py
├── Dockerfile
└── requirements.txt
```

## The phases

Each phase leaves you with a working, demoable system, so you are never stuck with half-broken code. In total this is roughly 3 weeks for a small team.

### Phase 0: Backend skeleton and moving the AI key (1–2 days)

This comes first because every later phase depends on it, and it also fixes the exposed API key.

1. Create the HF Space: choose the Docker type and set it to **private**. Add these as Space secrets: `GROQ_API_KEY`, `FIREBASE_SA_JSON` (service account key), `TWILIO_SID`, `TWILIO_TOKEN`, and `CRON_SECRET`.
2. Deploy a minimal FastAPI app. Every request from the app or portal must carry a Firebase ID token, which the backend checks:

```python
# deps.py
from fastapi import Header, HTTPException
from firebase_admin import auth

async def current_user(authorization: str = Header(...)):
    try:
        return auth.verify_id_token(authorization.removeprefix("Bearer "))
    except Exception:
        raise HTTPException(401, "invalid token")
```

3. Move the Groq calls into `/ai/chat`. In Flutter, replace the direct Groq call with a call to your backend:

```dart
final token = await FirebaseAuth.instance.currentUser!.getIdToken();
final res = await http.post(Uri.parse('$apiBase/ai/chat'),
  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
  body: jsonEncode({'messages': messages, 'lang': lang}));
```

Do the same in `aiService.ts`, then **delete the Groq key from both apps and rotate it**, since the old key may already have been extracted.

4. On cron-job.org, create a job that calls `POST /cron/tick` every 10 minutes with header `X-Cron-Secret`. This single job keeps the Space awake, which matters for Twilio (see Phase 3), and later runs escalations.

**A note on private Spaces:** a private Space requires a Hugging Face token on every request. You have two options. You can make the Space public, since your secrets stay hidden and only the code is visible. Or you can keep it private and put a Cloudflare Worker (free) in front of it that adds the token. For a hackathon, a public Space with strict auth on every endpoint is fine.

### Phase 1: Unified data model and server-side scoring (2–3 days)

This is the foundation that lets IVRS, WhatsApp, and counsellor notes feed the same distress score.

**Firestore collections:**

```
beneficiaries/{bid}        pseudonym, stateCode, districtCode, caseType,
                           language, channels[], consent{}, assignedCounsellor
contact_private/{bid}      phone number (backend-only, clients can never read)
observations/{oid}         bid, channel (app|ivrs|whatsapp|sms|counsellor),
                           kind (checkin|screener|voice|text|event), payload,
                           features{}, createdAt
case_events/{bid}/{eid}    type (hearing|bail|chargesheet|compensation_due|
                           compensation_paid|intimidation), date, source
scores/{bid}/daily/{date}  score, tier, components{}, drivers[], forecast{}
alerts/{aid}               bid, tier, level, notified[], reasons[], status,
                           ackDeadline, escalationLevel, districtCode
recommendations/{rid}      bid, interventionId, reason, owner, status
aggregates/{scope}         precomputed district/state/national stats
```

**Scoring rules:**

- Port your Dart distress engine to `engine/scoring.py` and make the server version the one source of truth. The app keeps its local copy only to show a score while offline.
- Add a voice component and **re-weight across whatever data is actually available**, so a missing component is never treated as zero:

```python
BASE_W = {"self_report": .50, "behaviour": .20, "language": .20, "voice": .10}

def combine(components: dict) -> float:
    avail = {k: v for k, v in components.items() if v is not None}
    total_w = sum(BASE_W[k] for k in avail)
    return sum(BASE_W[k] * v for k, v in avail.items()) / total_w
```

- **Treat silence as a signal of its own.** If there has been no contact on any channel for 5 days, or 3 days within a week of a hearing, create an `outreach_due` task that triggers an IVRS call. Don't just add a few points to the score.
- The app writes observations through `/ingest` and keeps a local queue for offline use, sending the batch once it's back online.

**Case events:** there is no public API for NHAA or the Integrated Portal, so build a `CaseSource` adapter with two implementations:
1. A CSV or JSON import screen in the portal.
2. A mock "PoA Portal" endpoint (`/mock-poa/cases`) that your adapter reads from.

This lets you demonstrate integration truthfully. Real integration would follow a data-sharing agreement with the Ministry of Social Justice and Empowerment. Make sure the events include **bail and release of the accused**, which is one of the highest-risk moments for survivors.

### Phase 2: Escalation matrix, alerts, and intervention recommendations (2–3 days)

Both of these are rules written in YAML config files, which makes them fast to build, easy to explain to evaluators, and adjustable by officials without code changes.

**`config/escalation.yaml`**

```yaml
tiers:
  watch:    {notify: [counsellor],                              ack_hours: 72}
  outreach: {notify: [counsellor, nodal_officer],               ack_hours: 24}
  urgent:   {notify: [counsellor, nodal_officer, dmhp, sp_office], ack_hours: 4}
  crisis:   {notify: [crisis_desk], ack_minutes: 15, handoff: tele_manas_14416}
escalate_if_unacknowledged:
  counsellor: nodal_officer
  nodal_officer: dm_office
  dm_office: state_nodal_officer
```

**How it runs:**

- When a score's tier rises, `escalation.py` creates an alert with the reasons attached and sends it to each role's users in that district. Notifications go out by FCM push to the portal and by email.
- On every `/cron/tick`, the system finds alerts past their `ackDeadline`, moves each up one level, and logs the step to the audit trail.
- A **crisis** alert never waits for the cron job. It is sent immediately at the moment of detection.

**`config/interventions.yaml`**

```yaml
- id: witness_protection
  when: {all: [intimidation_within_hours: 48, hearing_within_days: 7]}
  action: "Initiate witness protection application (Sec 15A; WPS 2018)"
  reason: "Intimidation reported {intimidation_ago}; hearing in {hearing_in} days"
  owner: nodal_officer

- id: compensation_followup
  when: {any: [compensation_overdue_days: 7]}
  action: "Escalate pending relief instalment to District Social Welfare Officer"
  owner: counsellor

- id: psychiatric_referral
  when: {any: [phq9_item9_positive, phq9_at_least: 20]}
  action: "Referral via DMHP / Tele-MANAS"
  owner: counsellor
```

**Recommendations in the portal:** each recommendation appears as a card showing its reason, with **Accept, Reject, or Done** buttons. Store the caseworker's decision. That record becomes labelled data for improving the system later, and it shows evaluators a working "human in the loop".

### Phase 3: IVRS, WhatsApp, and SMS, plus voice analysis (3–4 days)

This is the phase evaluators will find most impressive, because it reaches people who don't have smartphones.

**Pre-recording prompts:** generate each IVRS prompt once per language, using Bhashini TTS or recording a volunteer's voice. Host the MP3s as static files in the Space and play them with Twilio's `<Play>`. This avoids any per-call text-to-speech cost, and a real human voice sounds warmer to callers.

**Call flow:**

1. **The call is placed.** The cron job finds beneficiaries due for a check-in: weekly by default, every 2 days near a hearing, and immediately when they fall silent. It then starts the call with `client.calls.create(to=phone, url=f"{API}/ivrs/start?bid=...")`.
2. **Keypad questions.** The caller answers 2–3 questions by pressing keys: sleep quality from 1 to 3, mood from 1 to 3, and "Has anyone threatened or pressured you since we last spoke? Press 1 for yes."
3. **An open voice question** is recorded with `<Record maxLength="45">`.
4. **Closing.** The caller hears "Press 9 at any time to speak to a counsellor", followed by the helpline numbers.

**Starting the call:**

```python
@router.post("/ivrs/start")
async def ivrs_start(bid: str, lang: str = "hi"):
    vr = VoiceResponse()
    g = Gather(input="dtmf", num_digits=1, timeout=8,
               action=f"/ivrs/answer?bid={bid}&lang={lang}&q=sleep")
    g.play(f"{AUDIO}/{lang}/greet_sleep.mp3")
    vr.append(g)
    return Response(str(vr), media_type="application/xml")
```

**Rules for the call pipeline:**

- **Check Twilio's signature** on every webhook using `twilio.request_validator.RequestValidator`.
- A "yes" to the threat question creates an `intimidation` case event **immediately**, which instantly raises the score through its contextual modifier.
- **Twilio expects a reply within about 15 seconds.** The recording webhook must therefore respond right away and do the processing in a `BackgroundTasks` job. This is also why the keep-warm ping matters.

**Processing each recording in the background:**

1. Download the WAV file using your Twilio credentials, then **delete it from Twilio** so survivor audio isn't left on a third-party server.
2. Extract voice features:

```python
smile = opensmile.Smile(feature_set=opensmile.FeatureSet.eGeMAPSv02,
                        feature_level=opensmile.FeatureLevel.Functionals)
f = smile.process_file(wav).iloc[0]
feats = {"f0_var":  f["F0semitoneFrom27.5Hz_sma3nz_stddevNorm"],
         "jitter":  f["jitterLocal_sma3nz_amean"],
         "shimmer": f["shimmerLocaldB_sma3nz_amean"],
         "rate":    f["VoicedSegmentsPerSec"],
         "pause":   f["MeanUnvoicedSegmentLength"]}
```

3. Convert each feature to a **z-score against that person's own baseline**, which needs at least 3 calls before it's used. Average the z-scores into a voice-stress value between 0 and 100. Phone audio is low quality (8 kHz), so jitter and shimmer are noisy. That's another reason the voice weight is capped at 10% and can never trigger a tier on its own.
4. Transcribe the recording with Whisper, then pass the transcript to the Phase 4 NLP pipeline.
5. Write the results as an `observation` and re-score.

**WhatsApp (sandbox):** a `/whatsapp/inbound` webhook runs the same check-in as a short menu ("Reply 1, 2 or 3"), and free-text replies go to the NLP pipeline. **SMS** is one-way: hearing reminders and compensation updates. In production, SMS in India requires templates registered on the TRAI DLT platform, so mention that in your pitch.

**Missed-call callback:** in production this would use a missed-call number from Exotel. For the demo, a "Request a call" button in the app or a WhatsApp keyword ("CALL") starts the same outbound call.

### Phase 4: Emotion AI, crisis detection, and multilingual support (2–3 days)

The text pipeline has three steps, in this order:

1. **Deterministic crisis check first.** `crisis_lexicon.py` holds a clinician-reviewed list of phrases for self-harm and imminent danger in each supported language, including romanised Hinglish. A match triggers the crisis path immediately. This step **never depends on the LLM**, so an API outage or rate limit can't hide a crisis.
2. **Pseudonymise.** Replace names, villages, phone numbers, and FIR numbers with placeholders such as `[NAME]` and `[PLACE]`, using patterns plus a names list, before any text leaves your server. This matters for rape survivors under BNS Section 72.
3. **LLM classification.** Use Groq's JSON mode with a small, fast model (it has higher free limits than a large one) and a fixed output format:

```json
{"emotions": {"fear": 0.0, "sadness": 0.0, "anger": 0.0,
              "hopelessness": 0.0, "shame": 0.0, "calm": 0.0},
 "threat_mentioned": false, "crisis_signal": false,
 "evidence": ["short span that justified the top emotion"]}
```

The `evidence` field feeds straight into your Explainable AI view, for example: "Hopelessness detected in: '…'". If `crisis_signal` is true but the keyword list didn't match, don't escalate automatically. Create an **Urgent alert for a human to review**. That keeps false positives from the LLM from firing crisis responses.

**Multilingual support:**

- **App interface:** use Flutter's `.arb` translation files, which are a few kilobytes per language. Start with Hindi and English, then add Marathi, Telugu, Tamil, Kannada, Odia, Gujarati, and Bengali.
- **Speech:** put speech recognition behind an `asr.py` interface. Use Groq Whisper for Hindi and English now, and plug in Bhashini for the other languages, where Whisper is weaker. Switching then changes one file.
- **Chat:** the LLM replies in the user's chosen language. For languages it handles poorly, translate its reply using Bhashini's translation API.

### Phase 5: Trend analysis and prediction (2–3 days)

This is what makes the "predict before a crisis" claim true.

**Trend layer:** plain math, no machine learning.

```python
def ewma(xs, a=0.3):
    out, s = [], xs[0]
    for x in xs:
        s = a * x + (1 - a) * s
        out.append(s)
    return out

def cusum_up(xs, mu, sd, k=0.5, h=4.0):   # sustained upward drift
    s = 0.0
    for x in xs:
        s = max(0.0, s + (x - mu) / max(sd, 1e-6) - k)
        if s > h:
            return True
    return False
```

Store the smoothed score and the 7- and 14-day slopes each day. A drift detected by CUSUM raises a **"Rising trend"** Watch alert even while the score still looks moderate.

**Forecast model:**

1. **Generate synthetic data.** Write `synth_cohort.py` to simulate about 1,000 beneficiaries over 180 days. Each one gets a hidden distress level that responds to events: hearings cause spikes, intimidation causes jumps, overdue compensation causes slow drift, and grant of bail to the accused causes a sharp rise. Add noise, and **make missed check-ins more likely when distress is high**, which mirrors real withdrawal behaviour.
2. **Define the label:** whether the person reaches the Urgent tier or above within the next 14 days.
3. **Define the features:**
   - The current score, the smoothed score, the 7- and 14-day slopes, and the variability.
   - Days until the next hearing and until any bail hearing, and days since the last intimidation.
   - Days compensation is overdue, and the number of missed contacts in a row.
   - Case type and the latest voice and emotion signals.
4. **Train** `train_forecast.py` with LightGBM, calibrate the output probabilities, and save `forecast.lgb`, which is under 1 MB.
5. **Serve** it by computing the risk probability on every re-score, plus the top 3 SHAP contributions, for example: "Risk 0.71 in 14 days — main drivers: bail hearing in 5 days (+0.22), rising slope (+0.15), 3 missed calls (+0.12)."
6. **Alert on forecast:** a forecast risk above 0.6 creates an "Anticipated escalation" alert at Outreach level.

Be upfront in your pitch that the model was trained on synthetic data, and present the retraining plan: once real outcomes exist, the caseworkers' accept and reject decisions from Phase 2 plus actual tier changes become the training labels. Evaluators respect that honesty far more than an unexplained accuracy number.

### Phase 6: District, State, and national dashboards (3 days)

**Roles:** use Firebase Auth custom claims, set once from the backend with the Admin SDK at no cost. For example: `{role: "district_officer", state: "UP", district: "UP-LKO"}`.

**Firestore security rules:**

```
match /beneficiaries/{id} {
  allow read: if request.auth.token.role in ['counsellor','district_officer']
              && request.auth.token.district == resource.data.districtCode;
}
match /aggregates/{doc} {
  allow read: if request.auth.token.role in ['state_officer','national_officer','district_officer'];
}
match /contact_private/{id} { allow read, write: if false; }   // backend only
```

**What each level shows:**

- **District:** the triage queue sorted by forecast risk, then tier, then how long ago the alert was raised. Plus overdue acknowledgements, a calendar of hearings in the next 7 days for high-risk cases, and pending recommendations.
- **State:** a map of districts coloured by the share of beneficiaries at Outreach or above, average alert response time per district, and compensation delay hotspots.
- **National:** state-by-state comparisons plus policy indicators, such as how distress relates to trial delay and to compensation delay.

**Keeping it free and fast:**

- On each `/cron/tick`, the backend recomputes the `aggregates` documents. Dashboards then read a handful of documents instead of thousands, which keeps you well inside the free read quota.
- Hide any count below 5 in aggregate views and show "<5" instead. In a small district, even a count can identify a survivor.

**Maps:** use a simplified district boundary file, reduced to a few hundred kilobytes with mapshaper, and **load it only on the state and national pages.** For anything shown to government evaluators, the map must use **Survey of India-compliant boundaries**. Maps showing incorrect Indian borders cause serious problems in an official context, so check your boundary source carefully.

**Demo data:** `seed_demo.py` creates about 40 synthetic beneficiaries across 2 states and 3 districts, with login accounts for each role, so every dashboard level has data to show.

### Phase 7: Keeping the app small (1 day, and ongoing)

What you add to the app across all these phases is small: a few new screens, an API client, a local offline queue, and translation files. No machine learning models ship inside the app. Beyond that, a few steps will likely *shrink* your current size:

- **Soundscapes are probably your biggest assets.** Re-encode them as mono Opus or OGG at about 32–48 kbps, with loops of 30–60 seconds. Better still, download each one the first time it's played and cache it.
- **Fonts:** bundle only Fraunces and Inter. Download the Noto font for an Indian script only when the user selects that language. The `google_fonts` package can fetch and cache fonts at runtime.
- **Release build settings:**

```
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Also turn on `minifyEnabled true` and `shrinkResources true` in the Android release build config. If you share the APK directly rather than through the Play Store, build it with `--split-per-abi`.

- **Audit the size** with `flutter build apk --analyze-size` and remove any package you can replace with a few lines of your own code.

## Suggested schedule

| Week | Work | What you can demo at the end |
|---|---|---|
| 1 | Phase 0, Phase 1, Phase 2 | Secure backend. Every channel feeds one score. Alerts auto-escalate with reasons, and interventions are recommended |
| 2 | Phase 3, Phase 4 | A real phone call that ends in a scored observation. Voice and emotion analysis. Hindi, English, and 2 more languages |
| 3 | Phase 5, Phase 6, Phase 7 | Forecast with explanations, three-level dashboards, and a smaller app |

## Things that will go wrong, and how to avoid them

- **Twilio call timeouts when the Space was asleep.** Keep the cron-job.org ping running, and do all slow work in background tasks.
- **Hitting Groq's rate limits during a live demo.** Cache chat replies for scripted demo steps. Remember that the crisis keyword check doesn't depend on Groq, so safety still works if it fails.
- **Running out of Firestore reads** because dashboards query raw data. Always read from the `aggregates` documents.
- **A trial phone number that isn't verified.** Verify every demo phone number in the Twilio console the day before.
- **The service account key leaking.** Keep it only in the Space's secrets. Never commit it to git, and add it to `.gitignore` from day one.

For your final demo, walk through one continuous story. A witness receives an IVRS call five days before a bail hearing and presses 1 because they were threatened. Their voice and words show fear. The forecast rises, and the Nodal Officer gets an alert with the reasons attached and a recommended witness protection application. When nobody acknowledges it within four hours, the alert escalates to the District Magistrate's office on its own. That single flow shows almost every line of the problem statement working.

If you want, I can start on Phase 0 now: write the FastAPI skeleton, Dockerfile, auth dependency, and the updated Flutter and TypeScript AI clients.