import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { 
  User, 
  ShieldCheck, 
  PhoneCall, 
  AlertTriangle, 
  FileText, 
  ArrowLeft, 
  Send, 
  Volume2, 
  Calendar, 
  Heart, 
  Moon, 
  Shield, 
  Smile, 
  Activity, 
  Users, 
  Clock,
  CheckCircle2,
  Scale
} from 'lucide-react';
import { doc, onSnapshot, collection, query, orderBy, limit } from 'firebase/firestore';
import { db } from '../../lib/firebase/firestore';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { useAuth } from '../../context/AuthContext';
import { maskPseudonym, maskPhone, maskReflection, maskIdentifier, isMaskedRole } from '../../lib/maskData';
import { ExplainableAIPanel } from '../guardian/ExplainableAI';

const INDIVIDUAL_DISTRESS_TIMELINE = [
  { date: 'Sep 05', moodScore: 4, distressIndex: 12 },
  { date: 'Sep 06', moodScore: 4, distressIndex: 15 },
  { date: 'Sep 07', moodScore: 3, distressIndex: 28 },
  { date: 'Sep 08', moodScore: 2, distressIndex: 55 },
  { date: 'Sep 09', moodScore: 1, distressIndex: 82 },
  { date: 'Sep 10', moodScore: 2, distressIndex: 68 },
  { date: 'Sep 11', moodScore: 3, distressIndex: 40 },
];

