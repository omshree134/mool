import React, { useState } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { Users, AlertTriangle, ShieldCheck, Activity, MapPin, Filter } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { TopographyDivider } from '../common/TopographyDivider';

const AGGREGATE_TREND_DATA = [
  { day: 'Mon', averageGrounding: 3.8, flaggedDistressCount: 4, checkinVolume: 120 },
  { day: 'Tue', averageGrounding: 3.6, flaggedDistressCount: 6, checkinVolume: 135 },
  { day: 'Wed', averageGrounding: 3.2, flaggedDistressCount: 11, checkinVolume: 142 },
  { day: 'Thu', averageGrounding: 2.9, flaggedDistressCount: 18, checkinVolume: 160 },
  { day: 'Fri', averageGrounding: 3.4, flaggedDistressCount: 9, checkinVolume: 155 },
  { day: 'Sat', averageGrounding: 3.9, flaggedDistressCount: 5, checkinVolume: 148 },
  { day: 'Sun', averageGrounding: 4.1, flaggedDistressCount: 3, checkinVolume: 150 },
];

const REGIONAL_BREAKDOWN = [
  { region: 'District A (East)', beneficiaries: 142, highRisk: 6, status: 'Stable' },
  { region: 'District B (Valley)', beneficiaries: 98, highRisk: 14, status: 'Elevated' },
  { region: 'District C (North)', beneficiaries: 215, highRisk: 4, status: 'Stable' },
  { region: 'District D (Border)', beneficiaries: 85, highRisk: 12, status: 'Elevated' },
];

