import React, { useState, useEffect } from 'react';
import {
  Brain,
  TrendingUp,
  TrendingDown,
  Minus,
  AlertTriangle,
  ShieldCheck,
  Activity,
  Heart,
  Moon,
  Shield,
  Smile,
  Lightbulb,
  Lock,
  RefreshCw,
  ChevronDown,
  ChevronUp,
  Zap,
  Gavel,
  Phone,
  Home,
  Wallet,
  Stethoscope,
  BookOpen,
  Eye,
  Sparkles,
} from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { getExplainableInsights, ExplainableInsight, DistressPrediction } from '../../services/aiService';

interface ExplainableAIPanelProps {
  ward: {
    id: string;
    displayName?: string;
    latestScore?: number;
    latestTier?: string;
    latestMood?: number;
    latestSleep?: number;
    latestSafety?: number;
    latestCoping?: number;
    latestNote?: string;
    latest?: {
      tier?: string;
      score?: number;
      confidence?: number;
      dateKey?: string;
    };
  };
  checkins?: any[];
  isExpanded?: boolean;
}

const TIER_CONFIG: Record<string, { label: string; color: string; bgColor: string; borderColor: string; icon: React.ReactNode }> = {
  crisis: {
    label: 'Crisis — Contact Now',
    color: 'text-white',
    bgColor: 'bg-mool-signal',
    borderColor: 'border-mool-signal',
    icon: <AlertTriangle className="w-4 h-4" />,
  },
  urgent: {
    label: 'Urgent — Reach out within 4 hours',
    color: 'text-white',
    bgColor: 'bg-mool-signal',
    borderColor: 'border-mool-signal/50',
    icon: <AlertTriangle className="w-4 h-4" />,
  },
  outreach: {
    label: 'Outreach — Reach out within 24 hours',
    color: 'text-white',
    bgColor: 'bg-mool-sandrose',
    borderColor: 'border-mool-sandrose/50',
    icon: <Phone className="w-4 h-4" />,
  },
  watch: {
    label: 'Watch — Keep an eye on',
    color: 'text-white',
    bgColor: 'bg-mool-dusk',
    borderColor: 'border-mool-dusk/50',
    icon: <Eye className="w-4 h-4" />,
  },
  stable: {
    label: 'Stable — Grounded',
    color: 'text-white',
    bgColor: 'bg-mool-moss',
    borderColor: 'border-mool-moss/50',
    icon: <ShieldCheck className="w-4 h-4" />,
  },
  insufficientData: {
    label: 'Not Enough Data',
    color: 'text-mool-ink-muted',
    bgColor: 'bg-mool-mist',
    borderColor: 'border-mool-mist',
    icon: <Minus className="w-4 h-4" />,
  },
};

const INTERVENTION_ICONS: Record<string, React.ReactNode> = {
  counselling: <Stethoscope className="w-3.5 h-3.5" />,
  medical: <Heart className="w-3.5 h-3.5" />,
  legal: <Gavel className="w-3.5 h-3.5" />,
  witness_protection: <Shield className="w-3.5 h-3.5" />,
  financial: <Wallet className="w-3.5 h-3.5" />,
  rehabilitation: <Home className="w-3.5 h-3.5" />,
};

const PRIORITY_COLORS: Record<string, string> = {
  immediate: 'bg-mool-signal/15 text-mool-signal border-mool-signal/30',
  soon: 'bg-mool-sandrose/15 text-mool-sandrose border-mool-sandrose/30',
  routine: 'bg-mool-moss/10 text-mool-moss border-mool-moss/20',
};

