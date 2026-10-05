import React from 'react';
import { Sun, Heart, Compass, ShieldCheck } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { TopographyDivider } from '../common/TopographyDivider';
import { useSurvivor } from '../../context/SurvivorContext';

export const PersonalTrends: React.FC = () => {
  const { checkins, pseudonym } = useSurvivor();

  // Non-alarming grounding calculation
  const totalEntries = checkins.length;
  const avgMood = totalEntries > 0
    ? (checkins.reduce((acc, c) => acc + c.moodScore, 0) / totalEntries).toFixed(1)
    : '3.5';

  return (
    <div className="max-w-md mx-auto p-4 space-y-5 pb-24">
      <div className="space-y-1">
        <span className="text-xs font-semibold text-mool-moss uppercase tracking-wide">Personal Insight</span>
        <h1 className="font-serif text-2xl text-mool-ink font-semibold">Your Grounding Journey</h1>
        <p className="text-xs text-mool-ink-muted leading-relaxed">
          A gentle look back at your feelings over time. This view is private to you.
        </p>
      </div>

      <TopographyDivider variant="moss" />

      {/* Grounding Summary Stat Cards */}
      <div className="grid grid-cols-2 gap-3">
        <GroundedCard variant="primary" elevation="flat" className="p-4 space-y-1">
          <div className="flex items-center space-x-1.5 text-mool-moss text-xs font-medium">
            <Sun className="w-4 h-4" />
            <span>Check-in Streak</span>
          </div>
          <p className="font-serif text-2xl font-bold text-mool-ink">{totalEntries} Days</p>
          <p className="text-[10px] text-mool-ink-muted">Steady reflections recorded</p>
        </GroundedCard>

        <GroundedCard variant="primary" elevation="flat" className="p-4 space-y-1">
          <div className="flex items-center space-x-1.5 text-mool-moss text-xs font-medium">
            <Heart className="w-4 h-4" />
            <span>Average Sentiment</span>
          </div>
          <p className="font-serif text-2xl font-bold text-mool-ink">{avgMood} / 5</p>
          <p className="text-[10px] text-mool-ink-muted">Grounded & steady baseline</p>
        </GroundedCard>
      </div>

      {/* Gentle Sentiment Visualizer (No clinical risk terms) */}
      <GroundedCard variant="primary" className="space-y-3">
        <h3 className="font-serif text-sm font-semibold text-mool-ink flex items-center space-x-2">
          <Compass className="w-4 h-4 text-mool-moss" />
          <span>Weekly Feeling Rhythm</span>
        </h3>

        <div className="space-y-2 pt-1">
          {checkins.slice(0, 5).map((item, idx) => {
            const pct = (item.moodScore / 5) * 100;
            const dateStr = new Date(item.timestamp).toLocaleDateString(undefined, { weekday: 'short' });
            return (
              <div key={idx} className="space-y-1">
                <div className="flex justify-between text-xs text-mool-ink font-medium">
                  <span>{dateStr}</span>
                  <span className="text-mool-moss font-semibold">{item.moodScore}/5</span>
                </div>
                <div className="w-full h-2.5 bg-mool-mist/50 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-mool-moss rounded-full transition-all duration-500"
                    style={{ width: `${pct}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </GroundedCard>

      {/* Grounding Reminder Note */}
      <GroundedCard variant="mist" elevation="flat" className="flex items-start space-x-3 p-4">
        <ShieldCheck className="w-5 h-5 text-mool-moss shrink-0 mt-0.5" />
        <p className="text-xs text-mool-ink-muted leading-relaxed">
          Remember: Healing is not linear. Ups and downs are completely natural. Your assigned caseworker is watching over your wellbeing quietly to offer support whenever you need it.
        </p>
      </GroundedCard>
    </div>
  );
};