export const AggregateDashboard: React.FC = () => {
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d'>('7d');

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Top Banner */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-mool-dusk text-white p-6 rounded-organic-lg shadow-dusk-elevated">
        <div className="space-y-1">
          <div className="inline-flex items-center space-x-2 px-2.5 py-0.5 bg-mool-moss text-white rounded-full text-xs font-semibold">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Population Wellbeing Overview</span>
          </div>
          <h1 className="font-serif text-2xl sm:text-3xl font-bold tracking-tight text-mool-linen">
            Aggregate Distress & Grounding Metrics
          </h1>
          <p className="text-xs text-mool-linen/80">
            Anonymized population trends for caseworkers and policy coordinators.
          </p>
        </div>

        <div className="flex items-center space-x-2 bg-mool-dusk-dark p-1.5 rounded-organic border border-mool-dusk-light">
          <Filter className="w-3.5 h-3.5 text-mool-sandrose ml-2" />
          {(['7d', '30d', '90d'] as const).map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-3 py-1 text-xs font-medium rounded-md transition-colors ${
                timeRange === range
                  ? 'bg-mool-moss text-white font-semibold'
                  : 'text-mool-linen/70 hover:text-white'
              }`}
            >
              {range.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* 4 Summary Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <GroundedCard variant="primary" elevation="ground" className="space-y-2">
          <div className="flex items-center justify-between text-mool-ink-muted">
            <span className="text-xs font-semibold uppercase tracking-wider">Total Monitored</span>
            <Users className="w-4 h-4 text-mool-moss" />
          </div>
          <p className="font-serif text-3xl font-bold text-mool-ink">540</p>
          <p className="text-[11px] text-mool-moss font-medium">89.4% Active weekly check-ins</p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="ground" className="space-y-2">
          <div className="flex items-center justify-between text-mool-ink-muted">
            <span className="text-xs font-semibold uppercase tracking-wider">Avg Population Grounding</span>
            <Activity className="w-4 h-4 text-mool-moss" />
          </div>
          <p className="font-serif text-3xl font-bold text-mool-ink">3.57 / 5</p>
          <p className="text-[11px] text-mool-moss font-medium">+0.3 shift over last 14 days</p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="ground" className="space-y-2">
          <div className="flex items-center justify-between text-mool-ink-muted">
            <span className="text-xs font-semibold uppercase tracking-wider">Open AI Distress Flags</span>
            <AlertTriangle className="w-4 h-4 text-mool-signal" />
          </div>
          <p className="font-serif text-3xl font-bold text-mool-signal">7</p>
          <p className="text-[11px] text-mool-signal font-medium">3 Critical, 4 High priority</p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="ground" className="space-y-2">
          <div className="flex items-center justify-between text-mool-ink-muted">
            <span className="text-xs font-semibold uppercase tracking-wider">Active Responders</span>
            <ShieldCheck className="w-4 h-4 text-mool-dusk" />
          </div>
          <p className="font-serif text-3xl font-bold text-mool-ink">18</p>
          <p className="text-[11px] text-mool-ink-muted font-medium">Caseworkers & NGO partners</p>
        </GroundedCard>
      </div>

      {/* Main Population Grounding Trend Chart (Recharts with muted palette) */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <GroundedCard variant="primary" elevation="ground" className="lg:col-span-2 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-serif text-lg font-bold text-mool-ink">Population Grounding Score vs. Distress Flags</h3>
              <p className="text-xs text-mool-ink-muted">7-day aggregated temporal trend curve</p>
            </div>
            <div className="flex items-center space-x-4 text-xs">
              <span className="flex items-center space-x-1.5 font-medium text-mool-moss">
                <span className="w-3 h-3 rounded-full bg-mool-moss inline-block" />
                <span>Grounding Level (1-5)</span>
              </span>
              <span className="flex items-center space-x-1.5 font-medium text-mool-signal">
                <span className="w-3 h-3 rounded-full bg-mool-signal inline-block" />
                <span>Distress Flags</span>
              </span>
            </div>
          </div>

          <div className="h-72 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={AGGREGATE_TREND_DATA} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorGrounding" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#5F7A5E" stopOpacity={0.4}/>
                    <stop offset="95%" stopColor="#5F7A5E" stopOpacity={0.0}/>
                  </linearGradient>
                  <linearGradient id="colorDistress" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#B3543F" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#B3543F" stopOpacity={0.0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#E4E0D5" vertical={false} />
                <XAxis dataKey="day" stroke="#595952" fontSize={12} tickLine={false} />
                <YAxis stroke="#595952" fontSize={12} tickLine={false} domain={[0, 20]} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#F6F3EC', borderRadius: '12px', border: '1px solid #E4E0D5', fontSize: '12px' }}
                />
                <Area type="monotone" dataKey="averageGrounding" stroke="#5F7A5E" strokeWidth={2.5} fillOpacity={1} fill="url(#colorGrounding)" name="Avg Grounding" />
                <Area type="monotone" dataKey="flaggedDistressCount" stroke="#B3543F" strokeWidth={2} fillOpacity={1} fill="url(#colorDistress)" name="Distress Events" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </GroundedCard>

        {/* Regional Breakdown Card */}
        <GroundedCard variant="primary" elevation="ground" className="space-y-4">
          <div className="flex items-center space-x-2">
            <MapPin className="w-5 h-5 text-mool-dusk" />
            <h3 className="font-serif text-lg font-bold text-mool-ink">Regional Distribution</h3>
          </div>

          <div className="space-y-3">
            {REGIONAL_BREAKDOWN.map((reg, idx) => (
              <div key={idx} className="p-3 bg-mool-linen border border-mool-mist rounded-organic space-y-1.5">
                <div className="flex justify-between items-center text-xs font-semibold text-mool-ink">
                  <span>{reg.region}</span>
                  <span className={`px-2 py-0.5 rounded-full text-[10px] ${
                    reg.status === 'Elevated' ? 'bg-mool-signal/15 text-mool-signal' : 'bg-mool-moss/15 text-mool-moss'
                  }`}>
                    {reg.status}
                  </span>
                </div>
                <div className="flex justify-between text-[11px] text-mool-ink-muted">
                  <span>{reg.beneficiaries} Beneficiaries</span>
                  <span className="text-mool-signal font-medium">{reg.highRisk} High-risk alerts</span>
                </div>
              </div>
            ))}
          </div>
        </GroundedCard>
      </div>
    </div>
  );
};

