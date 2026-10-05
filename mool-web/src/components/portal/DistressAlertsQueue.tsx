import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  AlertTriangle, 
  ShieldAlert, 
  CheckCircle2, 
  Clock, 
  Eye, 
  ArrowUpRight, 
  MapPin, 
  ExternalLink,
  Radio,
  BellRing,
  TrendingUp,
  Zap,
  Timer,
  Scale
} from 'lucide-react';
import { collection, onSnapshot, query } from 'firebase/firestore';
import { db } from '../../lib/firebase/firestore';
import { GroundedCard } from '../common/GroundedCard';
import { DistressEvent, AlertStatus } from '../../types';
import { useAuth } from '../../context/AuthContext';
import { maskPseudonym, maskIdentifier, isMaskedRole } from '../../lib/maskData';

const INITIAL_ALERTS: DistressEvent[] = [
  {
    id: 'evt-101',
    beneficiaryId: 'survivor-904',
    beneficiaryPseudonym: 'Priya',
    timestamp: '2026-09-11T14:32:00Z',
    severity: 'critical',
    source: 'prediction',
    status: 'open',
    riskFactors: [
      'Temporal divergence from 14-day grounding baseline (-42%)',
      'Distress keywords detected in voice note ("scared", "cannot sleep")',
      'Zero check-in response over last 72 hours',
    ],
    explanation: 'AI prediction model flagged acute drop in emotional sentiment combined with high voice tremor acoustic variance.',
    assignedCaseworker: 'Officer Rajesh Singh',
    region: 'District B (Valley)',
    forecastProbability: 0.88,
    shapDrivers: [
      'Bail hearing in 3 days (+0.28)',
      'IVRS threat keyword detected (+0.22)',
      'Zero check-in 72h (+0.18)',
      'Voice tremor spike (+0.12)',
    ],
    slaDeadline: '2026-09-11T18:32:00Z',
    slaEscalationLevel: 'Escalated to Nodal Officer',
    recommendedIntervention: 'Initiate witness protection application (Sec 15A; WPS 2018)',
    statutoryMilestone: 'ACCUSED GRANTED BAIL — Bail Hearing Sep 14, 2026',
  },
  {
    id: 'evt-102',
    beneficiaryId: 'survivor-882',
    beneficiaryPseudonym: 'Aarav',
    timestamp: '2026-09-11T09:15:00Z',
    severity: 'high',
    source: 'selfreport',
    status: 'acknowledged',
    riskFactors: ['Self-reported mood drop (2/5)', 'Intrusive memory tag flagged'],
    explanation: 'Survivor self-reported high distress level during morning check-in.',
    assignedCaseworker: 'Officer Rajesh Singh',
    region: 'District A (East)',
    forecastProbability: 0.74,
    shapDrivers: [
      'Mood drop sustained 5 days (+0.24)',
      'Compensation overdue 14 days (+0.19)',
      'Sleep disruption reported (+0.14)',
    ],
    slaDeadline: '2026-09-12T09:15:00Z',
    slaEscalationLevel: 'Counsellor Acknowledged',
    recommendedIntervention: 'Escalate pending relief instalment to District Social Welfare Officer',
    statutoryMilestone: 'Stage 2 Compensation (50%) Overdue — Chargesheet filed Jul 28',
  },
  {
    id: 'evt-103',
    beneficiaryId: 'survivor-940',
    beneficiaryPseudonym: 'Kabir',
    timestamp: '2026-09-10T18:20:00Z',
    severity: 'moderate',
    source: 'prediction',
    status: 'closed',
    riskFactors: ['Disrupted check-in schedule', 'Mild anxiety tags'],
    explanation: 'ML model flagged schedule drift; resolved post phone call check-in by caseworker.',
    assignedCaseworker: 'Ananya Sharma (NGO)',
    region: 'District D (Border)',
    forecastProbability: 0.62,
    shapDrivers: [
      'Check-in schedule drift (+0.16)',
      'Mild anxiety in voice (+0.11)',
      'Trial adjournment (+0.09)',
    ],
    slaDeadline: '2026-09-13T18:20:00Z',
    slaEscalationLevel: 'Resolved',
    recommendedIntervention: 'Follow-up phone call within 48 hours',
    statutoryMilestone: 'Special Court Trial — PW-1 Examination Sep 28',
  },
];

/** Returns a color class for the forecast risk badge */
function forecastColor(prob: number): string {
  if (prob >= 0.8) return 'bg-mool-signal text-white';
  if (prob >= 0.65) return 'bg-mool-sandrose text-white';
  return 'bg-mool-moss/80 text-white';
}

