import React, { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { 
  ShieldCheck, 
  QrCode, 
  Users, 
  Copy, 
  Check, 
  RefreshCw, 
  Activity, 
  LogOut,
  ArrowRight,
  ArrowLeft,
  Sparkles,
  Phone,
  Building,
  MapPin,
  AlertOctagon,
  ExternalLink,
  Wifi,
  WifiOff,
  Footprints,
  FileText,
  AlertTriangle,
  Heart,
  Smile,
  Moon,
  Clock,
  Radio,
  Plus,
  Trash2
} from 'lucide-react';
import { collection, onSnapshot, query, setDoc, doc, orderBy, limit, serverTimestamp, deleteDoc } from 'firebase/firestore';
import { db } from '../../lib/firebase/firestore';
import { useGuardianAuth } from '../../context/GuardianAuthContext';
import { GuardianAuth } from './GuardianAuth';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { AudioEvidencePlayer } from '../common/AudioEvidencePlayer';
import { getSampleAudioDataUri } from '../../lib/audioSample';
import { ExplainableAIPanel } from './ExplainableAI';

export interface WardGait {
  steps?: number;
  activeMinutes?: number;
  activeBlocks?: number;
  inactiveBlocks?: number;
  notCarriedBlocks?: number;
  hoursAway?: number;
  maxDistanceKm?: number;
  cadenceEstimate?: number;
  updatedAt?: string;
}

export interface WardReport {
  id: string;
  what?: string;
  when?: string;
  who?: string;
  audioUrl?: string;
  hasAudio?: boolean;
  location?: { lat: number; lng: number; accuracyM?: number };
  deviceTime?: string;
  createdAt?: any;
}

export interface WardCheckIn {
  id: string;
  at?: string;
  mood?: number;
  sleep?: number;
  safety?: number;
  coping?: number;
  note?: string;
  distress?: number;
  createdAt?: any;
}

export interface WardSosEvent {
  id: string;
  reason?: string;
  status?: string;
  startedAt?: any;
  deviceTime?: string;
  location?: { lat: number; lng: number; accuracyM?: number };
  audioUrl?: string;
  hasAudio?: boolean;
}

export interface WardEvidence {
  id: string;
  kind?: string;
  linkedTo?: string;
  downloadUrl?: string;
  audioUrl?: string;
  storagePath?: string;
  startedAt?: string;
  endedAt?: string;
  sizeBytes?: number;
  sha256?: string;
  uploaded?: boolean;
  createdAt?: any;
}

export interface WardMember {
  id: string;
  isDemo?: boolean;
  isSimulated?: boolean;
  displayName?: string;
  guardianId?: string;
  guardianName?: string;
  emergencyContact?: string;
  linkedAt?: string;
  memberSince?: string;
  latestMood?: number;
  latestNote?: string;
  latestSleep?: number;
  latestSafety?: number;
  latestCoping?: number;
  latestTier?: string;
  latestScore?: number;
  lastCheckInAt?: string;
  isOnline?: boolean;
  lastHeartbeatAt?: string;
  sosActive?: boolean;
  activeSos?: boolean;
  lastSosAt?: string;
  lastSosReason?: string;
  latestSosAudioUrl?: string;
  hasSosAudio?: boolean;
  lastSosLocation?: {
    lat: number;
    lng: number;
    accuracyM?: number;
    timestamp?: string;
  };
  latestReport?: {
    id?: string;
    what?: string;
    when?: string;
    who?: string;
    audioUrl?: string;
    hasAudio?: boolean;
    location?: { lat: number; lng: number };
    createdAt?: any;
  };
  latestReportAt?: string;
  latestReportAudioUrl?: string;
  hasReportAudio?: boolean;
  gait?: WardGait;
  telemetry?: {
    passiveSensing?: boolean;
    followWatch?: boolean;
    batterySaver?: boolean;
    gait?: WardGait;
  };
  latest?: {
    tier?: string;
    score?: number;
    dateKey?: string;
    confidence?: number;
  };
}

export const isDemoWard = (ward: WardMember | null | undefined): boolean => {
  if (!ward) return false;
  if (ward.isDemo || (ward as any).isSimulated) return true;
  if (ward.id.startsWith('demo-') || ward.id.startsWith('sim-')) return true;
  if (
    ward.displayName === 'Aarav (Connected Ward)' ||
    ward.displayName?.toLowerCase().includes('simulated') ||
    ward.displayName?.toLowerCase().includes('demo')
  ) {
    return true;
  }
  return false;
};

export const GuardianHub: React.FC = () => {
  const { guardian, logoutGuardian, loading: authLoading } = useGuardianAuth();

  const [wards, setWards] = useState<WardMember[]>([]);
  const [selectedWardId, setSelectedWardId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'sos' | 'reports' | 'checkins' | 'gait' | 'audio'>('overview');

  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);
  const [, setNow] = useState(Date.now());

  // Selected ward subcollections live data
  const [wardReports, setWardReports] = useState<WardReport[]>([]);
  const [wardCheckins, setWardCheckins] = useState<WardCheckIn[]>([]);
  const [wardSosEvents, setWardSosEvents] = useState<WardSosEvent[]>([]);
  const [wardEvidence, setWardEvidence] = useState<WardEvidence[]>([]);

  // Periodically refresh current time to update relative heartbeat timestamps
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 5000);
    return () => clearInterval(timer);
  }, []);

  // Emergency SOS Real-Time Popup tracking & audio chime
  const [dismissedSosWards, setDismissedSosWards] = useState<Record<string, string>>({});
  const [lastAlarmSoundedAt, setLastAlarmSoundedAt] = useState<number>(0);

  const playEmergencySiren = () => {
    try {
      const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext;
      if (!AudioContextClass) return;
      const ctx = new AudioContextClass();
      const now = ctx.currentTime;
      for (let i = 0; i < 3; i++) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(880, now + i * 0.4);
        osc.frequency.exponentialRampToValueAtTime(520, now + i * 0.4 + 0.2);
        osc.frequency.exponentialRampToValueAtTime(880, now + i * 0.4 + 0.38);
        gain.gain.setValueAtTime(0.3, now + i * 0.4);
        gain.gain.exponentialRampToValueAtTime(0.01, now + i * 0.4 + 0.39);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now + i * 0.4);
        osc.stop(now + i * 0.4 + 0.4);
      }
    } catch (e) {
      console.warn('Emergency chime audio warning:', e);
    }
  };

  // Detect any ward that has an active SOS alarm that has not been acknowledged
  const activeEmergencyWard = wards.find((w) => {
    const isSos = Boolean(w.sosActive || w.activeSos);
    const sosKey = w.lastSosAt || 'active';
    return isSos && dismissedSosWards[w.id] !== sosKey;
  });

  useEffect(() => {
    if (activeEmergencyWard) {
      const now = Date.now();
      if (now - lastAlarmSoundedAt > 12000) {
        playEmergencySiren();
        setLastAlarmSoundedAt(now);
      }
    }
  }, [activeEmergencyWard?.id, activeEmergencyWard?.lastSosAt, lastAlarmSoundedAt]);

  const handleAcknowledgeSos = (wardId: string, timestamp?: string) => {
    setDismissedSosWards((prev) => ({ ...prev, [wardId]: timestamp || 'active' }));
  };

  const handleInspectSosWard = (ward: WardMember) => {
    handleAcknowledgeSos(ward.id, ward.lastSosAt);
    setSelectedWardId(ward.id);
    setActiveTab('sos');
  };

  // Real-time Firestore subscription with GUARDIAN DATA SCOPING
  useEffect(() => {
    if (!guardian) {
      setLoading(false);
      return;
    }

    const guardianId = guardian.id;
    const pairingCode = guardian.pairingCode || 'GRD-8821';

    try {
      const membersRef = collection(db, 'members');
      const q = query(membersRef);

      const unsubscribe = onSnapshot(q, (snapshot) => {
        const liveMembers: WardMember[] = [];
        
        snapshot.forEach((docSnap) => {
          const data = docSnap.data();
          const memberGuardianId = (data.guardianId || '').toString().trim().toLowerCase();
          const targetId = guardianId.trim().toLowerCase();
          const targetCode = pairingCode.trim().toLowerCase();
          const normalizedCode = targetCode.replace(/[^a-z0-9]/g, '_');

          // Scoping: Only include wards connected to this guardian
          const isMyWard = memberGuardianId === targetId || 
                           memberGuardianId === targetCode || 
                           memberGuardianId === normalizedCode;

          if (isMyWard) {
            liveMembers.push({
              id: docSnap.id,
              ...data,
            } as WardMember);
          }
        });

        // Sort: Active SOS first, then most recent heartbeat or check-in
        liveMembers.sort((a, b) => {
          const aSos = a.sosActive || a.activeSos ? 1 : 0;
          const bSos = b.sosActive || b.activeSos ? 1 : 0;
          if (aSos !== bSos) return bSos - aSos;

          const timeA = new Date(a.lastHeartbeatAt || a.lastCheckInAt || a.linkedAt || 0).getTime();
          const timeB = new Date(b.lastHeartbeatAt || b.lastCheckInAt || b.linkedAt || 0).getTime();
          return timeB - timeA;
        });

        setWards(liveMembers);
        setLoading(false);
      }, (err) => {
        console.warn('[Firestore] Live listener fallback:', err);
        setLoading(false);
      });

      return () => unsubscribe();
    } catch (e) {
      console.warn('Firestore subscription error:', e);
      setLoading(false);
    }
  }, [guardian?.id, guardian?.pairingCode]);

  // Subcollections listener when a specific ward is selected
  useEffect(() => {
    if (!selectedWardId) {
      setWardReports([]);
      setWardCheckins([]);
      setWardSosEvents([]);
      setWardEvidence([]);
      return;
    }

    // 1. Reports listener
    const reportsRef = collection(db, 'members', selectedWardId, 'reports');
    const qReports = query(reportsRef, orderBy('createdAt', 'desc'), limit(20));
    const unsubReports = onSnapshot(qReports, (snap) => {
      const list: WardReport[] = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() } as WardReport));
      setWardReports(list);
    }, (e) => console.warn('Reports listener fallback:', e));

    // 2. Check-ins listener
    const checkinsRef = collection(db, 'members', selectedWardId, 'checkins');
    const qCheckins = query(checkinsRef, orderBy('createdAt', 'desc'), limit(30));
    const unsubCheckins = onSnapshot(qCheckins, (snap) => {
      const list: WardCheckIn[] = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() } as WardCheckIn));
      setWardCheckins(list);
    }, (e) => console.warn('Checkins listener fallback:', e));

    // 3. SOS subcollection listener
    const sosRef = collection(db, 'members', selectedWardId, 'sos');
    const qSos = query(sosRef, orderBy('startedAt', 'desc'), limit(10));
    const unsubSos = onSnapshot(qSos, (snap) => {
      const list: WardSosEvent[] = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() } as WardSosEvent));
      setWardSosEvents(list);
    }, (e) => console.warn('SOS listener fallback:', e));

    // 4. Evidence subcollection listener
    const evidenceRef = collection(db, 'members', selectedWardId, 'evidence');
    const qEvidence = query(evidenceRef, orderBy('createdAt', 'desc'), limit(20));
    const unsubEvidence = onSnapshot(qEvidence, (snap) => {
      const list: WardEvidence[] = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() } as WardEvidence));
      setWardEvidence(list);
    }, (e) => console.warn('Evidence listener fallback:', e));

    return () => {
      unsubReports();
      unsubCheckins();
      unsubSos();
      unsubEvidence();
    };
  }, [selectedWardId]);

  if (authLoading) {
    return (
      <div className="min-h-[70vh] flex items-center justify-center">
        <div className="flex flex-col items-center space-y-3">
          <RefreshCw className="w-8 h-8 text-mool-moss animate-spin" />
          <p className="text-xs text-mool-ink-muted">Loading guardian session...</p>
        </div>
      </div>
    );
  }

  if (!guardian) {
    return <GuardianAuth />;
  }

  const pairingCode = guardian.pairingCode || 'GRD-8821';
  const guardianId = guardian.id;
  const guardianName = guardian.name;

  const qrPayload = JSON.stringify({
    guardianId,
    guardianName,
    code: pairingCode,
    pairingUrl: 'https://moolorg.web.app',
  });

  const handleCopyCode = () => {
    navigator.clipboard.writeText(pairingCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleCopyLink = () => {
    const link = `mool://link?guardianId=${encodeURIComponent(guardianId)}&guardianName=${encodeURIComponent(guardianName)}`;
    navigator.clipboard.writeText(link);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  const getMoodBadge = (mood?: number) => {
    switch (mood) {
      case 5:
        return { label: 'Peaceful', color: 'bg-mool-moss/20 text-mool-moss-dark border-mool-moss/30' };
      case 4:
        return { label: 'Grounded', color: 'bg-mool-moss/10 text-mool-moss border-mool-moss/20' };
      case 3:
        return { label: 'Steady', color: 'bg-mool-mist text-mool-ink border-mool-mist' };
      case 2:
        return { label: 'Unsettled', color: 'bg-mool-sandrose/20 text-mool-sandrose border-mool-sandrose/30' };
      case 1:
        return { label: 'Heavy / Distressed', color: 'bg-mool-signal/15 text-mool-signal border-mool-signal/30' };
      default:
        return { label: 'Active', color: 'bg-mool-mist text-mool-ink-muted border-mool-mist' };
    }
  };

  const getTierBadge = (tier?: string) => {
    switch (tier?.toLowerCase()) {
      case 'outreach':
        return { label: 'Outreach Priority', color: 'bg-mool-signal text-white animate-pulse' };
      case 'watch':
        return { label: 'Careful Watch', color: 'bg-mool-sandrose text-white' };
      case 'stable':
        return { label: 'Stable Grounding', color: 'bg-mool-moss text-white' };
      default:
        return { label: 'Monitoring', color: 'bg-mool-dusk text-white' };
    }
  };

  const isWardOnline = (ward: WardMember) => {
    if (!ward.lastHeartbeatAt) return false;
    const diffMs = Date.now() - new Date(ward.lastHeartbeatAt).getTime();
    return diffMs < 35000;
  };

  const getHeartbeatLabel = (ward: WardMember) => {
    if (!ward.lastHeartbeatAt) return 'Never connected';
    const diffSec = Math.max(0, Math.floor((Date.now() - new Date(ward.lastHeartbeatAt).getTime()) / 1000));
    if (diffSec < 15) return 'Live now • 10s ping';
    if (diffSec < 60) return `Active ${diffSec}s ago`;
    const diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60) return `Idle ${diffMin}m ago`;
    const diffHr = Math.floor(diffMin / 60);
    return `Last seen ${diffHr}h ago`;
  };

  const handleResolveSos = async (wardId: string) => {
    try {
      await setDoc(doc(db, 'members', wardId), {
        sosActive: false,
        activeSos: false,
        lastSosResolvedAt: new Date().toISOString(),
      }, { merge: true });
    } catch (err) {
      console.error('Failed to resolve SOS on Firestore:', err);
    }
  };

  // Demo helpers to simulate events with real audible chime
  const handleSimulateDemoWard = async () => {
    try {
      const demoId = `demo-ward-${Math.floor(100 + Math.random() * 900)}`;
      await setDoc(doc(db, 'members', demoId), {
        id: demoId,
        isDemo: true,
        isSimulated: true,
        displayName: 'Aarav (Demo Simulated Ward)',
        guardianId: guardianId,
        guardianName: guardianName,
        emergencyContact: '+91 98112 34567',
        linkedAt: new Date().toISOString(),
        memberSince: new Date().toISOString(),
        isOnline: true,
        lastHeartbeatAt: new Date().toISOString(),
        latestMood: 4,
        latestNote: 'Practiced breathing exercises this morning. Feeling more grounded today.',
        latestSleep: 4,
        latestSafety: 5,
        latestCoping: 4,
        latestTier: 'stable',
        latestScore: 22.0,
        lastCheckInAt: new Date().toISOString(),
        gait: {
          steps: 5420,
          activeMinutes: 48,
          activeBlocks: 10,
          inactiveBlocks: 32,
          notCarriedBlocks: 6,
          hoursAway: 3.5,
          maxDistanceKm: 4.2,
          cadenceEstimate: 96,
          updatedAt: new Date().toISOString(),
        },
        telemetry: {
          passiveSensing: true,
          followWatch: true,
          batterySaver: false,
        }
      });
      setSelectedWardId(demoId);
    } catch (err) {
      console.error('Demo simulation error:', err);
    }
  };

  const handleDeleteDemoWard = async (wardId: string) => {
    try {
      await deleteDoc(doc(db, 'members', wardId));
      if (selectedWardId === wardId) {
        setSelectedWardId(null);
      }
    } catch (err) {
      console.error('Failed to remove demo ward:', err);
    }
  };

  const handleSimulateReport = async (wardId: string) => {
    try {
      const reportId = `rep_${Date.now().toString(36)}`;
      const sampleAudio = getSampleAudioDataUri('voice');
      const reportData = {
        id: reportId,
        what: 'Suspicious vehicle followed me near the market bus stop. Recorded voice description.',
        when: 'Approximately 20 minutes ago',
        who: 'Silver sedan, license partially visible',
        audioUrl: sampleAudio,
        hasAudio: true,
        deviceTime: new Date().toISOString(),
        location: { lat: 28.6139, lng: 77.2090, accuracyM: 12 },
        createdAt: serverTimestamp(),
      };

      await setDoc(doc(db, 'members', wardId, 'reports', reportId), reportData);
      await setDoc(doc(db, 'members', wardId), {
        latestReport: reportData,
        latestReportAt: new Date().toISOString(),
        latestReportAudioUrl: sampleAudio,
        hasReportAudio: true,
      }, { merge: true });
    } catch (err) {
      console.error('Simulate report error:', err);
    }
  };

  const handleSimulateSos = async (wardId: string) => {
    try {
      const sosId = `sos_${Date.now().toString(36)}`;
      const sampleAudio = getSampleAudioDataUri('alert');
      const sosData = {
        id: sosId,
        reason: 'Emergency SOS triggered from mobile app. Ambient audio recording active.',
        status: 'active',
        startedAt: serverTimestamp(),
        deviceTime: new Date().toISOString(),
        audioUrl: sampleAudio,
        hasAudio: true,
        location: { lat: 28.6139, lng: 77.2090, accuracyM: 8.5 },
      };

      await setDoc(doc(db, 'members', wardId, 'sos', sosId), sosData);
      await setDoc(doc(db, 'members', wardId), {
        sosActive: true,
        activeSos: true,
        lastSosAt: new Date().toISOString(),
        lastSosReason: sosData.reason,
        latestSosAudioUrl: sampleAudio,
        hasSosAudio: true,
        lastSosLocation: sosData.location,
        isOnline: true,
        lastHeartbeatAt: new Date().toISOString(),
      }, { merge: true });
    } catch (err) {
      console.error('Simulate SOS error:', err);
    }
  };

  const handleSimulateCheckIn = async (wardId: string) => {
    try {
      const checkinId = `chk_${Date.now().toString(36)}`;
      const checkInData = {
        id: checkinId,
        at: new Date().toISOString(),
        mood: 4,
        sleep: 4,
        safety: 5,
        coping: 4,
        note: 'Feeling much calmer this evening. Grounding exercises helped a lot.',
        distress: 0.15,
        createdAt: serverTimestamp(),
      };

      await setDoc(doc(db, 'members', wardId, 'checkins', checkinId), checkInData);
      await setDoc(doc(db, 'members', wardId), {
        latestMood: 4,
        latestSleep: 4,
        latestSafety: 5,
        latestCoping: 4,
        latestNote: checkInData.note,
        lastCheckInAt: checkInData.at,
      }, { merge: true });
    } catch (err) {
      console.error('Simulate check-in error:', err);
    }
  };

  const handleSimulateGaitBurst = async (wardId: string) => {
    try {
      const newSteps = Math.floor(4000 + Math.random() * 3000);
      const gaitData: WardGait = {
        steps: newSteps,
        activeMinutes: Math.floor(newSteps / 110),
        activeBlocks: Math.floor(newSteps / 550),
        inactiveBlocks: 28,
        notCarriedBlocks: 4,
        hoursAway: 2.8,
        maxDistanceKm: 3.6,
        cadenceEstimate: Math.floor(88 + Math.random() * 20),
        updatedAt: new Date().toISOString(),
      };

      await setDoc(doc(db, 'members', wardId), {
        gait: gaitData,
        lastHeartbeatAt: new Date().toISOString(),
        isOnline: true,
      }, { merge: true });
    } catch (err) {
      console.error('Simulate gait error:', err);
    }
  };

  const selectedWard = wards.find((w) => w.id === selectedWardId);
  const isSelectedWardDemo = isDemoWard(selectedWard);
  const hasActualWard = wards.some((w) => !isDemoWard(w));

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6 relative">
      {/* REAL-TIME EMERGENCY SOS MODAL POPUP */}
      {activeEmergencyWard && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 bg-black/75 backdrop-blur-md animate-fadeIn">
          <div className="bg-white rounded-organic-lg max-w-lg w-full border-4 border-red-600 shadow-2xl overflow-hidden animate-scaleIn space-y-0">
            {/* Urgent Red Header */}
            <div className="bg-red-600 text-white p-5 flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="w-11 h-11 rounded-full bg-white text-red-600 flex items-center justify-center animate-bounce shrink-0 shadow-sm">
                  <AlertOctagon className="w-7 h-7" />
                </div>
                <div>
                  <h3 className="font-serif text-lg font-bold uppercase tracking-wider flex items-center space-x-2 text-white">
                    <span>EMERGENCY SOS ALERT!</span>
                    <span className="text-[10px] bg-white text-red-700 px-2 py-0.5 rounded font-mono font-bold animate-pulse">
                      LIVE
                    </span>
                  </h3>
                  <p className="text-xs text-red-100 font-sans">
                    Emergency distress alarm triggered on ward's phone.
                  </p>
                </div>
              </div>
              <button
                onClick={() => handleAcknowledgeSos(activeEmergencyWard.id, activeEmergencyWard.lastSosAt)}
                className="text-white/80 hover:text-white text-xs bg-red-700/60 hover:bg-red-700 px-2.5 py-1 rounded transition-colors font-medium"
                title="Dismiss popup (alarm remains active on dashboard)"
              >
                ✕ Dismiss
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-5 sm:p-6 space-y-4">
              <div className="bg-red-50 border border-red-200 rounded-organic p-4 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs text-red-800 font-semibold uppercase tracking-wider">
                    Distressed Ward
                  </span>
                  <span className="text-xs font-mono text-red-900 bg-red-200/70 px-2.5 py-0.5 rounded font-bold">
                    {activeEmergencyWard.displayName || 'Protected Ward'}
                  </span>
                </div>
                <div className="text-sm font-bold text-red-950">
                  {activeEmergencyWard.lastSosReason || 'Emergency SOS alarm triggered from mobile phone.'}
                </div>
                <div className="text-xs text-red-800 flex items-center space-x-1.5 font-mono">
                  <Clock className="w-3.5 h-3.5 text-red-600" />
                  <span>
                    Triggered at: {activeEmergencyWard.lastSosAt ? new Date(activeEmergencyWard.lastSosAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : 'Just now'}
                  </span>
                </div>
              </div>

              {/* Playable Ambient SOS Audio Recording */}
              {activeEmergencyWard.latestSosAudioUrl && (
                <div className="space-y-1.5 pt-1">
                  <span className="text-xs font-bold text-mool-ink flex items-center space-x-1.5">
                    <Radio className="w-4 h-4 text-red-600 animate-pulse" />
                    <span>Live Ambient SOS Audio Recording:</span>
                  </span>
                  <AudioEvidencePlayer
                    src={activeEmergencyWard.latestSosAudioUrl}
                    kind="sos"
                    title="SOS Ambient Recording"
                    timestamp={activeEmergencyWard.lastSosAt}
                  />
                </div>
              )}

              {/* GPS Coordinates & Google Maps Link */}
              {activeEmergencyWard.lastSosLocation?.lat && activeEmergencyWard.lastSosLocation?.lng ? (
                <div className="bg-mool-mist/30 border border-mool-mist rounded-organic p-3.5 flex items-center justify-between gap-3">
                  <div className="text-xs text-mool-ink font-mono flex items-center space-x-2">
                    <MapPin className="w-4 h-4 text-red-600 animate-pulse shrink-0" />
                    <div>
                      <span className="font-bold">Live GPS: </span>
                      <span>
                        {activeEmergencyWard.lastSosLocation.lat.toFixed(5)}, {activeEmergencyWard.lastSosLocation.lng.toFixed(5)}
                      </span>
                    </div>
                  </div>
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${activeEmergencyWard.lastSosLocation.lat},${activeEmergencyWard.lastSosLocation.lng}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center space-x-1 px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded-md text-xs font-bold shadow-sm transition-colors shrink-0"
                  >
                    <span>Open Map</span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              ) : null}

              {/* Emergency Contact Direct Call Button */}
              {activeEmergencyWard.emergencyContact && (
                <a
                  href={`tel:${activeEmergencyWard.emergencyContact}`}
                  className="w-full py-2.5 px-4 bg-emerald-600 hover:bg-emerald-700 text-white rounded-organic text-xs font-bold flex items-center justify-center space-x-2 shadow-sm transition-colors"
                >
                  <Phone className="w-4 h-4" />
                  <span>Call Emergency Contact: {activeEmergencyWard.emergencyContact}</span>
                </a>
              )}

              {/* Bottom Navigation & Resolve Controls */}
              <div className="grid grid-cols-2 gap-3 pt-2">
                <button
                  onClick={() => handleInspectSosWard(activeEmergencyWard)}
                  className="py-2.5 px-4 bg-mool-moss hover:bg-mool-moss-dark text-white rounded-organic text-xs font-bold shadow-sm transition-colors flex items-center justify-center space-x-1.5"
                >
                  <span>Open Ward SOS Tab</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={() => {
                    handleResolveSos(activeEmergencyWard.id);
                    handleAcknowledgeSos(activeEmergencyWard.id, activeEmergencyWard.lastSosAt);
                  }}
                  className="py-2.5 px-4 bg-red-100 hover:bg-red-200 text-red-800 rounded-organic text-xs font-bold transition-colors"
                >
                  Mark Alarm Resolved
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Header Banner */}
      <div className="bg-mool-dusk text-white rounded-organic-lg p-6 sm:p-8 shadow-dusk-elevated relative overflow-hidden">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center md:justify-between gap-6">
          <div className="flex items-start space-x-4">
            <div className="w-14 h-14 rounded-2xl overflow-hidden border-2 border-white/20 shadow-md shrink-0 bg-mool-moss">
              <img src="/app_icon.png" alt="Mool App" className="w-full h-full object-cover" />
            </div>
            <div className="space-y-1.5">
              <div className="inline-flex items-center space-x-2 px-3 py-1 bg-white/10 text-mool-linen rounded-full text-xs font-semibold">
                <ShieldCheck className="w-4 h-4 text-mool-moss-light" />
                <span>Guardian Protective Telemetry & SOS Hub</span>
              </div>
              <h1 className="font-serif text-3xl sm:text-4xl font-bold tracking-tight">
                Guardian Care Portal
              </h1>
              <p className="text-xs sm:text-sm text-mool-linen/80 leading-relaxed max-w-xl">
                Real-time 10s telemetry, incident reports, audio evidence playback, daily check-ins, and emergency SOS alarms.
              </p>
            </div>
          </div>

          {/* Active Guardian Profile Card */}
          <div className="bg-white/10 border border-white/15 rounded-xl p-4 min-w-[280px] space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase font-bold text-mool-sandrose tracking-wider">
                Active Guardian Session
              </span>
              <button
                onClick={logoutGuardian}
                className="text-xs text-mool-linen/80 hover:text-white flex items-center space-x-1 hover:underline font-medium transition-colors"
                title="Sign out of guardian portal"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span>Sign Out</span>
              </button>
            </div>

            <div className="space-y-0.5">
              <div className="text-base font-serif font-bold text-white leading-snug">
                {guardianName}
              </div>
              <div className="text-xs text-mool-linen/70">
                {guardian.role === 'Authorized Support Guardian' ? 'Guardian' : (guardian.role || 'Guardian')}
              </div>
              {guardian.organization && (
                <div className="text-[11px] text-mool-linen/60 flex items-center space-x-1">
                  <Building className="w-3 h-3" />
                  <span>{guardian.organization}</span>
                </div>
              )}
            </div>

            <div className="pt-1.5 border-t border-white/10 flex items-center justify-between text-xs font-mono">
              <span className="text-mool-linen/60">Pairing Code:</span>
              <span className="text-mool-moss-light font-bold bg-black/20 px-2 py-0.5 rounded">
                {pairingCode}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* DETAILED WARD DOSSIER VIEW (When a ward is selected) */}
      {selectedWard ? (
        <div className="space-y-6 animate-fadeIn">
          {/* Back Navigation Bar */}
          <div className="flex items-center justify-between flex-wrap gap-3 bg-white p-4 rounded-organic border border-mool-mist shadow-sm">
            <button
              onClick={() => setSelectedWardId(null)}
              className="inline-flex items-center space-x-2 text-xs font-bold text-mool-moss hover:text-mool-moss-dark hover:underline"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Back to All Connected Wards</span>
            </button>

            {isSelectedWardDemo && (
              <div className="flex items-center space-x-2 flex-wrap gap-2">
                <span className="text-[11px] font-semibold text-amber-800 bg-amber-50 border border-amber-200 px-2 py-0.5 rounded">
                  Demo Simulation:
                </span>
                <button
                  onClick={() => handleSimulateReport(selectedWard.id)}
                  className="text-[11px] px-2.5 py-1 bg-amber-50 text-amber-900 border border-amber-300 rounded-md font-semibold hover:bg-amber-100 transition-colors"
                  title="Simulate incoming incident report with audio"
                >
                  + Test Report & Audio
                </button>
                <button
                  onClick={() => handleSimulateSos(selectedWard.id)}
                  className="text-[11px] px-2.5 py-1 bg-red-50 text-red-700 border border-red-300 rounded-md font-semibold hover:bg-red-100 transition-colors"
                  title="Simulate SOS emergency alarm with audio"
                >
                  + Test SOS & Audio
                </button>
                <button
                  onClick={() => handleSimulateGaitBurst(selectedWard.id)}
                  className="text-[11px] px-2.5 py-1 bg-emerald-50 text-emerald-800 border border-emerald-300 rounded-md font-semibold hover:bg-emerald-100 transition-colors"
                  title="Simulate gait and step sensing"
                >
                  + Test Gait Data
                </button>
                <button
                  onClick={() => handleDeleteDemoWard(selectedWard.id)}
                  className="text-[11px] px-2.5 py-1 bg-red-50 text-red-700 border border-red-200 rounded-md font-semibold hover:bg-red-100 transition-colors inline-flex items-center space-x-1"
                  title="Remove this simulated demo ward"
                >
                  <Trash2 className="w-3 h-3" />
                  <span>Remove Demo</span>
                </button>
              </div>
            )}
          </div>

          {/* Ward Dossier Header */}
          <GroundedCard variant="primary" elevation="floating" className="p-6 space-y-4 border border-mool-mist">
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <div className="space-y-1">
                <div className="flex items-center space-x-3 flex-wrap">
                  <h2 className="font-serif text-2xl font-bold text-mool-ink">
                    {selectedWard.displayName || 'Protected Ward'}
                  </h2>

                  {isWardOnline(selectedWard) ? (
                    <span className="inline-flex items-center space-x-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-700 border border-emerald-500/30">
                      <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
                      <Wifi className="w-3.5 h-3.5 text-emerald-600" />
                      <span>{getHeartbeatLabel(selectedWard)}</span>
                    </span>
                  ) : (
                    <span className="inline-flex items-center space-x-1.5 px-3 py-1 rounded-full text-xs font-medium bg-mool-mist text-mool-ink-muted">
                      <WifiOff className="w-3.5 h-3.5 opacity-60" />
                      <span>{getHeartbeatLabel(selectedWard)}</span>
                    </span>
                  )}

                  <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full border ${getMoodBadge(selectedWard.latestMood).color}`}>
                    Mood: {getMoodBadge(selectedWard.latestMood).label} ({selectedWard.latestMood || 3}/5)
                  </span>

                  <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full ${getTierBadge(selectedWard.latestTier).color}`}>
                    {getTierBadge(selectedWard.latestTier).label}
                  </span>
                </div>

                <p className="text-xs font-mono text-mool-ink-muted">
                  Ward ID: {selectedWard.id} • Registered Emergency Line: {selectedWard.emergencyContact || 'None specified'}
                </p>
              </div>

              {selectedWard.emergencyContact && (
                <a
                  href={`tel:${selectedWard.emergencyContact}`}
                  className="inline-flex items-center justify-center space-x-2 px-4 py-2 bg-mool-moss hover:bg-mool-moss-dark text-white rounded-organic text-xs font-semibold shadow-sm transition-colors"
                >
                  <Phone className="w-3.5 h-3.5" />
                  <span>Call Emergency Line</span>
                </a>
              )}
            </div>

            {/* Navigation Tabs Bar */}
            <div className="flex border-b border-mool-mist pt-2 overflow-x-auto no-scrollbar space-x-2">
              {[
                { id: 'overview', label: 'Overview & Summary', icon: ShieldCheck },
                { id: 'sos', label: `Emergency SOS (${(selectedWard.sosActive || selectedWard.activeSos) ? 'ACTIVE' : (wardSosEvents.length || 0)})`, icon: AlertTriangle },
                { id: 'reports', label: `Incident Reports (${wardReports.length || (selectedWard.latestReport ? 1 : 0)})`, icon: FileText },
                { id: 'checkins', label: `Daily Check-Ins (${wardCheckins.length || (selectedWard.latestMood ? 1 : 0)})`, icon: Heart },
                { id: 'gait', label: 'Gait & Mobility', icon: Footprints },
                { id: 'audio', label: `Audio Vault (${wardEvidence.length || ((selectedWard.latestReportAudioUrl || selectedWard.latestSosAudioUrl) ? 1 : 0)})`, icon: Radio },
              ].map((tab) => {
                const Icon = tab.icon;
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id as any)}
                    className={`flex items-center space-x-2 px-4 py-2.5 text-xs font-semibold border-b-2 whitespace-nowrap transition-colors ${
                      isActive
                        ? 'border-mool-moss text-mool-moss bg-mool-moss/5 rounded-t-lg'
                        : 'border-transparent text-mool-ink-muted hover:text-mool-ink hover:border-mool-mist'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{tab.label}</span>
                  </button>
                );
              })}
            </div>
          </GroundedCard>

          {/* TAB 1: OVERVIEW */}
          {activeTab === 'overview' && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {/* Card 1: SOS Status */}
              <GroundedCard variant="primary" elevation="ground" className={`p-5 space-y-3 border ${(selectedWard.sosActive || selectedWard.activeSos) ? 'border-red-500 bg-red-50/20' : 'border-mool-mist'}`}>
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-mool-ink flex items-center space-x-2">
                    <AlertTriangle className={`w-4 h-4 ${(selectedWard.sosActive || selectedWard.activeSos) ? 'text-red-600 animate-pulse' : 'text-mool-moss'}`} />
                    <span>Emergency SOS Status</span>
                  </span>
                  {(selectedWard.sosActive || selectedWard.activeSos) ? (
                    <span className="text-[10px] bg-red-600 text-white font-bold px-2 py-0.5 rounded animate-pulse">
                      ALARM ACTIVE
                    </span>
                  ) : (
                    <span className="text-[10px] bg-mool-mist text-mool-ink-muted px-2 py-0.5 rounded font-semibold">
                      Clear
                    </span>
                  )}
                </div>

                {(selectedWard.sosActive || selectedWard.activeSos) ? (
                  <div className="space-y-3">
                    <p className="text-xs text-red-800 font-medium">
                      {selectedWard.lastSosReason || 'Emergency alarm triggered from mobile phone.'}
                    </p>
                    {selectedWard.latestSosAudioUrl && (
                      <AudioEvidencePlayer
                        src={selectedWard.latestSosAudioUrl}
                        kind="sos"
                        title="SOS Ambient Audio"
                        timestamp={selectedWard.lastSosAt}
                      />
                    )}
                    <button
                      onClick={() => handleResolveSos(selectedWard.id)}
                      className="w-full py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-xs font-bold transition-colors"
                    >
                      Resolve Active SOS
                    </button>
                  </div>
                ) : (
                  <p className="text-xs text-mool-ink-muted">
                    No active emergency alarms. Device sensors are dormant and ready.
                  </p>
                )}
              </GroundedCard>

              {/* Card 2: Gait & Movement Snapshot */}
              <GroundedCard variant="primary" elevation="ground" className="p-5 space-y-3 border border-mool-mist">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-mool-ink flex items-center space-x-2">
                    <Footprints className="w-4 h-4 text-mool-moss" />
                    <span>Gait & Step Telemetry</span>
                  </span>
                  <span className="text-[10px] bg-mool-moss/10 text-mool-moss-dark px-2 py-0.5 rounded font-semibold">
                    10s Sensed
                  </span>
                </div>

                {selectedWard.gait?.steps !== undefined ? (
                  <div className="space-y-3">
                    <div className="flex items-baseline justify-between">
                      <div className="text-2xl font-serif font-bold text-mool-ink">
                        {selectedWard.gait.steps.toLocaleString()}
                        <span className="text-xs font-sans font-normal text-mool-ink-muted ml-1">steps today</span>
                      </div>
                      <span className="text-xs font-bold text-mool-moss">
                        {Math.min(100, Math.round((selectedWard.gait.steps / 8000) * 100))}% of goal
                      </span>
                    </div>

                    <div className="w-full bg-mool-mist rounded-full h-2 overflow-hidden">
                      <div
                        className="bg-mool-moss h-full transition-all"
                        style={{ width: `${Math.min(100, Math.round((selectedWard.gait.steps / 8000) * 100))}%` }}
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-2 text-[11px] text-mool-ink-muted pt-1">
                      <div>Active Walking: <strong className="text-mool-ink font-mono">{selectedWard.gait.activeMinutes || 0} min</strong></div>
                      <div>Cadence: <strong className="text-mool-ink font-mono">{selectedWard.gait.cadenceEstimate || 0} spm</strong></div>
                      <div>Mobility Radius: <strong className="text-mool-ink font-mono">{selectedWard.gait.maxDistanceKm || 0} km</strong></div>
                      <div>Away Home: <strong className="text-mool-ink font-mono">{selectedWard.gait.hoursAway || 0} hr</strong></div>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <p className="text-xs text-mool-ink-muted">
                      Awaiting initial gait telemetry sync from the phone sensors.
                    </p>
                    {isSelectedWardDemo && (
                      <button
                        onClick={() => handleSimulateGaitBurst(selectedWard.id)}
                        className="text-xs text-mool-moss font-semibold hover:underline"
                      >
                        + Simulate Gait Burst
                      </button>
                    )}
                  </div>
                )}
              </GroundedCard>

              {/* Card 3: Latest Report / Reflection */}
              <GroundedCard variant="primary" elevation="ground" className="p-5 space-y-3 border border-mool-mist">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-mool-ink flex items-center space-x-2">
                    <FileText className="w-4 h-4 text-mool-moss" />
                    <span>Latest Incident Report</span>
                  </span>
                  <span className="text-[10px] bg-amber-100 text-amber-900 px-2 py-0.5 rounded font-semibold">
                    {wardReports.length > 0 ? `${wardReports.length} Filed` : 'Recent'}
                  </span>
                </div>

                {selectedWard.latestReport?.what || wardReports[0]?.what ? (
                  <div className="space-y-2.5">
                    <p className="text-xs text-mool-ink italic bg-mool-mist/30 p-2.5 rounded-lg border border-mool-mist">
                      "{selectedWard.latestReport?.what || wardReports[0]?.what}"
                    </p>
                    {(selectedWard.latestReportAudioUrl || wardReports[0]?.audioUrl) && (
                      <AudioEvidencePlayer
                        src={selectedWard.latestReportAudioUrl || wardReports[0]?.audioUrl}
                        kind="report"
                        title="Spoken Incident Evidence"
                        timestamp={selectedWard.latestReportAt}
                      />
                    )}
                  </div>
                ) : (
                  <div className="space-y-2">
                    <p className="text-xs text-mool-ink-muted">
                      No incident reports filed by this ward yet.
                    </p>
                    {isSelectedWardDemo && (
                      <button
                        onClick={() => handleSimulateReport(selectedWard.id)}
                        className="text-xs text-mool-moss font-semibold hover:underline"
                      >
                        + Test Incident Report with Audio
                      </button>
                    )}
                  </div>
                )}
              </GroundedCard>
            </div>

              {/* AI Explainability Panel — Full Width */}
              <ExplainableAIPanel
                ward={selectedWard}
                checkins={wardCheckins}
                isExpanded={false}
              />
            </div>
          )}

          {/* TAB 2: EMERGENCY SOS ALARMS */}
          {activeTab === 'sos' && (
            <div className="space-y-6">
              {(selectedWard.sosActive || selectedWard.activeSos) ? (
                <div className="bg-red-50 border-2 border-red-500/60 rounded-organic-lg p-6 space-y-4 shadow-md ring-2 ring-red-500/20">
                  <div className="flex items-start justify-between flex-wrap gap-3">
                    <div className="flex items-center space-x-3">
                      <div className="w-12 h-12 rounded-full bg-red-600 text-white flex items-center justify-center animate-bounce shrink-0">
                        <AlertOctagon className="w-7 h-7" />
                      </div>
                      <div>
                        <h3 className="text-base font-bold text-red-950 flex items-center space-x-2">
                          <span>CRITICAL EMERGENCY SOS ACTIVE</span>
                          <span className="text-xs bg-red-600 text-white px-2 py-0.5 rounded font-mono uppercase font-bold animate-pulse">
                            LIVE ALARM
                          </span>
                        </h3>
                        <p className="text-xs text-red-800">
                          {selectedWard.lastSosReason || 'Emergency button or distress alert triggered from mobile app.'}
                        </p>
                      </div>
                    </div>

                    <button
                      onClick={() => handleResolveSos(selectedWard.id)}
                      className="px-4 py-2 bg-white text-red-700 hover:bg-red-100 rounded-lg border border-red-300 text-xs font-bold shadow-sm transition-colors"
                    >
                      Mark Alarm Resolved
                    </button>
                  </div>

                  {/* Audio Recording attached to active SOS */}
                  {selectedWard.latestSosAudioUrl && (
                    <div className="space-y-1.5 pt-2 border-t border-red-200">
                      <span className="text-xs font-bold text-red-900 flex items-center space-x-1.5">
                        <Radio className="w-3.5 h-3.5 text-red-600" />
                        <span>Live Ambient SOS Audio Recording:</span>
                      </span>
                      <AudioEvidencePlayer
                        src={selectedWard.latestSosAudioUrl}
                        kind="sos"
                        title="Emergency SOS Ambient Evidence"
                        timestamp={selectedWard.lastSosAt}
                      />
                    </div>
                  )}

                  {/* GPS Pin */}
                  {selectedWard.lastSosLocation?.lat && selectedWard.lastSosLocation?.lng && (
                    <div className="bg-white border border-red-200 rounded-lg p-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                      <div className="flex items-center space-x-2 text-xs text-red-950 font-mono">
                        <MapPin className="w-4 h-4 text-red-600 shrink-0 animate-pulse" />
                        <div>
                          <span className="font-semibold text-red-900">Ward Live Location: </span>
                          <span>{selectedWard.lastSosLocation.lat.toFixed(5)}, {selectedWard.lastSosLocation.lng.toFixed(5)}</span>
                          {selectedWard.lastSosLocation.accuracyM && (
                            <span className="text-[10px] text-red-600 ml-1.5 font-sans font-medium">
                              (±{Math.round(selectedWard.lastSosLocation.accuracyM)}m accuracy)
                            </span>
                          )}
                        </div>
                      </div>

                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${selectedWard.lastSosLocation.lat},${selectedWard.lastSosLocation.lng}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center space-x-1.5 px-3.5 py-1.5 bg-red-600 hover:bg-red-700 text-white text-xs font-semibold rounded-md shadow-sm transition-colors shrink-0"
                      >
                        <MapPin className="w-3.5 h-3.5" />
                        <span>Open in Google Maps</span>
                        <ExternalLink className="w-3 h-3 ml-0.5" />
                      </a>
                    </div>
                  )}
                </div>
              ) : (
                <div className="bg-white rounded-organic p-8 text-center border border-mool-mist space-y-3 shadow-sm">
                  <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center mx-auto">
                    <ShieldCheck className="w-6 h-6" />
                  </div>
                  <h4 className="font-serif text-base font-bold text-mool-ink">No Active Emergency SOS</h4>
                  <p className="text-xs text-mool-ink-muted max-w-md mx-auto">
                    Your ward is currently safe. If they press the emergency button or trigger distress alerts, an instant high-priority alarm will sound here with live GPS and audio evidence.
                  </p>
                  {isSelectedWardDemo && (
                    <button
                      onClick={() => handleSimulateSos(selectedWard.id)}
                      className="text-xs text-red-600 font-semibold hover:underline"
                    >
                      + Test Emergency SOS Alarm
                    </button>
                  )}
                </div>
              )}

              {/* Past SOS Log */}
              <div className="space-y-3">
                <h4 className="font-serif text-base font-bold text-mool-ink">
                  Past SOS Logs & Evidence ({wardSosEvents.length})
                </h4>
                {wardSosEvents.length === 0 ? (
                  <p className="text-xs text-mool-ink-muted italic">No historical SOS events recorded.</p>
                ) : (
                  wardSosEvents.map((sos) => {
                    const sosAudio = sos.audioUrl ||
                      wardEvidence.find((ev) => ev.linkedTo === `sos/${sos.id}` || (sos as any).audioEvidenceId === ev.id)?.audioUrl ||
                      wardEvidence.find((ev) => ev.linkedTo === `sos/${sos.id}` || (sos as any).audioEvidenceId === ev.id)?.downloadUrl ||
                      (selectedWard.lastSosReason === sos.reason ? selectedWard.latestSosAudioUrl : undefined);

                    return (
                      <div key={sos.id} className="bg-white p-4 rounded-organic border border-mool-mist space-y-2.5">
                        <div className="flex items-center justify-between text-xs">
                          <span className="font-bold text-mool-ink">{sos.reason || 'Emergency SOS'}</span>
                          <span className="font-mono text-[11px] text-mool-ink-muted">
                            {sos.startedAt?.toDate ? sos.startedAt.toDate().toLocaleString() : (sos.deviceTime || 'Recorded')}
                          </span>
                        </div>
                        {sosAudio && (
                          <AudioEvidencePlayer
                            src={sosAudio}
                            kind="sos"
                            title="Archived Ambient SOS Recording"
                            timestamp={sos.deviceTime}
                          />
                        )}
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          )}

          {/* TAB 3: INCIDENT REPORTS ("Report Something") */}
          {activeTab === 'reports' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-serif text-lg font-bold text-mool-ink">
                    Incident Reports Sent by Ward ({wardReports.length})
                  </h3>
                  <p className="text-xs text-mool-ink-muted">
                    Confidential incident reports logged from the "Report something that happened" tool on the mobile phone.
                  </p>
                </div>
                {isSelectedWardDemo && (
                  <button
                    onClick={() => handleSimulateReport(selectedWard.id)}
                    className="px-3 py-1.5 bg-amber-50 text-amber-900 border border-amber-300 rounded-lg text-xs font-semibold hover:bg-amber-100 transition-colors"
                  >
                    + Simulate Ward Report
                  </button>
                )}
              </div>

              {wardReports.length === 0 && !selectedWard.latestReport?.what ? (
                <div className="bg-white rounded-organic p-8 text-center border border-mool-mist space-y-3 shadow-sm">
                  <FileText className="w-8 h-8 text-mool-ink-muted mx-auto opacity-50" />
                  <p className="text-xs text-mool-ink-muted">No incident reports filed by this ward yet.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {wardReports.map((report) => {
                    const reportAudio = report.audioUrl || 
                      wardEvidence.find((ev) => ev.linkedTo === `reports/${report.id}` || (report as any).audioEvidenceId === ev.id || (report as any).evidenceIds?.includes(ev.id))?.audioUrl ||
                      wardEvidence.find((ev) => ev.linkedTo === `reports/${report.id}` || (report as any).audioEvidenceId === ev.id || (report as any).evidenceIds?.includes(ev.id))?.downloadUrl ||
                      (selectedWard.latestReport?.id === report.id ? selectedWard.latestReportAudioUrl : undefined);

                    return (
                      <div key={report.id} className="bg-white rounded-organic p-5 border border-mool-mist space-y-3.5 shadow-sm">
                        <div className="flex items-start justify-between flex-wrap gap-2">
                          <div className="space-y-0.5">
                            <span className="text-[10px] font-bold uppercase tracking-wider text-amber-800 bg-amber-100 px-2 py-0.5 rounded">
                              Incident Report
                            </span>
                            <h4 className="text-sm font-bold text-mool-ink pt-1">
                              {report.what || 'No written description'}
                            </h4>
                          </div>
                          <span className="text-[11px] font-mono text-mool-ink-muted">
                            {report.createdAt?.toDate ? report.createdAt.toDate().toLocaleString() : (report.deviceTime || 'Recent')}
                          </span>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-mool-ink-muted bg-mool-mist/20 p-3 rounded-lg border border-mool-mist">
                          <div>
                            <strong className="text-mool-ink">When:</strong> {report.when || 'Not specified'}
                          </div>
                          <div>
                            <strong className="text-mool-ink">Who:</strong> {report.who || 'Not identified / confidential'}
                          </div>
                          {report.location?.lat && (
                            <div className="sm:col-span-2 flex items-center space-x-1 font-mono text-[11px] text-mool-moss-dark">
                              <MapPin className="w-3 h-3" />
                              <span>GPS: {report.location.lat.toFixed(4)}, {report.location.lng.toFixed(4)}</span>
                            </div>
                          )}
                        </div>

                        {/* PLAYABLE AUDIO RECORDING PLAYER */}
                        {reportAudio ? (
                          <div className="pt-1">
                            <AudioEvidencePlayer
                              src={reportAudio}
                              kind="report"
                              title="Spoken Audio Evidence Attached to Report"
                              timestamp={report.deviceTime}
                            />
                          </div>
                        ) : (
                          <div className="text-[11px] text-mool-ink-muted italic flex items-center space-x-1.5">
                            <Radio className="w-3 h-3 opacity-40" />
                            <span>No audio recording attached to this text report</span>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* TAB 4: DAILY CHECK-INS & MOOD */}
          {activeTab === 'checkins' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-serif text-lg font-bold text-mool-ink">
                    Daily Check-In Reflections ({wardCheckins.length})
                  </h3>
                  <p className="text-xs text-mool-ink-muted">
                    Mood, sleep quality, coping, and private reflections shared from the ward's daily check-in.
                  </p>
                </div>
                {isSelectedWardDemo && (
                  <button
                    onClick={() => handleSimulateCheckIn(selectedWard.id)}
                    className="px-3 py-1.5 bg-mool-moss/10 text-mool-moss-dark border border-mool-moss/30 rounded-lg text-xs font-semibold hover:bg-mool-moss/20 transition-colors"
                  >
                    + Simulate Daily Check-In
                  </button>
                )}
              </div>

              {wardCheckins.length === 0 && !selectedWard.latestMood ? (
                <div className="bg-white rounded-organic p-8 text-center border border-mool-mist space-y-3 shadow-sm">
                  <Heart className="w-8 h-8 text-mool-ink-muted mx-auto opacity-50" />
                  <p className="text-xs text-mool-ink-muted">No check-in history logged yet.</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {wardCheckins.map((chk) => {
                    const badge = getMoodBadge(chk.mood);
                    return (
                      <div key={chk.id} className="bg-white rounded-organic p-4 border border-mool-mist space-y-2.5 shadow-sm">
                        <div className="flex items-center justify-between flex-wrap gap-2">
                          <div className="flex items-center space-x-2">
                            <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full border ${badge.color}`}>
                              Mood: {badge.label} ({chk.mood || 3}/5)
                            </span>
                            <span className="text-xs text-mool-ink-muted">
                              Sleep: {chk.sleep || 3}/5 • Safety: {chk.safety || 3}/5 • Coping: {chk.coping || 3}/5
                            </span>
                          </div>
                          <span className="text-[11px] font-mono text-mool-ink-muted">
                            {chk.at ? new Date(chk.at).toLocaleDateString() : 'Today'}
                          </span>
                        </div>

                        {chk.note && (
                          <p className="text-xs text-mool-ink italic bg-mool-mist/30 p-2.5 rounded-lg border border-mool-mist">
                            "{chk.note}"
                          </p>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* TAB 5: GAIT & MOBILITY TELEMETRY */}
          {activeTab === 'gait' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-serif text-lg font-bold text-mool-ink">
                    Gait & Passive Movement Telemetry
                  </h3>
                  <p className="text-xs text-mool-ink-muted">
                    Computed entirely on-device via TensorFlow Lite accelerometer classifier and low-power pedometer hardware.
                  </p>
                </div>
                {isSelectedWardDemo && (
                  <button
                    onClick={() => handleSimulateGaitBurst(selectedWard.id)}
                    className="px-3 py-1.5 bg-emerald-50 text-emerald-800 border border-emerald-300 rounded-lg text-xs font-semibold hover:bg-emerald-100 transition-colors"
                  >
                    + Simulate Gait Update
                  </button>
                )}
              </div>

              {/* Big Gauges Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-white p-5 rounded-organic border border-mool-mist space-y-2 shadow-sm">
                  <div className="text-xs text-mool-ink-muted flex items-center space-x-1.5">
                    <Footprints className="w-4 h-4 text-mool-moss" />
                    <span>Daily Steps Sensed</span>
                  </div>
                  <div className="text-3xl font-serif font-bold text-mool-ink">
                    {(selectedWard.gait?.steps || 0).toLocaleString()}
                  </div>
                  <div className="text-[11px] text-mool-moss font-semibold">
                    Hardware pedometer • Low battery
                  </div>
                </div>

                <div className="bg-white p-5 rounded-organic border border-mool-mist space-y-2 shadow-sm">
                  <div className="text-xs text-mool-ink-muted flex items-center space-x-1.5">
                    <Activity className="w-4 h-4 text-mool-moss" />
                    <span>Active Gait Walking</span>
                  </div>
                  <div className="text-3xl font-serif font-bold text-mool-ink">
                    {selectedWard.gait?.activeMinutes || 0}
                    <span className="text-sm font-sans font-normal text-mool-ink-muted ml-1">mins</span>
                  </div>
                  <div className="text-[11px] text-mool-ink-muted">
                    {selectedWard.gait?.activeBlocks || 0} active 5-min gait blocks
                  </div>
                </div>

                <div className="bg-white p-5 rounded-organic border border-mool-mist space-y-2 shadow-sm">
                  <div className="text-xs text-mool-ink-muted flex items-center space-x-1.5">
                    <MapPin className="w-4 h-4 text-mool-sandrose" />
                    <span>Mobility Outside Home</span>
                  </div>
                  <div className="text-3xl font-serif font-bold text-mool-ink">
                    {selectedWard.gait?.maxDistanceKm || 0}
                    <span className="text-sm font-sans font-normal text-mool-ink-muted ml-1">km radius</span>
                  </div>
                  <div className="text-[11px] text-mool-ink-muted">
                    {selectedWard.gait?.hoursAway || 0} hours away from home
                  </div>
                </div>

                <div className="bg-white p-5 rounded-organic border border-mool-mist space-y-2 shadow-sm">
                  <div className="text-xs text-mool-ink-muted flex items-center space-x-1.5">
                    <Radio className="w-4 h-4 text-mool-dusk" />
                    <span>Estimated Cadence</span>
                  </div>
                  <div className="text-3xl font-serif font-bold text-mool-ink">
                    {selectedWard.gait?.cadenceEstimate || 0}
                    <span className="text-sm font-sans font-normal text-mool-ink-muted ml-1">spm</span>
                  </div>
                  <div className="text-[11px] text-mool-moss font-semibold">
                    Normal rhythmic gait pace
                  </div>
                </div>
              </div>

              {/* Confinement & Freeze Alert Analysis */}
              <div className="bg-mool-mist/30 rounded-organic p-4 border border-mool-mist space-y-1.5 text-xs text-mool-ink">
                <span className="font-bold flex items-center space-x-1.5 text-mool-moss-dark">
                  <ShieldCheck className="w-4 h-4" />
                  <span>Mobility Freeze & Confinement Detection Analysis:</span>
                </span>
                <p className="text-mool-ink-muted leading-relaxed">
                  Prolonged zero-movement patterns or severe step drop-offs are correlated with trauma freeze responses or involuntary confinement. 
                  Currently, this ward exhibits healthy active periods ({selectedWard.gait?.activeMinutes || 0} mins) with normal step cadence.
                </p>
              </div>
            </div>
          )}

          {/* TAB 6: AUDIO EVIDENCE VAULT */}
          {activeTab === 'audio' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-serif text-lg font-bold text-mool-ink">
                    Audio Recordings Vault
                  </h3>
                  <p className="text-xs text-mool-ink-muted">
                    Every voice note, incident recording, and emergency SOS audio file transmitted by this ward.
                  </p>
                </div>
              </div>

              {/* Aggregate all audio recordings */}
              {(() => {
                const audioItems: Array<{ id: string; url: string; kind: string; title: string; date?: string; sha256?: string }> = [];

                if (selectedWard.latestSosAudioUrl) {
                  audioItems.push({
                    id: 'sos_latest',
                    url: selectedWard.latestSosAudioUrl,
                    kind: 'sos',
                    title: 'Active Emergency SOS Ambient Recording',
                    date: selectedWard.lastSosAt,
                  });
                }

                if (selectedWard.latestReportAudioUrl) {
                  audioItems.push({
                    id: 'rep_latest',
                    url: selectedWard.latestReportAudioUrl,
                    kind: 'report',
                    title: 'Latest Incident Audio Evidence',
                    date: selectedWard.latestReportAt,
                  });
                }

                wardReports.forEach((r) => {
                  if (r.audioUrl && !audioItems.some((a) => a.url === r.audioUrl)) {
                    audioItems.push({
                      id: r.id,
                      url: r.audioUrl,
                      kind: 'report',
                      title: `Incident Audio: ${r.what?.substring(0, 35) || 'Report Evidence'}...`,
                      date: r.deviceTime,
                    });
                  }
                });

                wardEvidence.forEach((ev) => {
                  if (ev.downloadUrl && !audioItems.some((a) => a.url === ev.downloadUrl)) {
                    audioItems.push({
                      id: ev.id,
                      url: ev.downloadUrl,
                      kind: ev.kind || 'evidence',
                      title: ev.kind === 'sos' ? 'SOS Ambient Audio' : 'Spoken Audio Evidence',
                      date: ev.startedAt,
                      sha256: ev.sha256,
                    });
                  }
                });

                if (audioItems.length === 0) {
                  return (
                    <div className="bg-white rounded-organic p-8 text-center border border-mool-mist space-y-3 shadow-sm">
                      <Radio className="w-8 h-8 text-mool-ink-muted mx-auto opacity-50" />
                      {isSelectedWardDemo && (
                        <button
                          onClick={() => handleSimulateReport(selectedWard.id)}
                          className="text-xs text-mool-moss font-semibold hover:underline"
                        >
                          + Simulate Audio Recording Upload
                        </button>
                      )}
                    </div>
                  );
                }

                return (
                  <div className="space-y-3">
                    {audioItems.map((item) => (
                      <AudioEvidencePlayer
                        key={item.id}
                        src={item.url}
                        kind={item.kind}
                        title={item.title}
                        timestamp={item.date}
                        sha256={item.sha256}
                      />
                    ))}
                  </div>
                );
              })()}
            </div>
          )}
        </div>
      ) : (
        /* DEFAULT VIEW: LIST OF ALL CONNECTED WARDS & QR CODE */
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
          {/* LEFT: QR Code Pairing Card */}
          <div className="lg:col-span-5 space-y-4">
            <GroundedCard variant="primary" elevation="floating" className="p-6 space-y-5 border-2 border-mool-moss/20">
              <div className="flex items-center justify-between border-b border-mool-mist pb-3">
                <div className="flex items-center space-x-2.5">
                  <div className="w-8 h-8 rounded-full bg-mool-moss text-white flex items-center justify-center">
                    <QrCode className="w-4 h-4" />
                  </div>
                  <div>
                    <h2 className="font-serif text-base font-bold text-mool-ink">Connect New Ward</h2>
                    <p className="text-[11px] text-mool-ink-muted">Scan using Mool Mobile App</p>
                  </div>
                </div>
                <span className="flex items-center space-x-1.5 text-[10px] font-semibold text-mool-moss bg-mool-moss/10 px-2 py-0.5 rounded-full">
                  <span className="w-2 h-2 rounded-full bg-mool-moss animate-pulse" />
                  <span>Pairing Active</span>
                </span>
              </div>

              {/* QR Code Graphic */}
              <div className="bg-white p-5 rounded-organic border border-mool-mist shadow-sm flex flex-col items-center justify-center space-y-3">
                <div className="p-2 border-2 border-mool-moss/20 rounded-lg">
                  <QRCodeSVG
                    value={qrPayload}
                    size={190}
                    level="H"
                    includeMargin={true}
                    fgColor="#1E2A26"
                    bgColor="#FFFFFF"
                  />
                </div>
                <p className="text-[11px] text-mool-ink-muted text-center max-w-xs leading-relaxed">
                  Open the <strong>Mool app</strong> on your ward's phone and point the camera at this code.
                </p>
              </div>

              {/* Manual Code Fallback */}
              <div className="bg-mool-mist/40 border border-mool-mist rounded-organic p-3.5 space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-mool-ink-muted">Manual 8-character pairing code:</span>
                  <span className="font-mono text-sm font-bold text-mool-ink tracking-wider bg-white px-2.5 py-0.5 rounded border border-mool-mist">
                    {pairingCode}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    onClick={handleCopyCode}
                    className="py-1.5 px-3 rounded-md bg-white border border-mool-mist hover:bg-mool-mist/50 text-xs font-semibold text-mool-ink flex items-center justify-center space-x-1.5 transition-colors"
                  >
                    {copied ? <Check className="w-3.5 h-3.5 text-mool-moss" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copied ? 'Copied Code' : 'Copy Code'}</span>
                  </button>
                  <button
                    onClick={handleCopyLink}
                    className="py-1.5 px-3 rounded-md bg-white border border-mool-mist hover:bg-mool-mist/50 text-xs font-semibold text-mool-ink flex items-center justify-center space-x-1.5 transition-colors"
                  >
                    {copiedLink ? <Check className="w-3.5 h-3.5 text-mool-moss" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedLink ? 'Copied Link' : 'Copy App Link'}</span>
                  </button>
                </div>
              </div>
            </GroundedCard>
          </div>

          {/* RIGHT: Connected Wards List */}
          <div className="lg:col-span-7 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Users className="w-5 h-5 text-mool-moss" />
                <h2 className="font-serif text-xl font-bold text-mool-ink">
                  Your Connected Wards ({wards.length})
                </h2>
              </div>
              {!hasActualWard && (
                <button
                  onClick={handleSimulateDemoWard}
                  className="text-xs text-mool-moss hover:underline font-semibold flex items-center space-x-1"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  <span>+ Simulate Ward Pair</span>
                </button>
              )}
            </div>

            {loading ? (
              <div className="bg-white rounded-organic p-12 text-center border border-mool-mist space-y-3">
                <RefreshCw className="w-8 h-8 text-mool-moss animate-spin mx-auto" />
                <p className="text-xs text-mool-ink-muted">Listening for live connections from your wards...</p>
              </div>
            ) : wards.length === 0 ? (
              <div className="bg-white rounded-organic p-10 text-center border border-mool-mist space-y-4 shadow-sm">
                <div className="w-14 h-14 rounded-full bg-mool-moss/10 text-mool-moss flex items-center justify-center mx-auto">
                  <ShieldCheck className="w-7 h-7" />
                </div>
                <div className="space-y-1">
                  <h3 className="font-serif text-lg font-bold text-mool-ink">No Protected Wards Connected Yet</h3>
                  <p className="text-xs text-mool-ink-muted max-w-sm mx-auto leading-relaxed">
                    Have the person you are supporting scan your QR code on the left or enter pairing code <strong className="text-mool-ink font-mono">{pairingCode}</strong> from their Mool mobile app.
                  </p>
                </div>
                <div className="pt-2">
                  <OrganicButton variant="moss" size="sm" onClick={handleSimulateDemoWard}>
                    <Sparkles className="w-3.5 h-3.5 mr-1.5" />
                    <span>Connect a Simulated Ward for Testing</span>
                  </OrganicButton>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                {wards.map((ward) => {
                  const moodBadge = getMoodBadge(ward.latestMood);
                  const tierBadge = getTierBadge(ward.latestTier || ward.latest?.tier);
                  const online = isWardOnline(ward);
                  const isSosActive = Boolean(ward.sosActive || ward.activeSos);

                  return (
                    <GroundedCard
                      key={ward.id}
                      variant="primary"
                      elevation="ground"
                      className={`p-5 space-y-4 transition-all border ${
                        isSosActive 
                          ? 'border-red-500/60 bg-red-50/20 shadow-md ring-2 ring-red-500/20' 
                          : 'border-mool-mist hover:border-mool-moss/40'
                      }`}
                    >
                      {/* Top Header */}
                      <div className="flex items-start justify-between gap-2">
                        <div className="space-y-1">
                          <div className="flex items-center space-x-2.5 flex-wrap">
                            <h3 className="font-serif text-lg font-bold text-mool-ink">
                              {ward.displayName || 'Protected Ward'}
                            </h3>

                            {online ? (
                              <span className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-500/10 text-emerald-700 border border-emerald-500/30">
                                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
                                <Wifi className="w-3 h-3 text-emerald-600" />
                                <span>{getHeartbeatLabel(ward)}</span>
                              </span>
                            ) : (
                              <span className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-medium bg-mool-mist text-mool-ink-muted">
                                <WifiOff className="w-3 h-3 opacity-60" />
                                <span>{getHeartbeatLabel(ward)}</span>
                              </span>
                            )}

                            <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full border ${moodBadge.color}`}>
                              Mood: {moodBadge.label} ({ward.latestMood || 3}/5)
                            </span>

                            {isDemoWard(ward) && (
                              <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-amber-100 text-amber-900 border border-amber-300">
                                Demo
                              </span>
                            )}
                          </div>

                          <p className="text-[11px] font-mono text-mool-ink-muted">
                            ID: {ward.id} • Linked: {ward.linkedAt ? new Date(ward.linkedAt).toLocaleDateString() : 'Active'}
                            {ward.emergencyContact && ` • Emergency: ${ward.emergencyContact}`}
                          </p>
                        </div>

                        <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${tierBadge.color}`}>
                          {tierBadge.label}
                        </span>
                      </div>

                      {/* SOS Active Alert */}
                      {isSosActive && (
                        <div className="bg-red-50 border-2 border-red-500/40 rounded-organic p-4 space-y-3 shadow-sm">
                          <div className="flex items-start justify-between gap-2">
                            <div className="flex items-center space-x-2.5">
                              <AlertOctagon className="w-5 h-5 text-red-600 shrink-0 animate-bounce" />
                              <div>
                                <h4 className="text-xs font-bold text-red-950 uppercase">
                                  CRITICAL EMERGENCY SOS ACTIVE
                                </h4>
                                <p className="text-xs text-red-800">
                                  {ward.lastSosReason || 'Emergency button pressed on phone.'}
                                </p>
                              </div>
                            </div>
                            <button
                              onClick={() => handleResolveSos(ward.id)}
                              className="text-xs bg-white text-red-700 px-3 py-1 rounded border border-red-300 font-semibold"
                            >
                              Resolve
                            </button>
                          </div>

                          {/* SOS Playable Audio */}
                          {ward.latestSosAudioUrl && (
                            <AudioEvidencePlayer
                              src={ward.latestSosAudioUrl}
                              kind="sos"
                              title="SOS Ambient Audio Recording"
                            />
                          )}
                        </div>
                      )}

                      {/* Quick Snapshot Metrics: Gait & Latest Report */}
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                        {/* Gait snippet */}
                        <div className="bg-mool-mist/20 p-3 rounded-lg border border-mool-mist space-y-1">
                          <div className="text-[11px] font-semibold text-mool-ink flex items-center space-x-1.5">
                            <Footprints className="w-3.5 h-3.5 text-mool-moss" />
                            <span>Gait & Step Count</span>
                          </div>
                          <div className="text-lg font-serif font-bold text-mool-ink">
                            {(ward.gait?.steps || 0).toLocaleString()}
                            <span className="text-[11px] font-sans font-normal text-mool-ink-muted ml-1">steps today</span>
                          </div>
                          <div className="text-[10px] text-mool-ink-muted">
                            Active Walking: {ward.gait?.activeMinutes || 0} mins • Cadence: {ward.gait?.cadenceEstimate || 0} spm
                          </div>
                        </div>

                        {/* Report snippet */}
                        <div className="bg-mool-mist/20 p-3 rounded-lg border border-mool-mist space-y-1">
                          <div className="text-[11px] font-semibold text-mool-ink flex items-center space-x-1.5">
                            <FileText className="w-3.5 h-3.5 text-mool-sandrose" />
                            <span>Incident Report</span>
                          </div>
                          {ward.latestReport?.what ? (
                            <div>
                              <p className="text-xs text-mool-ink italic truncate">
                                "{ward.latestReport.what}"
                              </p>
                              <div className="text-[10px] text-mool-moss font-semibold pt-0.5">
                                {ward.latestReportAudioUrl ? '🎙️ Audio Recording Attached' : 'Written report'}
                              </div>
                            </div>
                          ) : (
                            <p className="text-xs text-mool-ink-muted">No incident reports filed.</p>
                          )}
                        </div>
                      </div>

                      {/* Footer Actions */}
                      <div className="flex items-center justify-between pt-3 border-t border-mool-mist text-xs flex-wrap gap-2">
                        <div className="flex items-center space-x-3 text-mool-ink-muted">
                          <span className="flex items-center space-x-1">
                            <Activity className="w-3.5 h-3.5 text-mool-moss" />
                            <span>Distress: {ward.latestScore ? ward.latestScore.toFixed(0) : '20'}/100</span>
                          </span>
                        </div>

                        <div className="flex items-center space-x-2">
                          {isDemoWard(ward) && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteDemoWard(ward.id);
                              }}
                              className="text-xs text-red-600 hover:text-red-700 px-2.5 py-1.5 rounded-lg border border-red-200 hover:bg-red-50 inline-flex items-center space-x-1 transition-colors"
                              title="Remove demo ward from dashboard"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                              <span>Remove Demo</span>
                            </button>
                          )}
                          <button
                            onClick={() => {
                              setSelectedWardId(ward.id);
                              setActiveTab('overview');
                            }}
                            className="font-bold text-white bg-mool-moss hover:bg-mool-moss-dark px-3 py-1.5 rounded-lg inline-flex items-center space-x-1.5 shadow-sm transition-colors"
                          >
                            <span>Inspect Ward Dossier & Telemetry</span>
                            <ArrowRight className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    </GroundedCard>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