export const ExplainableAIPanel: React.FC<ExplainableAIPanelProps> = ({ ward, checkins, isExpanded: defaultExpanded }) => {
  const [expanded, setExpanded] = useState(defaultExpanded ?? false);
  const [loading, setLoading] = useState(false);
  const [insights, setInsights] = useState<{
    summary: string;
    topFactors: ExplainableInsight[];
    prediction: DistressPrediction;
    interventions: { type: string; priority: string; reason: string }[];
    alertLevel: string;
  } | null>(null);

  const tier = (ward.latestTier || ward.latest?.tier || 'stable').toLowerCase();
  const score = ward.latestScore ?? ward.latest?.score ?? 0;
  const confidence = ward.latest?.confidence ?? 0;
  const tierConfig = TIER_CONFIG[tier] || TIER_CONFIG.stable;

  const [decisions, setDecisions] = useState<Record<number, 'accepted' | 'rejected' | 'done'>>({});

  const handleDecision = async (idx: number, decision: 'accepted' | 'rejected' | 'done', intervention: any) => {
    setDecisions(prev => ({ ...prev, [idx]: decision }));
    try {
      const apiBase = import.meta.env.VITE_MOOL_API_URL || 'https://mool-worker.omshreechoudhary7.workers.dev';
      await fetch(`${apiBase}/recommendations/rec_${idx}/decision`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          decision,
          note: `Caseworker marked as ${decision}: ${intervention.type}`,
        }),
      });
    } catch {
      // Optimistic UI state already updated
    }
  };

  const loadInsights = async () => {
    setLoading(true);
    try {
      const result = await getExplainableInsights({
        displayName: ward.displayName,
        latestScore: score,
        latestTier: tier,
        latestMood: ward.latestMood,
        latestSleep: ward.latestSleep,
        latestSafety: ward.latestSafety,
        latestCoping: ward.latestCoping,
        latestNote: ward.latestNote,
        recentCheckins: checkins,
        confidence,
      });
      setInsights(result);
    } catch (err) {
      console.warn('Failed to load AI insights:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (expanded && !insights && !loading) {
      loadInsights();
    }
  }, [expanded]);

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'critical': return 'bg-mool-signal text-white';
      case 'high': return 'bg-mool-sandrose/20 text-mool-sandrose';
      case 'moderate': return 'bg-mool-dusk/10 text-mool-dusk';
      case 'low': return 'bg-mool-moss/10 text-mool-moss';
      default: return 'bg-mool-mist text-mool-ink-muted';
    }
  };

  const getTrendIcon = (trend: string) => {
    switch (trend) {
      case 'rising': return <TrendingUp className="w-3 h-3 text-mool-signal" />;
      case 'falling': return <TrendingDown className="w-3 h-3 text-mool-moss" />;
      default: return <Minus className="w-3 h-3 text-mool-ink-muted" />;
    }
  };

  return (
    <GroundedCard variant="primary" elevation="ground" className="overflow-hidden">
      {/* Collapsed Header — always visible */}
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full px-4 py-3 flex items-center justify-between hover:bg-mool-mist/30 transition-colors"
      >
        <div className="flex items-center space-x-3">
          <div className="w-8 h-8 rounded-lg bg-mool-dusk/10 flex items-center justify-center">
            <Brain className="w-4 h-4 text-mool-dusk" />
          </div>
          <div className="text-left">
            <div className="flex items-center space-x-2">
              <h3 className="text-xs font-bold text-mool-ink">AI Explainability Panel</h3>
              <span className="text-[9px] bg-mool-dusk/10 text-mool-dusk px-1.5 py-0.5 rounded-full font-semibold">
                Groq AI
              </span>
            </div>
            <p className="text-[10px] text-mool-ink-muted">Why this score? What should you do?</p>
          </div>
        </div>

        <div className="flex items-center space-x-2">
          {/* Mini score badge */}
          <div className={`px-2 py-1 rounded-md text-[10px] font-bold ${tierConfig.bgColor} ${tierConfig.color}`}>
            {score > 0 ? score.toFixed(0) : '—'}
          </div>
          {expanded ? <ChevronUp className="w-4 h-4 text-mool-ink-muted" /> : <ChevronDown className="w-4 h-4 text-mool-ink-muted" />}
        </div>
      </button>

      {/* Expanded Content */}
      {expanded && (
        <div className="px-4 pb-4 space-y-4 border-t border-mool-mist animate-in slide-in-from-top-2 duration-200">
          {loading ? (
            <div className="py-8 flex flex-col items-center space-y-2">
              <RefreshCw className="w-6 h-6 text-mool-dusk animate-spin" />
              <p className="text-xs text-mool-ink-muted">Analyzing with Groq AI (llama-3.3-70b)...</p>
            </div>
          ) : insights ? (
            <>
              {/* 1. Score Decomposition */}
              <div className="pt-3 space-y-3">
                {/* Tier Badge */}
                <div className={`flex items-center space-x-2 px-3 py-2 rounded-lg border ${tierConfig.borderColor} ${tierConfig.bgColor}`}>
                  {tierConfig.icon}
                  <span className={`text-xs font-bold ${tierConfig.color}`}>{tierConfig.label}</span>
                  <span className="ml-auto text-[10px] opacity-80 font-medium">{tierConfig.color.includes('white') ? `Score: ${score.toFixed(0)}/100` : ''}</span>
                </div>

                {/* Confidence Bar */}
                <div className="flex items-center space-x-2">
                  <span className="text-[10px] text-mool-ink-muted font-semibold w-24">AI Confidence:</span>
                  <div className="flex-1 h-2 bg-mool-mist rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all duration-500 ${
                        confidence >= 0.7 ? 'bg-mool-moss' : confidence >= 0.4 ? 'bg-mool-sandrose' : 'bg-mool-ink-muted'
                      }`}
                      style={{ width: `${(confidence * 100).toFixed(0)}%` }}
                    />
                  </div>
                  <span className="text-[10px] font-bold text-mool-ink">{(confidence * 100).toFixed(0)}%</span>
                </div>
              </div>

              {/* 2. AI Summary */}
              <div className="bg-mool-dusk/5 border border-mool-dusk/15 rounded-lg p-3">
                <div className="flex items-start space-x-2">
                  <Sparkles className="w-3.5 h-3.5 text-mool-dusk mt-0.5 shrink-0" />
                  <p className="text-xs text-mool-ink leading-relaxed">{insights.summary}</p>
                </div>
              </div>

              {/* 3. Factor Breakdown — "Why this score?" */}
              {insights.topFactors.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-[11px] font-bold text-mool-ink uppercase tracking-wider flex items-center space-x-1.5">
                    <Activity className="w-3.5 h-3.5 text-mool-dusk" />
                    <span>Contributing Factors</span>
                  </h4>

                  {insights.topFactors.map((factor, i) => (
                    <div key={i} className="bg-white border border-mool-mist rounded-lg p-2.5 space-y-1.5">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded ${getSeverityColor(factor.severity)}`}>
                            {factor.severity.toUpperCase()}
                          </span>
                          <span className="text-[11px] font-semibold text-mool-ink">{factor.factorName}</span>
                        </div>
                        <div className="flex items-center space-x-1.5">
                          {getTrendIcon(factor.trend)}
                          <span className="text-[10px] font-bold text-mool-dusk">{factor.contribution}%</span>
                        </div>
                      </div>

                      {/* Contribution bar */}
                      <div className="h-1.5 bg-mool-mist/50 rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all duration-700 ${
                            factor.severity === 'critical' ? 'bg-mool-signal' :
                            factor.severity === 'high' ? 'bg-mool-sandrose' :
                            factor.severity === 'moderate' ? 'bg-mool-dusk' : 'bg-mool-moss'
                          }`}
                          style={{ width: `${factor.contribution}%` }}
                        />
                      </div>

                      <p className="text-[10px] text-mool-ink-muted leading-relaxed">{factor.explanation}</p>
                    </div>
                  ))}
                </div>
              )}

              {/* 4. Predicted Trajectory */}
              <div className="space-y-2">
                <h4 className="text-[11px] font-bold text-mool-ink uppercase tracking-wider flex items-center space-x-1.5">
                  <TrendingUp className="w-3.5 h-3.5 text-mool-dusk" />
                  <span>Predicted Trajectory (7 Days)</span>
                </h4>

                <div className={`rounded-lg p-3 border ${
                  insights.prediction.predictedTier === 'worsening' || insights.prediction.predictedTier === 'critical'
                    ? 'bg-mool-signal/5 border-mool-signal/20'
                    : insights.prediction.predictedTier === 'improving'
                      ? 'bg-mool-moss/5 border-mool-moss/20'
                      : 'bg-mool-mist/30 border-mool-mist'
                }`}>
                  <div className="flex items-center justify-between mb-2">
                    <span className={`text-xs font-bold ${
                      insights.prediction.predictedTier === 'worsening' ? 'text-mool-signal' :
                      insights.prediction.predictedTier === 'improving' ? 'text-mool-moss' : 'text-mool-ink'
                    }`}>
                      {insights.prediction.predictedTier === 'worsening' ? '⚠️ Predicted to worsen' :
                       insights.prediction.predictedTier === 'improving' ? '✨ Predicted to improve' :
                       insights.prediction.predictedTier === 'critical' ? '🚨 Critical trajectory' :
                       '→ Expected to remain stable'}
                    </span>
                    <span className="text-[10px] text-mool-ink-muted">
                      {(insights.prediction.confidence * 100).toFixed(0)}% confidence
                    </span>
                  </div>
                  <p className="text-[10px] text-mool-ink-muted leading-relaxed">{insights.prediction.reasoning}</p>
                </div>
              </div>

              {/* 5. Recommended Interventions */}
              {insights.interventions.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-[11px] font-bold text-mool-ink uppercase tracking-wider flex items-center space-x-1.5">
                    <Lightbulb className="w-3.5 h-3.5 text-mool-sandrose" />
                    <span>Recommended Interventions</span>
                  </h4>

                  {insights.interventions.map((intervention, i) => {
                    const currentDecision = decisions[i];
                    return (
                      <div key={i} className={`flex flex-col sm:flex-row sm:items-center justify-between p-3 rounded-lg border gap-2.5 ${PRIORITY_COLORS[intervention.priority] || PRIORITY_COLORS.routine}`}>
                        <div className="flex items-start space-x-2.5 flex-1">
                          <div className="mt-0.5">
                            {INTERVENTION_ICONS[intervention.type] || <Zap className="w-3.5 h-3.5" />}
                          </div>
                          <div>
                            <div className="flex items-center space-x-2">
                              <span className="text-[11px] font-bold capitalize">{intervention.type.replace('_', ' ')}</span>
                              <span className="text-[9px] font-bold uppercase tracking-wider opacity-70">
                                {intervention.priority}
                              </span>
                              {currentDecision && (
                                <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded uppercase ${
                                  currentDecision === 'accepted' ? 'bg-mool-moss text-white' :
                                  currentDecision === 'done' ? 'bg-mool-dusk text-white' : 'bg-mool-signal text-white'
                                }`}>
                                  {currentDecision}
                                </span>
                              )}
                            </div>
                            <p className="text-[10px] opacity-80 mt-0.5">{intervention.reason}</p>
                          </div>
                        </div>

                        {/* Human-in-the-Loop Action Buttons */}
                        <div className="flex items-center space-x-1.5 self-end sm:self-center shrink-0">
                          <button
                            onClick={() => handleDecision(i, 'accepted', intervention)}
                            className={`px-2.5 py-1 rounded text-[10px] font-bold transition-colors ${
                              currentDecision === 'accepted'
                                ? 'bg-mool-moss text-white shadow-sm'
                                : 'bg-white/80 hover:bg-mool-moss hover:text-white text-mool-ink border border-black/10'
                            }`}
                          >
                            Accept
                          </button>
                          <button
                            onClick={() => handleDecision(i, 'done', intervention)}
                            className={`px-2.5 py-1 rounded text-[10px] font-bold transition-colors ${
                              currentDecision === 'done'
                                ? 'bg-mool-dusk text-white shadow-sm'
                                : 'bg-white/80 hover:bg-mool-dusk hover:text-white text-mool-ink border border-black/10'
                            }`}
                          >
                            Done
                          </button>
                          <button
                            onClick={() => handleDecision(i, 'rejected', intervention)}
                            className={`px-2.5 py-1 rounded text-[10px] font-bold transition-colors ${
                              currentDecision === 'rejected'
                                ? 'bg-mool-signal text-white shadow-sm'
                                : 'bg-white/80 hover:bg-mool-signal hover:text-white text-mool-ink border border-black/10'
                            }`}
                          >
                            Reject
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* 6. Check-in Component Breakdown */}
              <div className="space-y-2">
                <h4 className="text-[11px] font-bold text-mool-ink uppercase tracking-wider">Latest Check-in Breakdown</h4>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { label: 'Mood', value: ward.latestMood, icon: <Smile className="w-3.5 h-3.5" />, weight: '60%' },
                    { label: 'Sleep', value: ward.latestSleep, icon: <Moon className="w-3.5 h-3.5" />, weight: '60%' },
                    { label: 'Safety', value: ward.latestSafety, icon: <Shield className="w-3.5 h-3.5" />, weight: '60%' },
                    { label: 'Coping', value: ward.latestCoping, icon: <Heart className="w-3.5 h-3.5" />, weight: '60%' },
                  ].map((item, i) => (
                    <div key={i} className="bg-white border border-mool-mist rounded-lg p-2 flex items-center space-x-2">
                      <div className={`w-7 h-7 rounded-md flex items-center justify-center ${
                        item.value == null ? 'bg-mool-mist text-mool-ink-muted' :
                        item.value >= 4 ? 'bg-mool-moss/15 text-mool-moss' :
                        item.value >= 3 ? 'bg-mool-mist text-mool-ink' :
                        item.value >= 2 ? 'bg-mool-sandrose/15 text-mool-sandrose' :
                        'bg-mool-signal/15 text-mool-signal'
                      }`}>
                        {item.icon}
                      </div>
                      <div>
                        <p className="text-[10px] text-mool-ink-muted">{item.label}</p>
                        <p className="text-xs font-bold text-mool-ink">
                          {item.value != null ? `${item.value}/5` : '—'}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Refresh button */}
              <button
                onClick={loadInsights}
                disabled={loading}
                className="w-full flex items-center justify-center space-x-2 py-2 text-[11px] text-mool-dusk hover:text-mool-dusk-dark font-semibold transition-colors"
              >
                <RefreshCw className={`w-3 h-3 ${loading ? 'animate-spin' : ''}`} />
                <span>Refresh AI Analysis</span>
              </button>
            </>
          ) : (
            <div className="py-6 text-center">
              <p className="text-xs text-mool-ink-muted">Unable to load AI insights. Tap to retry.</p>
              <button onClick={loadInsights} className="mt-2 text-xs text-mool-dusk font-semibold">
                Retry Analysis
              </button>
            </div>
          )}

          {/* Privacy & Explainability Footer */}
          <div className="flex items-center space-x-1.5 pt-1">
            <Lock className="w-3 h-3 text-mool-ink-faint" />
            <p className="text-[9px] text-mool-ink-faint">
              AI analysis by Groq (llama-3.3-70b) • Deterministic crisis detection • Explainable reasoning • HIPAA-aware
            </p>
          </div>
        </div>
      )}
    </GroundedCard>
  );
};