/** Returns the urgency label for the SLA notice */
function slaUrgencyLabel(deadline: string): { label: string; isOverdue: boolean } {
  const now = new Date();
  const dl = new Date(deadline);
  const diffMs = dl.getTime() - now.getTime();
  const diffH = diffMs / (1000 * 60 * 60);

  if (diffH < 0) return { label: `Overdue by ${Math.abs(Math.round(diffH))}h`, isOverdue: true };
  if (diffH < 4) return { label: `${Math.round(diffH)}h remaining`, isOverdue: false };
  if (diffH < 24) return { label: `${Math.round(diffH)}h remaining`, isOverdue: false };
  return { label: `${Math.round(diffH / 24)}d remaining`, isOverdue: false };
}

export const DistressAlertsQueue: React.FC = () => {
  const { role } = useAuth();
  const [alerts, setAlerts] = useState<DistressEvent[]>(INITIAL_ALERTS);
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const navigate = useNavigate();

  // Real-time Firestore subscription to members to catch live SOS alarms from mobile apps
  useEffect(() => {
    try {
      const q = query(collection(db, 'members'));
      const unsubscribe = onSnapshot(q, (snapshot) => {
        const liveSosAlerts: DistressEvent[] = [];

        snapshot.forEach((docSnap) => {
          const d = docSnap.data();
          if (d.sosActive || d.activeSos) {
            const lat = d.lastSosLocation?.lat;
            const lng = d.lastSosLocation?.lng;
            liveSosAlerts.push({
              id: `sos-${docSnap.id}`,
              beneficiaryId: docSnap.id,
              beneficiaryPseudonym: d.displayName || 'Ward',
              timestamp: d.lastSosAt || d.updatedAt?.toDate?.()?.toISOString?.() || new Date().toISOString(),
              severity: 'critical',
              source: 'selfreport',
              status: 'open',
              riskFactors: [
                `CRITICAL EMERGENCY SOS: ${d.lastSosReason || 'Emergency SOS or distress button triggered from mobile app'}`,
                lat && lng ? `Live GPS Fix: ${lat.toFixed(5)}, ${lng.toFixed(5)}` : 'GPS fix pending on phone',
                d.isOnline ? 'Active phone telemetry (10s heartbeat streaming)' : 'Phone idle / offline',
              ],
              explanation: `Emergency distress event initiated on mobile app. Live location: ${
                lat && lng ? `${lat.toFixed(5)}, ${lng.toFixed(5)}` : 'Indoor/Restricted'
              }. Designated Guardian: ${d.guardianName || 'General Emergency Roster'}.`,
              assignedCaseworker: d.guardianName ? `Guardian: ${d.guardianName}` : 'Unassigned Emergency Responder',
              region: 'Live Distress Beacon',
            });
          }
        });

        // Prepend live SOS alerts at top of queue
        setAlerts((prev) => {
          const nonSos = prev.filter((a) => !a.id.startsWith('sos-'));
          return [...liveSosAlerts, ...nonSos];
        });
      }, (err) => {
        console.warn('DistressAlertsQueue Firestore subscription warning:', err);
      });

      return () => unsubscribe();
    } catch (e) {
      console.warn('Error setting up Firestore listener in DistressAlertsQueue:', e);
    }
  }, []);

  const handleUpdateStatus = (id: string, newStatus: AlertStatus) => {
    setAlerts(prev =>
      prev.map(a => (a.id === id ? { ...a, status: newStatus } : a))
    );
  };

  const handleAcknowledgeSla = (id: string) => {
    setAlerts(prev =>
      prev.map(a =>
        a.id === id
          ? { ...a, status: 'acknowledged' as AlertStatus, slaEscalationLevel: 'SLA Acknowledged' }
          : a
      )
    );
  };

  const filtered = alerts.filter(a =>
    filterStatus === 'all' ? true : a.status === filterStatus
  );

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Top Banner */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-mool-dusk text-white p-6 rounded-organic-lg shadow-dusk-elevated">
        <div>
          <div className="inline-flex items-center space-x-2 px-2.5 py-0.5 bg-mool-signal text-white rounded-full text-xs font-semibold">
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>AI Distress Prediction & Triage Queue</span>
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl font-bold tracking-tight text-mool-linen mt-1">
            Surfaced Distress Events & Emergency SOS
          </h1>
          <p className="text-xs text-mool-linen/80">
            Real-time algorithmic predictions and live SOS distress alerts streamed from connected ward mobile devices.
          </p>
        </div>

        {/* Filter Pills */}
        <div className="flex space-x-1.5 bg-mool-dusk-dark p-1 rounded-organic border border-mool-dusk-light">
          {['all', 'open', 'acknowledged', 'closed'].map((st) => (
            <button
              key={st}
              onClick={() => setFilterStatus(st)}
              className={`px-3 py-1 text-xs font-semibold rounded-md capitalize transition-colors ${
                filterStatus === st
                  ? 'bg-mool-moss text-white'
                  : 'text-mool-linen/70 hover:text-white'
              }`}
            >
              {st}
            </button>
          ))}
        </div>
      </div>

      {/* Alerts List */}
      <div className="space-y-4">
        {filtered.map((alert) => {
          const isCritical = alert.severity === 'critical';
          const isHigh = alert.severity === 'high';
          const isLiveSos = alert.id.startsWith('sos-');
          const hasForecast = alert.forecastProbability != null;
          const hasSla = alert.slaDeadline != null;
          const slaInfo = hasSla ? slaUrgencyLabel(alert.slaDeadline!) : null;

          return (
            <GroundedCard
              key={alert.id}
              variant="primary"
              elevation="ground"
              className={`border-l-4 ${
                isLiveSos
                  ? 'border-l-red-600 bg-red-50/20 shadow-md ring-1 ring-red-500/20'
                  : isCritical
                  ? 'border-l-mool-signal bg-mool-signal/5'
                  : isHigh
                  ? 'border-l-mool-sandrose'
                  : 'border-l-mool-moss'
              } space-y-4`}
            >
              {/* Header: Name, severity, status */}
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-mool-mist/50 pb-3">
                <div className="flex items-center space-x-3">
                  <div className={`p-2 rounded-full ${
                    isLiveSos
                      ? 'bg-red-600 text-white animate-bounce'
                      : isCritical 
                      ? 'bg-mool-signal text-white' 
                      : 'bg-mool-sandrose text-white'
                  }`}>
                    <ShieldAlert className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="flex items-center space-x-2">
                      <span className="font-serif text-lg font-bold text-mool-ink">
                        {maskPseudonym(alert.beneficiaryPseudonym, alert.beneficiaryId, role)}
                      </span>
                      <span className="text-xs font-mono text-mool-ink-faint">({maskIdentifier(alert.beneficiaryId, role)})</span>
                      <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase ${
                        isLiveSos
                          ? 'bg-red-600 text-white animate-pulse'
                          : isCritical 
                          ? 'bg-mool-signal text-white' 
                          : 'bg-mool-sandrose text-white'
                      }`}>
                        {isLiveSos ? 'LIVE SOS ALARM' : `${alert.severity} SEVERITY`}
                      </span>
                    </div>
                    <p className="text-xs text-mool-ink-muted flex items-center space-x-2 mt-0.5">
                      <Clock className="w-3.5 h-3.5" />
                      <span>Flagged {new Date(alert.timestamp).toLocaleString()} • {alert.region}</span>
                    </p>
                  </div>
                </div>

                {/* Status Badge */}
                <div className="flex items-center space-x-2">
                  <span className={`px-3 py-1 rounded-full text-xs font-semibold capitalize ${
                    alert.status === 'open'
                      ? 'bg-mool-signal/15 text-mool-signal'
                      : alert.status === 'acknowledged'
                      ? 'bg-mool-sandrose/20 text-mool-sandrose'
                      : 'bg-mool-moss/15 text-mool-moss'
                  }`}>
                    Status: {alert.status}
                  </span>
                </div>
              </div>

              {/* ── 14-Day Forecast Risk + SLA Strip ───────────────── */}
              {(hasForecast || hasSla || alert.statutoryMilestone) && (
                <div className="flex flex-wrap gap-3 items-stretch">
                  {/* Forecast Risk Badge */}
                  {hasForecast && (
                    <div className={`flex items-center space-x-2 px-3 py-2 rounded-organic ${forecastColor(alert.forecastProbability!)}`}>
                      <TrendingUp className="w-4 h-4" />
                      <div>
                        <div className="text-sm font-bold">
                          {Math.round(alert.forecastProbability! * 100)}% Risk
                        </div>
                        <div className="text-[10px] opacity-90">14-Day Escalation Forecast (LightGBM)</div>
                      </div>
                    </div>
                  )}

                  {/* SLA Deadline Notice */}
                  {hasSla && slaInfo && (
                    <div className={`flex items-center space-x-2 px-3 py-2 rounded-organic border ${
                      slaInfo.isOverdue
                        ? 'bg-mool-signal/10 border-mool-signal/30 text-mool-signal'
                        : 'bg-mool-dusk/8 border-mool-dusk/20 text-mool-dusk'
                    }`}>
                      <Timer className="w-4 h-4" />
                      <div>
                        <div className="text-xs font-bold">
                          {slaInfo.isOverdue ? `⚠ SLA ${slaInfo.label}` : `Ack Deadline: ${slaInfo.label}`}
                        </div>
                        <div className="text-[10px] opacity-80">
                          {alert.slaEscalationLevel || 'Pending Acknowledgement'}
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Statutory Milestone Badge */}
                  {alert.statutoryMilestone && (
                    <div className="flex items-center space-x-2 px-3 py-2 rounded-organic bg-mool-sandrose/10 border border-mool-sandrose/25 text-mool-sandrose">
                      <Scale className="w-4 h-4 shrink-0" />
                      <div className="text-[11px] font-semibold leading-tight">
                        {alert.statutoryMilestone}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* ── TreeSHAP Contributing Drivers ──────────────────── */}
              {alert.shapDrivers && alert.shapDrivers.length > 0 && (
                <div className="space-y-1.5">
                  <h4 className="text-[11px] font-bold text-mool-dusk uppercase tracking-wide flex items-center space-x-1.5">
                    <Zap className="w-3 h-3" />
                    <span>Top Escalation Drivers (TreeSHAP)</span>
                  </h4>
                  <div className="flex flex-wrap gap-1.5">
                    {alert.shapDrivers.map((driver, idx) => (
                      <span
                        key={idx}
                        className="text-[11px] px-2.5 py-1 rounded-organic bg-mool-dusk/6 border border-mool-dusk/15 text-mool-ink font-medium"
                      >
                        {driver}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Explainable AI Risk Factors & Live Telemetry Details */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold text-mool-ink uppercase tracking-wide">
                  {isLiveSos ? 'Emergency SOS Dispatch Details' : 'Explainable AI Indicators & Risk Factors'}
                </h4>
                <p className="text-xs text-mool-ink-muted leading-relaxed">{alert.explanation}</p>
                
                <div className="flex flex-wrap gap-2 pt-1">
                  {alert.riskFactors.map((factor, idx) => (
                    <span
                      key={idx}
                      className={`text-[11px] px-2.5 py-1 rounded-organic shadow-sm border ${
                        factor.includes('CRITICAL EMERGENCY SOS')
                          ? 'bg-red-50 text-red-900 border-red-200 font-semibold'
                          : 'bg-white border-mool-mist text-mool-ink'
                      }`}
                    >
                      • {factor}
                    </span>
                  ))}
                </div>
              </div>

              {/* ── Recommended Intervention ───────────────────────── */}
              {alert.recommendedIntervention && (
                <div className="bg-mool-moss/8 border border-mool-moss/20 rounded-organic p-3 flex items-start space-x-3">
                  <div className="w-7 h-7 rounded-full bg-mool-moss text-white flex items-center justify-center shrink-0 mt-0.5">
                    <CheckCircle2 className="w-4 h-4" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-[11px] font-bold text-mool-moss uppercase tracking-wide">Recommended Intervention</div>
                    <p className="text-xs text-mool-ink mt-0.5">{alert.recommendedIntervention}</p>
                  </div>
                </div>
              )}

              {/* Triage Actions Bar */}
              <div className="pt-3 border-t border-mool-mist flex flex-wrap items-center justify-between gap-3">
                <div className="text-xs text-mool-ink-muted">
                  Assigned Contact: <strong className="text-mool-ink">{alert.assignedCaseworker}</strong>
                </div>

                <div className="flex items-center space-x-2">
                  {/* Acknowledge SLA button - only for open alerts with SLA */}
                  {alert.status === 'open' && hasSla && alert.slaEscalationLevel !== 'SLA Acknowledged' && (
                    <button
                      onClick={() => handleAcknowledgeSla(alert.id)}
                      className="px-3 py-1.5 bg-mool-sandrose text-white rounded-organic text-xs font-semibold hover:bg-mool-sandrose/90 transition-colors flex items-center space-x-1"
                    >
                      <Timer className="w-3.5 h-3.5" />
                      <span>Acknowledge SLA</span>
                    </button>
                  )}

                  {alert.status === 'open' && (
                    <button
                      onClick={() => handleUpdateStatus(alert.id, 'acknowledged')}
                      className="px-3 py-1.5 bg-mool-dusk text-white rounded-organic text-xs font-semibold hover:bg-mool-dusk-dark transition-colors"
                    >
                      Acknowledge Triage
                    </button>
                  )}

                  {alert.status !== 'closed' && (
                    <button
                      onClick={() => handleUpdateStatus(alert.id, 'closed')}
                      className="px-3 py-1.5 bg-mool-moss text-white rounded-organic text-xs font-semibold hover:bg-mool-moss-dark transition-colors flex items-center space-x-1"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      <span>Resolve & Close</span>
                    </button>
                  )}

                  <button
                    onClick={() => navigate(`/portal/case/${alert.beneficiaryId}`)}
                    className="px-3 py-1.5 bg-mool-mist/50 border border-mool-mist text-mool-ink rounded-organic text-xs font-semibold hover:bg-mool-mist transition-colors flex items-center space-x-1"
                  >
                    <Eye className="w-3.5 h-3.5" />
                    <span>Open Case Detail</span>
                    <ArrowUpRight className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </GroundedCard>
          );
        })}
      </div>
    </div>
  );
};