export const CaseView: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [liveMember, setLiveMember] = useState<any>(null);
  const [liveCheckins, setLiveCheckins] = useState<any[]>([]);
  const [liveScreeners, setLiveScreeners] = useState<any[]>([]);
  const [noteText, setNoteText] = useState('');
  const [notesLog, setNotesLog] = useState([
    {
      author: 'Officer Rajesh Singh',
      role: 'Caseworker & Guardian',
      text: 'Conducted 15-minute phone check-in. Ward reported feeling calmer after practicing grounding breath.',
      timestamp: '2026-09-11 11:30 AM',
    },
    {
      author: 'Dr. Ananya Sharma',
      role: 'Clinical Psychologist',
      text: 'Reviewed temporal AI prediction curve. Recommended continuing daily grounding check-ins.',
      timestamp: '2026-09-09 04:15 PM',
    },
  ]);

  useEffect(() => {
    if (!id) return;
    try {
      // 1. Live member doc listener
      const docRef = doc(db, 'members', id);
      const unsubDoc = onSnapshot(docRef, (snap) => {
        if (snap.exists()) {
          setLiveMember(snap.data());
        }
      });

      // 2. Live check-ins subcollection listener
      const checkinsRef = collection(db, 'members', id, 'checkins');
      const qCheckins = query(checkinsRef, orderBy('createdAt', 'desc'), limit(15));
      const unsubCheckins = onSnapshot(qCheckins, (snap) => {
        const list: any[] = [];
        snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
        setLiveCheckins(list);
      }, (e) => console.warn('Check-ins subcollection fallback:', e));

      // 3. Live screeners subcollection listener
      const screenersRef = collection(db, 'members', id, 'screeners');
      const qScreeners = query(screenersRef, orderBy('createdAt', 'desc'), limit(5));
      const unsubScreeners = onSnapshot(qScreeners, (snap) => {
        const list: any[] = [];
        snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
        setLiveScreeners(list);
      }, (e) => console.warn('Screeners subcollection fallback:', e));

      return () => {
        unsubDoc();
        unsubCheckins();
        unsubScreeners();
      };
    } catch (e) {
      console.warn('Firestore live listener in CaseView:', e);
    }
  }, [id]);

  const handleAddNote = (e: React.FormEvent) => {
    e.preventDefault();
    if (!noteText.trim()) return;

    setNotesLog(prev => [
      {
        author: 'Officer Rajesh Singh',
        role: 'Caseworker & Guardian',
        text: noteText.trim(),
        timestamp: new Date().toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }),
      },
      ...prev,
    ]);
    setNoteText('');
  };

  const getMoodBadge = (mood?: number) => {
    switch (mood) {
      case 5: return { label: 'Peaceful', color: 'bg-mool-moss/20 text-mool-moss-dark border-mool-moss/30' };
      case 4: return { label: 'Grounded', color: 'bg-mool-moss/10 text-mool-moss border-mool-moss/20' };
      case 3: return { label: 'Steady', color: 'bg-mool-mist text-mool-ink border-mool-mist' };
      case 2: return { label: 'Unsettled', color: 'bg-mool-sandrose/20 text-mool-sandrose border-mool-sandrose/30' };
      case 1: return { label: 'Heavy / Distressed', color: 'bg-mool-signal/15 text-mool-signal border-mool-signal/30' };
      default: return { label: 'Active', color: 'bg-mool-mist text-mool-ink-muted border-mool-mist' };
    }
  };

  const { role } = useAuth();
  const isSosActive = liveMember?.sosActive === true;
  const rawEmergencyPhone = liveMember?.emergencyContact || '+91 98765 43210';
  const emergencyPhone = maskPhone(rawEmergencyPhone, role);
  const wardName = maskPseudonym(liveMember?.displayName || 'Aarav (Ward)', id, role);
  const guardianName = isMaskedRole(role) ? 'Assigned Support Guardian' : (liveMember?.guardianName || 'Officer Rajesh Singh (Guardian)');
  const displayCaseId = maskIdentifier(id, role);

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Back Button */}
      <button
        onClick={() => navigate('/guardian')}
        className="inline-flex items-center space-x-1.5 text-xs font-semibold text-mool-moss hover:underline"
      >
        <ArrowLeft className="w-4 h-4" />
        <span>Return to Guardian Hub</span>
      </button>

      {/* Emergency SOS Banner (If Active) */}
      {isSosActive && (
        <div className="bg-mool-signal text-white p-4 sm:p-5 rounded-organic-lg shadow-lg flex items-center justify-between animate-pulse">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-full bg-white text-mool-signal flex items-center justify-center font-bold">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <div>
              <h2 className="font-serif text-lg font-bold">EMERGENCY SOS SIGNAL ACTIVE</h2>
              <p className="text-xs text-white/90">
                Triggered from ward phone • Reason: {liveMember?.lastSosReason || 'Urgent assistance requested'}
              </p>
            </div>
          </div>
          <a
            href={`tel:${emergencyPhone}`}
            className="px-4 py-2 bg-white text-mool-signal rounded-organic text-xs font-bold hover:bg-white/90 transition-colors flex items-center space-x-1.5 shadow"
          >
            <PhoneCall className="w-4 h-4" />
            <span>Call Ward Immediately</span>
          </a>
        </div>
      )}

      {/* Case Header */}
      <div className="bg-mool-dusk text-white p-6 rounded-organic-lg shadow-dusk-elevated flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div className="flex items-center space-x-4">
          <div className="w-14 h-14 rounded-full bg-mool-moss text-white flex items-center justify-center font-serif text-2xl font-bold">
            {wardName[0].toUpperCase()}
          </div>
          <div>
            <div className="flex items-center space-x-3">
              <h1 className="font-serif text-2xl font-bold text-mool-linen">
                {wardName}
              </h1>
              <span className={`text-xs px-2.5 py-0.5 rounded-full font-semibold ${
                liveMember?.latestTier === 'outreach' ? 'bg-mool-signal text-white' : 'bg-mool-moss text-white'
              }`}>
                {liveMember?.latestTier ? liveMember.latestTier.toUpperCase() : 'STABLE GROUNDING'}
              </span>
            </div>
            <p className="text-xs text-mool-linen/80 mt-1">
              Case ID: <span className="font-mono font-bold text-mool-sandrose">{displayCaseId}</span> • Guardian: {guardianName} • Consent: Granted
            </p>
            {liveMember?.linkedAt && (
              <p className="text-[11px] text-mool-linen/60 mt-0.5">
                Linked since: {new Date(liveMember.linkedAt).toLocaleDateString()}
              </p>
            )}
          </div>
        </div>

        <div className="flex items-center space-x-2">
          <a
            href={`tel:${emergencyPhone}`}
            className="px-4 py-2.5 bg-mool-sandrose text-white rounded-organic text-xs font-semibold hover:bg-mool-sandrose/90 transition-colors flex items-center space-x-1.5 shadow-sm"
          >
            <PhoneCall className="w-4 h-4" />
            <span>Call Contact ({emergencyPhone})</span>
          </a>
        </div>
      </div>

      {/* 4-Stat Metric Strip: Latest Self-Reported Metrics */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <GroundedCard variant="primary" elevation="ground" className="p-4 space-y-1">
          <div className="flex items-center space-x-2 text-xs text-mool-ink-muted">
            <Heart className="w-3.5 h-3.5 text-mool-moss" />
            <span>Latest Mood</span>
          </div>
          <div className="text-xl font-bold text-mool-ink">
            {liveMember?.latestMood ?? 4}<span className="text-xs text-mool-ink-muted font-normal"> / 5</span>
          </div>
          <p className="text-[11px] text-mool-moss font-medium">
            {getMoodBadge(liveMember?.latestMood).label}
          </p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="ground" className="p-4 space-y-1">
          <div className="flex items-center space-x-2 text-xs text-mool-ink-muted">
            <Moon className="w-3.5 h-3.5 text-mool-dusk" />
            <span>Sleep Quality</span>
          </div>
          <div className="text-xl font-bold text-mool-ink">
            {liveMember?.latestSleep ?? 3}<span className="text-xs text-mool-ink-muted font-normal"> / 5</span>
          </div>
          <p className="text-[11px] text-mool-ink-muted">
            {liveMember?.latestSleep && liveMember.latestSleep >= 4 ? 'Restful Sleep' : 'Moderate Rest'}
          </p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="ground" className="p-4 space-y-1">
          <div className="flex items-center space-x-2 text-xs text-mool-ink-muted">
            <Shield className="w-3.5 h-3.5 text-mool-moss" />
            <span>Safety Feeling</span>
          </div>
          <div className="text-xl font-bold text-mool-ink">
            {liveMember?.latestSafety ?? 4}<span className="text-xs text-mool-ink-muted font-normal"> / 5</span>
          </div>
          <p className="text-[11px] text-mool-moss font-medium">
            {liveMember?.latestSafety && liveMember.latestSafety >= 4 ? 'Secure Environment' : 'Needs Check-in'}
          </p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="ground" className="p-4 space-y-1">
          <div className="flex items-center space-x-2 text-xs text-mool-ink-muted">
            <Smile className="w-3.5 h-3.5 text-mool-sandrose" />
            <span>Coping Level</span>
          </div>
          <div className="text-xl font-bold text-mool-ink">
            {liveMember?.latestCoping ?? 4}<span className="text-xs text-mool-ink-muted font-normal"> / 5</span>
          </div>
          <p className="text-[11px] text-mool-ink-muted">
            {liveMember?.latestCoping && liveMember.latestCoping >= 4 ? 'Steady Coping' : 'Struggling'}
          </p>
        </GroundedCard>
      </div>

      {/* AI Explainability Panel for Responders */}
      {liveMember && (
        <ExplainableAIPanel
          ward={{
            id: id || '',
            displayName: wardName,
            latestScore: liveMember?.latestScore,
            latestTier: liveMember?.latestTier,
            latestMood: liveMember?.latestMood,
            latestSleep: liveMember?.latestSleep,
            latestSafety: liveMember?.latestSafety,
            latestCoping: liveMember?.latestCoping,
            latestNote: liveMember?.latestNote,
            latest: liveMember?.latest,
          }}
          checkins={liveCheckins}
          isExpanded={true}
        />
      )}

      {/* SC/ST (PoA) Act Judicial Milestones & Statutory Relief Card */}
      <GroundedCard variant="primary" elevation="ground" className="space-y-4 border-l-4 border-l-mool-dusk">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 border-b border-mool-mist/50 pb-3">
          <div className="flex items-center space-x-2.5">
            <div className="w-8 h-8 rounded-lg bg-mool-dusk/10 flex items-center justify-center text-mool-dusk">
              <Scale className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-serif text-base font-bold text-mool-ink">
                SC/ST (PoA) Act Judicial Milestones & Statutory Relief
              </h3>
              <p className="text-[11px] text-mool-ink-muted">
                Special Court Proceedings • Section 15A Witness Protection • Rule 12(4) DBT Relief
              </p>
            </div>
          </div>
          <span className="px-2.5 py-1 rounded text-xs font-bold bg-mool-signal/15 text-mool-signal border border-mool-signal/30 flex items-center space-x-1.5">
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>ACCUSED GRANTED BAIL (SEP 20, 2026)</span>
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
          <div className="p-3 bg-white border border-mool-mist rounded-organic space-y-1">
            <span className="text-[10px] font-bold text-mool-ink-muted uppercase tracking-wider block">Special Court & Stage</span>
            <p className="font-bold text-mool-ink text-sm">Special Court (SC/ST Act)</p>
            <p className="text-[11px] text-mool-dusk">Hearing: Sep 28, 2026 (PW-1 Examination)</p>
            <span className="inline-block mt-1 text-[10px] font-semibold text-mool-moss bg-mool-moss/10 px-2 py-0.5 rounded">
              FIR 142/2026 PS Gomti Nagar
            </span>
          </div>

          <div className="p-3 bg-white border border-mool-mist rounded-organic space-y-1">
            <span className="text-[10px] font-bold text-mool-ink-muted uppercase tracking-wider block">Section 15A Witness Protection</span>
            <p className="font-bold text-mool-sandrose text-sm">Application Pending</p>
            <p className="text-[11px] text-mool-ink-muted">Initiated via Witness Protection Scheme, 2018</p>
            <span className="inline-block mt-1 text-[10px] font-semibold text-mool-signal bg-mool-signal/10 px-2 py-0.5 rounded">
              48h Intimidation Window Active
            </span>
          </div>

          <div className="p-3 bg-white border border-mool-mist rounded-organic space-y-1">
            <span className="text-[10px] font-bold text-mool-ink-muted uppercase tracking-wider block">Statutory Compensation (Rule 12(4))</span>
            <p className="font-bold text-mool-ink text-sm">₹1,06,250 Paid • ₹2,12,500 Overdue</p>
            <p className="text-[11px] text-mool-signal font-semibold">Chargesheet Stage Overdue by 14 Days</p>
            <span className="inline-block mt-1 text-[10px] font-semibold text-mool-dusk bg-mool-dusk/10 px-2 py-0.5 rounded">
              DSWO Followup Required
            </span>
          </div>
        </div>
      </GroundedCard>

      {/* Grid Content */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* 2-Column Distress Timeline Chart & Check-ins */}
        <div className="lg:col-span-2 space-y-6">
          <GroundedCard variant="primary" elevation="ground" className="space-y-4">
            <div className="flex justify-between items-center">
              <div>
                <h3 className="font-serif text-lg font-bold text-mool-ink">Distress Risk Timeline</h3>
                <p className="text-xs text-mool-ink-muted">Predicted distress vs. daily phone self-ratings</p>
              </div>
              <span className="text-xs text-mool-signal font-semibold bg-mool-signal/15 px-2.5 py-1 rounded-full flex items-center space-x-1.5">
                <Activity className="w-3.5 h-3.5" />
                <span>Distress Engine: Active</span>
              </span>
            </div>

            <div className="h-60 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={INDIVIDUAL_DISTRESS_TIMELINE} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorDistressInd" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#B3543F" stopOpacity={0.4}/>
                      <stop offset="95%" stopColor="#B3543F" stopOpacity={0.0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E4E0D5" vertical={false} />
                  <XAxis dataKey="date" stroke="#595952" fontSize={12} />
                  <YAxis stroke="#595952" fontSize={12} domain={[0, 100]} />
                  <Tooltip contentStyle={{ backgroundColor: '#F6F3EC', borderRadius: '10px', fontSize: '12px' }} />
                  <Area type="monotone" dataKey="distressIndex" stroke="#B3543F" strokeWidth={2.5} fillOpacity={1} fill="url(#colorDistressInd)" name="Distress Index" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </GroundedCard>

          {/* Self-Reported Check-ins & Shared Reflections (Live Stream from Phone) */}
          <GroundedCard variant="primary" elevation="ground" className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-serif text-base font-bold text-mool-ink flex items-center space-x-2">
                <Calendar className="w-4 h-4 text-mool-moss" />
                <span>Ward Check-In History & Reflection Notes</span>
              </h3>
              <span className="text-[11px] font-semibold text-mool-moss bg-mool-moss/10 px-2.5 py-0.5 rounded-full">
                Real-Time Firestore Sync
              </span>
            </div>
            
            <div className="space-y-2.5">
              {/* If member has latest note from phone */}
              {liveMember?.latestNote && (
                <div className="p-4 bg-mool-moss/10 border-2 border-mool-moss/30 rounded-organic space-y-2">
                  <div className="flex justify-between items-center text-xs font-semibold text-mool-ink">
                    <span className="flex items-center space-x-1.5">
                      <Clock className="w-3.5 h-3.5 text-mool-moss" />
                      <span>{liveMember.lastCheckInAt ? new Date(liveMember.lastCheckInAt).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : 'Today (Live Sync)'}</span>
                    </span>
                    <span className="text-mool-moss font-bold bg-white px-2 py-0.5 rounded-full border border-mool-moss/30">
                      Mood: {liveMember.latestMood ?? 4}/5 • {getMoodBadge(liveMember.latestMood).label}
                    </span>
                  </div>
                  <div className="bg-white/80 p-3 rounded-lg border border-mool-mist">
                    <span className="text-[10px] font-bold text-mool-moss uppercase tracking-wider block mb-1">
                      Reflection Note:
                    </span>
                    <p className="text-xs text-mool-ink italic leading-relaxed">
                      "{liveMember.latestNote}"
                    </p>
                  </div>
                </div>
              )}

              {/* Subcollection check-ins */}
              {liveCheckins.length > 0 ? (
                liveCheckins.map((chk) => (
                  <div key={chk.id} className="p-3 bg-mool-linen border border-mool-mist rounded-organic space-y-1.5">
                    <div className="flex justify-between text-xs font-semibold text-mool-ink">
                      <span className="flex items-center space-x-1.5">
                        <Calendar className="w-3.5 h-3.5 text-mool-moss" />
                        <span>{chk.at ? new Date(chk.at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : 'Recorded'}</span>
                      </span>
                      <span className="text-mool-moss font-bold">Rating: {chk.mood || 3}/5</span>
                    </div>
                    {chk.note && <p className="text-xs text-mool-ink-muted italic">"{maskReflection(chk.note, role)}"</p>}
                  </div>
                ))
              ) : (
                <>
                  <div className="p-3 bg-mool-linen border border-mool-mist rounded-organic space-y-1">
                    <div className="flex justify-between text-xs font-semibold text-mool-ink">
                      <span className="flex items-center space-x-1.5">
                        <Calendar className="w-3.5 h-3.5 text-mool-moss" />
                        <span>Sep 11, 2026 • 09:30 AM</span>
                      </span>
                      <span className="text-mool-moss font-bold">Grounding Rating: 3/5</span>
                    </div>
                    <p className="text-xs text-mool-ink-muted">"{maskReflection("Felt steady after deep breathing. Went for a short walk.", role)}"</p>
                  </div>

                  <div className="p-3 bg-mool-linen border border-mool-mist rounded-organic space-y-1">
                    <div className="flex justify-between text-xs font-semibold text-mool-ink">
                      <span className="flex items-center space-x-1.5">
                        <Calendar className="w-3.5 h-3.5 text-mool-moss" />
                        <span>Sep 09, 2026 • 08:15 PM</span>
                      </span>
                      <span className="text-mool-signal font-bold">Grounding Rating: 1/5</span>
                    </div>
                    <p className="text-xs text-mool-ink-muted">"{maskReflection("Intrusive flashbacks in the evening.", role)}"</p>
                  </div>
                </>
              )}
            </div>
          </GroundedCard>
        </div>

        {/* 1-Column Right Sidebar: Clinical Screeners & Caseworker Log */}
        <div className="space-y-6">
          {/* Clinical Screeners Card */}
          <GroundedCard variant="primary" elevation="ground" className="p-5 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-serif text-base font-bold text-mool-ink flex items-center space-x-2">
                <CheckCircle2 className="w-4 h-4 text-mool-moss" />
                <span>Clinical Screeners</span>
              </h3>
              <span className="text-[10px] bg-mool-moss/10 text-mool-moss px-2 py-0.5 rounded-full font-bold uppercase">
                PHQ / GAD / PTSD
              </span>
            </div>

            <div className="space-y-2.5">
              {liveMember?.latestScreenerScore != null ? (
                <div className="p-3 bg-mool-mist/40 border border-mool-mist rounded-organic space-y-1">
                  <div className="flex justify-between items-center text-xs font-bold text-mool-ink">
                    <span className="uppercase">{liveMember.latestScreenerId || 'PHQ-9'} Screener</span>
                    <span className="bg-mool-moss text-white px-2 py-0.5 rounded text-[10px]">
                      {liveMember.latestScreenerSeverity || 'Moderate'}
                    </span>
                  </div>
                  <p className="text-xs text-mool-ink-muted">
                    Total Score: <span className="font-bold text-mool-ink">{liveMember.latestScreenerScore}</span>
                  </p>
                  <p className="text-[10px] text-mool-ink-faint">
                    Completed: {liveMember.latestScreenerAt ? new Date(liveMember.latestScreenerAt).toLocaleDateString() : 'Recent'}
                  </p>
                </div>
              ) : (
                <div className="p-3 bg-mool-mist/30 border border-mool-mist rounded-organic space-y-1">
                  <div className="flex justify-between items-center text-xs font-bold text-mool-ink">
                    <span>PHQ-9 (Depression Screener)</span>
                    <span className="bg-mool-moss text-white px-2 py-0.5 rounded text-[10px]">Stable (4/27)</span>
                  </div>
                  <p className="text-[11px] text-mool-ink-muted">Minimal depressive indicators reported.</p>
                </div>
              )}

              <div className="p-3 bg-mool-mist/30 border border-mool-mist rounded-organic space-y-1">
                <div className="flex justify-between items-center text-xs font-bold text-mool-ink">
                  <span>GAD-7 (Anxiety Screener)</span>
                  <span className="bg-mool-sandrose text-white px-2 py-0.5 rounded text-[10px]">Mild (6/21)</span>
                </div>
                <p className="text-[11px] text-mool-ink-muted">Mild anxiety around court hearing dates.</p>
              </div>
            </div>
          </GroundedCard>

          {/* Trusted People Network */}
          {liveMember?.trustedContacts && liveMember.trustedContacts.length > 0 && (
            <GroundedCard variant="primary" elevation="ground" className="p-5 space-y-3">
              <h3 className="font-serif text-base font-bold text-mool-ink flex items-center space-x-2">
                <Users className="w-4 h-4 text-mool-moss" />
                <span>Ward's Trusted People ({liveMember.trustedContacts.length})</span>
              </h3>
              <div className="space-y-2">
                {liveMember.trustedContacts.map((c: any, i: number) => (
                  <div key={i} className="flex justify-between items-center p-2.5 bg-mool-linen rounded-lg border border-mool-mist text-xs">
                    <div>
                      <span className="font-bold text-mool-ink block">{c.name}</span>
                      <span className="text-[11px] text-mool-ink-muted font-mono">{c.phone}</span>
                    </div>
                    <a href={`tel:${c.phone}`} className="p-1.5 bg-white border border-mool-mist rounded text-mool-moss hover:bg-mool-moss/10">
                      <PhoneCall className="w-3.5 h-3.5" />
                    </a>
                  </div>
                ))}
              </div>
            </GroundedCard>
          )}

          {/* Responder Intervention Notes Log */}
          <GroundedCard variant="primary" elevation="ground" className="p-5 space-y-4">
            <h3 className="font-serif text-base font-bold text-mool-ink flex items-center space-x-2">
              <FileText className="w-4 h-4 text-mool-moss" />
              <span>Guardian Log & Notes</span>
            </h3>

            <form onSubmit={handleAddNote} className="space-y-2">
              <textarea
                rows={3}
                value={noteText}
                onChange={(e) => setNoteText(e.target.value)}
                placeholder="Log guardian intervention or observation..."
                className="w-full p-3 bg-white border border-mool-mist rounded-organic text-xs text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss resize-none"
              />
              <OrganicButton type="submit" variant="moss" fullWidth size="sm">
                <Send className="w-3.5 h-3.5 mr-1.5" />
                <span>Add Note</span>
              </OrganicButton>
            </form>

            <div className="space-y-3 pt-2 border-t border-mool-mist">
              {notesLog.map((n, idx) => (
                <div key={idx} className="p-3 bg-mool-mist/30 rounded-organic space-y-1">
                  <div className="flex justify-between items-center text-xs">
                    <span className="font-bold text-mool-ink">{n.author}</span>
                    <span className="text-[10px] text-mool-ink-faint">{n.timestamp}</span>
                  </div>
                  <span className="text-[10px] text-mool-moss font-semibold uppercase block">{n.role}</span>
                  <p className="text-xs text-mool-ink-muted leading-relaxed mt-1">{n.text}</p>
                </div>
              ))}
            </div>
          </GroundedCard>
        </div>
      </div>
    </div>
  );
};

